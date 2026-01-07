package flux

import (
	"context"
	"crypto/tls"
	"errors"
	"io"
	"log"
	"net"
	"net/http"
	"net/url"
	"time"

	// Dark Matter Support

	"aether/pkg/ghost"
	"aether/pkg/mirage" // Siren Support
	"aether/pkg/siren"
	"aether/pkg/transport" // WebRTC Support

	"github.com/gorilla/websocket"
	"github.com/quic-go/quic-go"

	utls "github.com/refraction-networking/utls"
)

// FluxConn wraps the transport.
type FluxConn struct {
	UdpSession *quic.Conn
	UdpStream  *quic.Stream
	TcpConn    net.Conn
	WSConn     *websocket.Conn    // WebSocket
	WebRTCConn io.ReadWriteCloser // NEW: WebRTC DataChannel

	TlsConfig *tls.Config
	Address   string
	UseUDP    bool
	Transport string // "auto", "tcp", "ws", "webrtc"

	// Reader state
	ghostReader *ghost.Reader
	readBuf     []byte

	// Auth
	ClientUUID string
	KeyStore   mirage.KeyStore
}

// Dial initiates the connection
func Dial(addr string, tlsConf *tls.Config, uuid string, trans string) (*FluxConn, error) {
	conn := &FluxConn{
		Address:    addr,
		TlsConfig:  tlsConf,
		ClientUUID: uuid,
		Transport:  trans,
	}

	if trans == "ws" {
		if err := conn.connectWS(); err != nil {
			return nil, err
		}
		return conn, nil
	}
	if trans == "webrtc" {
		if err := conn.connectWebRTC(); err != nil {
			return nil, err
		}
		return conn, nil
	}

	// Strict TCP mode
	if trans == "tcp" {
		if err := conn.connectTCP(); err != nil {
			return nil, err
		}
		// Ghost Reader is already initialized in connectTCP
		return conn, nil
	}

	// Default Hybrid
	conn.UseUDP = true
	if trans == "siren" {
		if err := conn.connectUDPSiren(); err != nil {
			return nil, err
		}
	} else {
		if err := conn.connectUDP(); err != nil {
			log.Println("⚠️ UDP Init failed, trying TCP:", err)
			conn.UseUDP = false
			if err := conn.connectTCP(); err != nil {
				return nil, err
			}
		}
	}
	return conn, nil
}

func (f *FluxConn) connectUDPSiren() error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Dark Matter: Port Hopping Disabled for Stability
	// secret := "AETHER_SECRET"
	// port := darkmatter.GetActivePort(secret, time.Now())
	// host, _, _ := net.SplitHostPort(f.Address)
	// targetAddr := net.JoinHostPort(host, strconv.Itoa(port))
	// log.Printf("🌑 Dark Matter: Hopping to Port %d", port)

	targetAddr := f.Address // Use fixed port from config

	udpAddr, err := net.ResolveUDPAddr("udp", targetAddr)
	if err != nil {
		return err
	}

	rawConn, err := net.ListenUDP("udp", nil)
	if err != nil {
		return err
	}

	// Create Custom PacketConn that Wraps/Unwraps
	sirenConn := &SirenPacketConn{
		PacketConn: rawConn,
		Ctx:        siren.NewContext(),
		Remote:     udpAddr,
	}

	tr := &quic.Transport{Conn: sirenConn}

	sess, err := tr.Dial(ctx, udpAddr, f.TlsConfig, nil)
	if err != nil {
		return err
	}
	f.UdpSession = sess

	stream, err := sess.OpenStreamSync(ctx)
	if err != nil {
		return err
	}
	f.UdpStream = stream
	f.ghostReader = ghost.NewReader(stream)
	return nil
}

// SirenPacketConn wraps net.PacketConn to do RTP Encapsulation
type SirenPacketConn struct {
	net.PacketConn
	Ctx    *siren.RTPContext
	Remote net.Addr
}

func (c *SirenPacketConn) WriteTo(p []byte, addr net.Addr) (n int, err error) {
	// Wrap payload in RTP
	// Note: We ignore 'addr' argument and use fixed Remote because
	// quic-go calls WriteTo with the session remote address.
	rtpPacket := c.Ctx.Wrap(p)
	_, err = c.PacketConn.WriteTo(rtpPacket, c.Remote)
	if err == nil {
		return len(p), nil // Pretend we wrote what was asked
	}
	return 0, err
}

