package main

import (
	"bufio"
	"context"
	"crypto/sha256"
	"crypto/tls"
	"encoding/binary"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"time"

	"aether/internal/common"
	"aether/pkg/config"
	"aether/pkg/darkmatter"
	"aether/pkg/honeypot"
	"aether/pkg/mirage"
	"aether/pkg/nebula"
	"aether/pkg/transport" // Import WebRTC Transport

	"github.com/gorilla/websocket"
	"github.com/quic-go/quic-go"
	"github.com/xtaci/smux"
)

const addr = "0.0.0.0:4242"

var (
	keyStore *InMemoryKeyStore
	rtcMgr   *transport.WebRTCManager
)

// WebSocket Upgrader
var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

func main() {
	// ... Config Loading ...
	var cfg *config.Config
	var err error

	if _, e := os.Stat("server_config.json"); e == nil {
		cfg, err = config.LoadConfig("server_config.json")
	} else {
		cfg, err = config.LoadConfig("config.json")
	}

	if err != nil {
		log.Println("⚠️ Config Error:", err)
		keyStore = NewInMemoryKeyStore([]config.User{})
	} else {
		keyStore = NewInMemoryKeyStore(cfg.Users)
		globalCfg = cfg // Assign for Nebula access
		log.Printf("📜 Config Loaded: Nebula=%v DarkMatter=%v Subnet='%s'",
			cfg.EnableNebula, cfg.EnableDarkMatter, cfg.IPv6Subnet)
	}

	tlsConf := common.GenerateTLSConfig()
	log.Println("🚀 Aether Server Starting on", addr)

	// Start Honeypot Server
	go honeypot.StartServer("8080")

	// 🌌 Project Dark Matter: Port Monitor (Server Side verification)
	// Since we are not using eBPF in this MVP to physically move ports,
	// we verify the logic by printing the "Active Port" the client should be using.
	if cfg.EnableDarkMatter {
		go func() {
			log.Printf("🌑 Dark Matter Active! Secret: %s", cfg.DarkMatterSecret)
			for {
				port := darkmatter.GetActivePort(cfg.DarkMatterSecret, time.Now())
				log.Printf("🌑 [DarkMatter] Active Port Window: %d", port)

				// Calculate next window
				now := time.Now().Unix()
				rem := darkmatter.RotationInterval - (now % darkmatter.RotationInterval)
				time.Sleep(time.Duration(rem) * time.Second)
			}
		}()
	}

	// Initialize WebRTC Manager
	rtcMgr = transport.NewWebRTCManager()
	rtcMgr.OnStream = func(rwc io.ReadWriteCloser) {
		// Wrap RWC in ServerFluxLink and start Smux
		// Note: WebRTC DataChannel is already "inside" the tunnel practically?
		// Actually, Aether protocol running INSIDE DataChannel means:
		// DataChannel -> Ghost(optional) -> Mirage -> Payload.
		// If using WebRTC, traffic is already encrypted (DTLS).
		// Ghost is definitely NOT needed inside (double encapsulation).
		// Mirage is good for Auth/Padding.
		// So we use ServerFluxLink but maybe bypass Ghost?
		// For simplicity/uniformity: Treat DataChannel as just another pipe.
		// The client will wrap packets in Ghost/Mirage.

		log.Println("📼 WebRTC DataChannel Connected!")
		link := NewServerFluxLink(rwc)
		startSmux(link)
	}

	// 1. QUIC Listener
	// Note: We need to multiplex signals if using same UDP port.
	// But quic-go ListenAddr binds heavily.
	// We should probably rely on separate UDP listener if possible,
	// OR use the UDPMultiplexer we built!

	udpAddr, _ := net.ResolveUDPAddr("udp", addr)
	udpConn, err := net.ListenUDP("udp", udpAddr)
	if err != nil {
		log.Fatal(err)
	}

	// Start Multiplexer
	mux := transport.NewUDPMultiplexer(udpConn)

	// Start QUIC on Virtual PacketConn
	go func() {
		// quic.Listen(packetConn...)
		listener, err := quic.Listen(mux.QuicConn, tlsConf, nil)
		if err != nil {
			log.Fatal(err)
		}
		for {
			sess, err := listener.Accept(context.Background())
			if err != nil {
				continue
			}
			go handleFluxSession(sess)
		}
	}()

	// We need to feed DTLS/WebRTC packets to Pion?
	// Pion usually manages its own socket.
	// We can use ICE's SetPacketConn?
	// Pion ICE Agent needs a PacketConn.
	// We can pass mux.DtlsConn to the WebRTC Engine setting!
	// Update: transport.WebRTCManager needs to accept a PacketConn or External UDP.
	// We didn't add that to NewWebRTCManager.
	// Let's modify NewWebRTCManager to accept `mux.DtlsConn`.
	// For now, let's keep Server logic structure and fix Manager later.

	// 2. TCP/WebSocket Listener (Signaling + TCP VPN + Honeypot)
	// Force IPv4 Listener to ensure 0.0.0.0 binding matches explicit IPv4 Client
	ln, err := net.Listen("tcp4", addr)
	if err != nil {
		log.Fatal(err)
	}

	for {
		log.Println("🔄 Waiting for TCP connection...")
		conn, err := ln.Accept()
		if err != nil {
			log.Println("❌ Accept Error:", err)
			continue
		}
		log.Println("✅ TCP AcceptRAW:", conn.RemoteAddr())
		// Wrap in TLS
		tlsConn := tls.Server(conn, tlsConf)
		log.Println("🔐 Wrapped in TLS, spawning handler...")
		go handleTCPConnection(tlsConn)
	}
}

