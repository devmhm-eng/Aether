package transport

import (
	"aether/pkg/siren"
	"net"
	"time"
)

// UDPMultiplexer splits traffic between QUIC and DTLS on the same UDP port
type UDPMultiplexer struct {
	Conn     *net.UDPConn
	QuicConn *VirtualPacketConn
	DtlsConn *VirtualPacketConn
}

func NewUDPMultiplexer(conn *net.UDPConn) *UDPMultiplexer {
	m := &UDPMultiplexer{
		Conn:     conn,
		QuicConn: NewVirtualPacketConn(conn),
		DtlsConn: NewVirtualPacketConn(conn),
	}
	go m.run()
	return m
}

func (m *UDPMultiplexer) run() {
	buf := make([]byte, 2048)
	for {
		n, addr, err := m.Conn.ReadFrom(buf)
		if err != nil {
			break
		}

		firstByte := buf[0]
		data := make([]byte, n)
		copy(data, buf[:n])

		// 2. Check for Siren/RTP (0x80)
		// Wait, if we use RTP, we are stripping it here, so it looks like QUIC to the listener.
		// But wait, if we modify the buffer 'data', we need to make sure QuicConn uses the NEW slice.
		// Currently QuicConn.Push copies data.
		// siren.Unwrap returns a slice view or new slice.

		if firstByte == 0x80 {
			payload, err := siren.Unwrap(data)
			if err == nil {
				// Forward UNWRAPPED payload to QUIC Listener
				m.QuicConn.Push(payload, addr)
				continue
			}
		}

		if firstByte >= 20 && firstByte <= 63 {
			// DTLS
			m.DtlsConn.Push(data, addr)
		} else if firstByte < 4 {
			// STUN (WebRTC Binding)
			m.DtlsConn.Push(data, addr)
		} else {
			// Assume QUIC
			m.QuicConn.Push(data, addr)
		}
	}
}

// VirtualPacketConn implements net.PacketConn for a virtual channel
type VirtualPacketConn struct {
	RealConn  net.PacketConn
	ReadChan  chan Packet
	localAddr net.Addr
}

type Packet struct {
	Data []byte
	Addr net.Addr
}

func NewVirtualPacketConn(real net.PacketConn) *VirtualPacketConn {
	return &VirtualPacketConn{
		RealConn:  real,
		ReadChan:  make(chan Packet, 1024),
		localAddr: real.LocalAddr(),
	}
}

func (v *VirtualPacketConn) Push(data []byte, addr net.Addr) {
	select {
	case v.ReadChan <- Packet{Data: data, Addr: addr}:
	default:
		// Drop if full
	}
}

func (v *VirtualPacketConn) ReadFrom(p []byte) (n int, addr net.Addr, err error) {
	pkt := <-v.ReadChan
	n = copy(p, pkt.Data)
	return n, pkt.Addr, nil
}

func (v *VirtualPacketConn) WriteTo(p []byte, addr net.Addr) (n int, err error) {
	return v.RealConn.WriteTo(p, addr)
}

func (v *VirtualPacketConn) Close() error                       { return nil }
func (v *VirtualPacketConn) LocalAddr() net.Addr                { return v.localAddr }
func (v *VirtualPacketConn) SetDeadline(t time.Time) error      { return nil }
func (v *VirtualPacketConn) SetReadDeadline(t time.Time) error  { return nil }
func (v *VirtualPacketConn) SetWriteDeadline(t time.Time) error { return nil }