func (c *SirenPacketConn) ReadFrom(p []byte) (n int, addr net.Addr, err error) {
	// Read Loop to skip invalid packets?
	buf := make([]byte, 2048)
	for {
		rn, rAddr, rErr := c.PacketConn.ReadFrom(buf)
		if rErr != nil {
			return 0, nil, rErr
		}

		// Unwrap RTP
		payload, err := siren.Unwrap(buf[:rn])
		if err != nil {
			continue
		} // Not RTP? Drop.

		n = copy(p, payload)
		return n, rAddr, nil
	}
}

func (f *FluxConn) connectUDP() error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	sess, err := quic.DialAddr(ctx, f.Address, f.TlsConfig, nil)
	if err != nil {
		return err
	}
	f.UdpSession = sess

	stream, err := sess.OpenStreamSync(ctx)
	if err != nil {
		return err
	}
	f.UdpStream = stream
	f.ghostReader = ghost.NewReader(stream)
	return nil
}

func (f *FluxConn) connectTCP() error {
	// Standard TLS Dial (Replaces uTLS for stability)
	// UPDATE: Reverting to uTLS to test fingerprinting issues
	// dialer := &net.Dialer{Timeout: 5 * time.Second}
	// tlsRawConn, err := tls.DialWithDialer(dialer, "tcp", f.Address, f.TlsConfig)

	rawConn, err := net.DialTimeout("tcp", f.Address, 5*time.Second)
	if err != nil {
		return err
	}

	uConfig := &utls.Config{
		ServerName:         f.TlsConfig.ServerName,
		InsecureSkipVerify: true,
		NextProtos:         []string{"aether-v1"},
	}
	// Using Firefox fingerprint
	uConn := utls.UClient(rawConn, uConfig, utls.HelloFirefox_Auto)
	if err := uConn.Handshake(); err != nil {
		rawConn.Close()
		return err
	}
	f.TcpConn = uConn

	// 👻 One-Shot Ghost Protocol: Send Fake HTTP Header
	// This satisfies the Server's Peek(4) logic.
	host, _, _ := net.SplitHostPort(f.Address)
	header := "POST /upload HTTP/1.1\r\n" +
		"Host: " + host + "\r\n" +
		"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36\r\n" +
		"Content-Type: application/octet-stream\r\n" +
		"\r\n"

	log.Printf("👻 Sending Ghost Header:\n%s", header)

	if _, err := f.TcpConn.Write([]byte(header)); err != nil {
		f.TcpConn.Close()
		return err
	}

	f.ghostReader = ghost.NewReader(uConn)
	return nil
}

func (f *FluxConn) connectWS() error {
	rawConn, err := net.DialTimeout("tcp", f.Address, 5*time.Second)
	if err != nil {
		return err
	}
	host, _, _ := net.SplitHostPort(f.Address)
	uConfig := &utls.Config{ServerName: host, InsecureSkipVerify: true, NextProtos: f.TlsConfig.NextProtos}
	uConn := utls.UClient(rawConn, uConfig, utls.HelloChrome_Auto)
	if err := uConn.Handshake(); err != nil {
		return err
	} // Leak rawConn?

	u := url.URL{Scheme: "wss", Host: f.Address, Path: "/ws"}
	wsConn, _, err := websocket.NewClient(uConn, &u, http.Header{"User-Agent": []string{"Mozilla/5.0..."}}, 1024, 1024)
	if err != nil {
		return err
	}
	f.WSConn = wsConn
	return nil
}

func (f *FluxConn) connectWebRTC() error {
	// 1. Connect to Signaling Channel (WebSocket /rtc)
	// We need a temporary WS connection
	log.Println("📼 Initializing WebRTC Signaling...")

	rawConn, err := net.DialTimeout("tcp", f.Address, 5*time.Second)
	if err != nil {
		return err
	}
	host, _, _ := net.SplitHostPort(f.Address)

	// uTLS for Signaling too!
	uConfig := &utls.Config{ServerName: host, InsecureSkipVerify: true, NextProtos: f.TlsConfig.NextProtos}
	uConn := utls.UClient(rawConn, uConfig, utls.HelloChrome_Auto)
	if err := uConn.Handshake(); err != nil {
		return err
	}

	u := url.URL{Scheme: "ws", Host: f.Address, Path: "/rtc"}
	ws, _, err := websocket.NewClient(uConn, &u, nil, 1024, 1024)
	if err != nil {
		return err
	}
	defer ws.Close()

	// 2. Create Create WebRTC Client
	c := transport.NewWebRTCClient()
	offer, err := c.CreateOffer()
	if err != nil {
		return err
	}

	// 3. Send Offer
	if err := ws.WriteMessage(websocket.TextMessage, []byte(offer)); err != nil {
		return err
	}

	// 4. Read Answer
	_, msg, err := ws.ReadMessage()
	if err != nil {
		return err
	}
	answer := string(msg)

	// 5. Connect
	log.Println("📼 Signaling Complete. Opening DataChannel...")
	rwc, err := c.SetAnswer(answer)
	if err != nil {
		return err
	}

	f.WebRTCConn = rwc

	// Note: We reuse GhostReader for WebRTC?
	// The server code for WebRTC uses ServerFluxLink which uses Ghost/Mirage wrappers.
	// Server side: func(rwc) { startSmux(NewServerFluxLink(rwc)) }
	// NewServerFluxLink ADDS a Ghost Reader and Wraps writes.
	// So YES, we need GhostReader on Client side because Sender (Server) Wraps data.
	f.ghostReader = ghost.NewReader(rwc)

	return nil
}