func handleTCPConnection(conn *tls.Conn) {
	log.Printf("🔍 Conn Type: %T", conn)

	// Force Handshake
	if err := conn.Handshake(); err != nil {
		log.Println("❌ TLS Handshake Error:", err)
		conn.Close()
		return
	}
	log.Println("✅ TLS Handshake Success")

	br := bufio.NewReader(conn)
	peek, err := br.Peek(4)
	if err != nil {
		conn.Close()
		return
	}
	head := string(peek)

	if head == "POST" {
		// 👻 Ghost Protocol: Consume the Fake Header
		req, err := http.ReadRequest(br)
		if err != nil {
			log.Println("❌ Ghost Header Parse Error:", err)
			conn.Close()
			return
		}
		// Close the body to ensure we don't leak, although it's likely empty/dummy.
		req.Body.Close()

		log.Println("👻 Ghost Handshake Accepted. Upgrading to Raw Stream.")

		// Pass 'br' (which is now positioned AFTER the header)
		log.Printf("📊 Buffered Bytes in Reader: %d", br.Buffered())
		link := NewServerFluxLinkRaw(conn, br)
		startSmux(link)
	} else if head == "GET " || head == "HEAD" || head == "CONN" {
		handleHTTPTraffic(conn, br)
	} else {
		bConn := &BufferedConn{Conn: conn, br: br}
		honeypot.ProxyToHoneypot(bConn, "8080")
	}
}

// ...

// ServerFluxLink implementation using RAW Length-Prefix (No Ghost Wrapping)
type ServerFluxLink struct {
	RWC        io.ReadWriteCloser
	br         *bufio.Reader
	readBuf    []byte
	ActiveUUID string
}

func NewServerFluxLinkRaw(c net.Conn, br *bufio.Reader) *ServerFluxLink {
	return &ServerFluxLink{RWC: c, br: br}
}