func (f *FluxConn) Read(b []byte) (n int, err error) {
	if len(f.readBuf) > 0 {
		n = copy(b, f.readBuf)
		f.readBuf = f.readBuf[n:]
		return n, nil
	}

	if f.Transport == "ws" && f.WSConn != nil {
		_, msg, err := f.WSConn.ReadMessage()
		if err != nil {
			return 0, err
		}
		store := &SingleKeyStore{UUID: f.ClientUUID}
		data, err := mirage.Open(msg, store)
		if err != nil {
			return 0, err
		}
		n = copy(b, data)
		if n < len(data) {
			f.readBuf = data[n:]
		}
		return n, nil
	}

	// WebRTC / TCP / UDP all use GhostReader (Stream based)
	if f.ghostReader == nil {
		return 0, errors.New("no reader")
	}

	// Use ReadRawPacket for TCP/UDP/WebRTC which now use Length-Prefix framing
	// instead of full Ghost HTTP responses.
	mirageData, err := f.ghostReader.ReadRawPacket()
	if err != nil {
		return 0, err
	}
	store := &SingleKeyStore{UUID: f.ClientUUID}
	data, err := mirage.Open(mirageData, store)
	if err != nil {
		return 0, err
	} // Auth fail

	n = copy(b, data)
	if n < len(data) {
		f.readBuf = data[n:]
	}
	return n, nil
}

func (f *FluxConn) Write(b []byte) (n int, err error) {
	masked, err := mirage.Seal(b, f.ClientUUID)
	if err != nil {
		return 0, err
	}

	if f.Transport == "ws" && f.WSConn != nil {
		err = f.WSConn.WriteMessage(websocket.BinaryMessage, masked)
		if err == nil {
			return len(b), nil
		}
		return 0, err
	}

	// Handle Framing (Length Prefix) for all Stream-based transports (TCP, UDP/QUIC, WebRTC/DataChannel)
	// Server expects: [Length: 2 bytes][Ciphertext]

	// Create Frame
	length := len(masked)
	header := []byte{byte(length >> 8), byte(length & 0xFF)}
	frame := append(header, masked...)

	if f.WebRTCConn != nil {
		// WebRTC DataChannel
		_, err = f.WebRTCConn.Write(frame)
		if err == nil {
			return len(b), nil
		}
		return 0, err
	}

	if f.UseUDP && f.UdpStream != nil {
		// QUIC Stream
		_, err = f.UdpStream.Write(frame)
		if err == nil {
			return len(b), nil
		}
		return 0, err
	}

	if f.TcpConn != nil {
		// TCP
		_, err = f.TcpConn.Write(frame)
		if err == nil {
			return len(b), nil
		}
		return 0, err
	}

	return 0, errors.New("closed")
}

func (f *FluxConn) Close() error {
	if f.WSConn != nil {
		f.WSConn.Close()
	}
	if f.UdpSession != nil {
		f.UdpSession.CloseWithError(0, "")
	}
	if f.TcpConn != nil {
		f.TcpConn.Close()
	}
	if f.WebRTCConn != nil {
		f.WebRTCConn.Close()
	} // Close Pion
	return nil
}

func (f *FluxConn) LocalAddr() net.Addr                { return nil }
func (f *FluxConn) RemoteAddr() net.Addr               { return nil }
func (f *FluxConn) SetDeadline(t time.Time) error      { return nil }
func (f *FluxConn) SetReadDeadline(t time.Time) error  { return nil }
func (f *FluxConn) SetWriteDeadline(t time.Time) error { return nil }

type SingleKeyStore struct{ UUID string }

func (s *SingleKeyStore) GetUUID(authID []byte) (string, bool) { return s.UUID, true }