// For QUIC/WebRTC (Legacy/Other transports) - Might need adjustment or keep separate
func NewServerFluxLink(s io.ReadWriteCloser) *ServerFluxLink {
	// For now, if QUIC uses this, it breaks unless we add Logic.
	// But TCP is priority.
	// QUIC provides message boundaries?
	// NOTE: QUIC/UDP still uses 'ghostReader'. If we change struct, we break QUIC.
	// Let's make ServerFluxLink adaptive or just fix TCP first.
	// Since we are replacing the STRUCT methods, we change it for everyone.
	// We should probably keep Ghost logic for UDP if needed, OR unify.
	// Simplicity: Unify. Use Length Prefix for EVERYTHING is standard.
	// But QUIC streams are clean.
	// Let's assume this change targets TCP mainly.
	return &ServerFluxLink{RWC: s, br: bufio.NewReader(s)}
}

func (l *ServerFluxLink) Read(b []byte) (int, error) {
	if len(l.readBuf) > 0 {
		n := copy(b, l.readBuf)
		l.readBuf = l.readBuf[n:]
		return n, nil
	}

	// Read 2-byte Length
	header := make([]byte, 2)
	if _, err := io.ReadFull(l.br, header); err != nil {
		log.Printf("❌ Read Frame Length Failed: %v", err)
		return 0, err
	}
	length := int(header[0])<<8 | int(header[1])
	log.Printf("📥 Reading Frame: Len=%d", length)

	payload := make([]byte, length)
	if _, err := io.ReadFull(l.br, payload); err != nil {
		log.Printf("❌ Read Payload Failed: %v", err)
		return 0, err
	}

	data, err := mirage.Open(payload, keyStore)
	if err != nil {
		authID := payload[:16]
		log.Printf("❌ Decryption Failed: %v | ReceivedID=%x", err, authID)
		return 0, err
	}

	authID := payload[:16]
	uuid, _ := keyStore.GetUUID(authID)
	l.ActiveUUID = uuid
	log.Printf("🔓 Decrypted Frame: UUID=%s Size=%d", uuid, len(data))

	n := copy(b, data)
	if n < len(data) {
		l.readBuf = data[n:]
	}
	return n, nil
}

func (l *ServerFluxLink) Write(b []byte) (int, error) {
	if l.ActiveUUID == "" {
		return 0, fmt.Errorf("no active session")
	}
	masked, err := mirage.Seal(b, l.ActiveUUID)
	if err != nil {
		return 0, err
	}

	// Length Prefix
	length := len(masked)
	header := []byte{byte(length >> 8), byte(length & 0xFF)}

	// Write Header + Payload
	_, err = l.RWC.Write(append(header, masked...))
	if err == nil {
		return len(b), nil
	}
	return 0, err
}

func (l *ServerFluxLink) Close() error { return l.RWC.Close() }

type InMemoryKeyStore struct{ Users map[string]string }

func NewInMemoryKeyStore(users []config.User) *InMemoryKeyStore {
	s := &InMemoryKeyStore{make(map[string]string)}
	for _, u := range users {
		k := sha256.Sum256([]byte(u.UUID))
		id := k[:16]
		s.Users[string(id)] = u.UUID
		log.Printf("🔑 Loaded User: PayloadID=%x UUID=%s", id, u.UUID)
	}
	return s
}
func (s *InMemoryKeyStore) GetUUID(id []byte) (string, bool) {
	u, ok := s.Users[string(id)]
	return u, ok
}

func handleRequest(stream net.Conn) {
	defer stream.Close()
	log.Println("📥 Handling SOCKS Request...")
	header := make([]byte, 4)
	if _, err := io.ReadFull(stream, header); err != nil {
		log.Println("❌ Header Read Error:", err)
		return
	}
	log.Printf("📦 Header: %v", header)
	if header[1] != 1 {
		return
	}
	var targetAddr string
	switch header[3] {
	case 1:
		buf := make([]byte, 4)
		io.ReadFull(stream, buf)
		targetAddr = net.IP(buf).String()
	case 3:
		buf := make([]byte, 1)
		io.ReadFull(stream, buf)
		aliceLen := int(buf[0])
		domain := make([]byte, aliceLen)
		io.ReadFull(stream, domain)
		targetAddr = string(domain)
	case 4:
		return
	}
	portBuf := make([]byte, 2)
	io.ReadFull(stream, portBuf)
	port := binary.BigEndian.Uint16(portBuf)
	dest := net.JoinHostPort(targetAddr, fmt.Sprintf("%d", port))
	log.Printf("🌐 SOCKS Request: %s", dest)

	// 🌌 Project Nebula: Happy Eyeballs Fallback Logic
	// 1. Try Nebula (IPv6 Source) first if enabled.
	// 2. If that fails (e.g. Target is IPv4-only), Fallback to Standard Dialer.

	var targetConn net.Conn
	var err error
	nebulaSuccess := false

	if globalCfg != nil && globalCfg.EnableNebula && globalCfg.IPv6Subnet != "" {
		randomIP, nErr := nebula.GetRandomIPv6(globalCfg.IPv6Subnet)
		if nErr == nil {
			// Try Dialing with specific IPv6 Source
			nebulaDialer := &net.Dialer{
				Timeout:   4 * time.Second, // Fast timeout for fallback
				LocalAddr: &net.TCPAddr{IP: randomIP},
			}
			log.Printf("🌌 Nebula active: Dialing %s from %s", dest, randomIP)
			targetConn, err = nebulaDialer.Dial("tcp", dest)
			if err == nil {
				nebulaSuccess = true
			} else {
				log.Printf("⚠️ Nebula Dial Failed (%s): %v -> Fallback to Standard IP", dest, err)
			}
		} else {
			log.Printf("⚠️ Nebula Generation Error: %v", nErr)
		}
	} else {
		// Log skipped reason only once per connection (debug only, maybe remove later to reduce spam)
		// log.Printf("⚠️ Nebula SKIPPED")
	}

	// 2. Fallback (Standard IP / IPv4 / IPv6 w/o source bind)
	if !nebulaSuccess {
		// Standard Dialer (matches OS default behavior)
		stdDialer := &net.Dialer{Timeout: 10 * time.Second}
		targetConn, err = stdDialer.Dial("tcp", dest)
		if err != nil {
			log.Printf("❌ SOCKS Dial Failed (%s): %v", dest, err)
			return
		}
	}

	log.Printf("✅ SOCKS Dial Connected: %s", dest)
	defer targetConn.Close()

	// Update Logger to show Source IP (Nebula Check)
	log.Printf("✅ SOCKS Dial Connected: %s -> %s", targetConn.LocalAddr(), dest)

	stream.Write([]byte{0x05, 0x00, 0x00, 0x01, 0, 0, 0, 0, 0, 0})
	go io.Copy(targetConn, stream)
	io.Copy(stream, targetConn)
}

// Global Config reference (to access Nebula settings)
var globalCfg *config.Config

func handleHTTPTraffic(conn net.Conn, br *bufio.Reader) {
	vln := &SingleConnListener{conn: conn}

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Route: /rtc -> Signaling
		if r.URL.Path == "/rtc" && websocket.IsWebSocketUpgrade(r) {
			ws, err := upgrader.Upgrade(w, r, nil)
			if err == nil {
				handleRTCSignaling(ws)
			}
			return
		}

		// Route: /ws -> WebSocket VPN
		if websocket.IsWebSocketUpgrade(r) {
			ws, err := upgrader.Upgrade(w, r, nil)
			if err == nil {
				handleWSLink(ws)
				return
			}
		}

		// Fallback -> Honeypot
		target, _ := url.Parse("http://127.0.0.1:8080")
		proxy := httputil.NewSingleHostReverseProxy(target)
		r.Host = "127.0.0.1:8080"
		proxy.ServeHTTP(w, r)
	})

	server := &http.Server{Handler: handler}
	bufferedConn := &BufferedConn{Conn: conn, br: br}
	vln.conn = bufferedConn
	server.Serve(vln)
}

func handleRTCSignaling(ws *websocket.Conn) {
	defer ws.Close()
	// Expect SDP Offer (Text)
	_, msg, err := ws.ReadMessage()
	if err != nil {
		return
	}

	offer := string(msg)

	// Create Answer
	answer, err := rtcMgr.AcceptOffer(offer)
	if err != nil {
		log.Println("RTC Error:", err)
		return
	}

	// Send Answer
	ws.WriteMessage(websocket.TextMessage, []byte(answer))
}

func handleWSLink(ws *websocket.Conn) {
	link := &WSFluxLink{WS: ws}
	startSmux(link)
}

// WSFluxLink implements io.ReadWriteCloser over WS
type WSFluxLink struct {
	WS         *websocket.Conn
	readBuf    []byte
	ActiveUUID string
}

func (l *WSFluxLink) Read(b []byte) (int, error) {
	if len(l.readBuf) > 0 {
		n := copy(b, l.readBuf)
		l.readBuf = l.readBuf[n:]
		return n, nil
	}
	_, msg, err := l.WS.ReadMessage()
	if err != nil {
		return 0, err
	}
	if len(msg) < 16 {
		return 0, fmt.Errorf("short ws packet")
	}
	authID := msg[:16]
	uuid, ok := keyStore.GetUUID(authID)
	if !ok {
		return 0, fmt.Errorf("auth failed")
	}
	l.ActiveUUID = uuid
	data, err := mirage.Open(msg, keyStore)
	if err != nil {
		return 0, err
	}
	n := copy(b, data)
	if n < len(data) {
		l.readBuf = data[n:]
	}
	return n, nil
}
func (l *WSFluxLink) Write(b []byte) (int, error) {
	if l.ActiveUUID == "" {
		return 0, fmt.Errorf("no auth")
	}
	masked, err := mirage.Seal(b, l.ActiveUUID)
	if err != nil {
		return 0, err
	}
	err = l.WS.WriteMessage(websocket.BinaryMessage, masked)
	if err != nil {
		return 0, err
	}
	return len(b), nil
}
func (l *WSFluxLink) Close() error { return l.WS.Close() }

// Helpers
func startSmux(link io.ReadWriteCloser) {
	session, err := smux.Server(link, nil)
	if err != nil {
		log.Println("Smux Error:", err)
		return
	}
	defer session.Close()
	for {
		stream, err := session.AcceptStream()
		if err != nil {
			break
		}
		go handleRequest(stream)
	}
}

type SingleConnListener struct {
	conn net.Conn
	done bool
}

func (l *SingleConnListener) Accept() (net.Conn, error) {
	if l.done {
		return nil, io.EOF
	}
	l.done = true
	return l.conn, nil
}
func (l *SingleConnListener) Close() error   { return nil }
func (l *SingleConnListener) Addr() net.Addr { return l.conn.LocalAddr() }

type BufferedConn struct {
	net.Conn
	br *bufio.Reader
}

func (b *BufferedConn) Read(p []byte) (int, error) { return b.br.Read(p) }

func handleFluxSession(sess *quic.Conn) {
	stream, err := sess.AcceptStream(context.Background())
	if err != nil {
		return
	}
	link := NewServerFluxLink(stream)
	startSmux(link)
}

type CombinedRW struct {
	io.Reader
	io.Writer
}

// For QUIC UDP which uses ServerFluxLink with ghostReader, we might need a separate struct IF they differ.
// But earlier edit changed ServerFluxLink to remove ghostReader.
// So QUIC logic also breaks unless we fix handleFluxSession.
// handleFluxSession calls NewServerFluxLink(stream).
// NewServerFluxLink now returns ServerFluxLink with br *bufio.Reader.
// So QUIC is now also "Length-Prefixed".
// This means UDP transport must ALSO be updated to Length-Prefixed if we want it to work.
// But UDP transport (Siren) is separate logic?
// Wait, Siren is transport layer.
// Inside QUIC stream, we have Aether Protocol.
// Yes, QUIC Streams must also follow the protocol.
// So this change UNIFIES TCP and QUIC protocol to be Length-Prefixed.
// This is GOOD.
