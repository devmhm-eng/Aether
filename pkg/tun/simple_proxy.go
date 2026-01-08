package tun

import (
	"encoding/binary"
	"fmt"
	"io"
	"log"
	"net"
	"os"
	"sync"
	"time"

	"github.com/xtaci/smux"
)

// SimpleProxy provides lightweight packet forwarding from TUN to smux
type SimpleProxy struct {
	fd      int
	tunFile *os.File
	session *smux.Session
	stopCh  chan struct{}
	wg      sync.WaitGroup

	// Connection tracking
	connsMu sync.RWMutex
	conns   map[string]*proxyConn
}

type proxyConn struct {
	stream   *smux.Stream
	lastSeen time.Time
	tunFile  *os.File
	srcIP    net.IP
	srcPort  uint16
	dstIP    net.IP
	dstPort  uint16
	protocol uint8
}

// NewSimpleProxy creates a new simple packet proxy
func NewSimpleProxy(fd int, session *smux.Session) (*SimpleProxy, error) {
	if session == nil {
		return nil, fmt.Errorf("smux session cannot be nil")
	}

	tunFile := os.NewFile(uintptr(fd), "/dev/tun")
	if tunFile == nil {
		return nil, fmt.Errorf("invalid file descriptor")
	}

	return &SimpleProxy{
		fd:      fd,
		tunFile: tunFile,
		session: session,
		stopCh:  make(chan struct{}),
		conns:   make(map[string]*proxyConn),
	}, nil
}

// Start begins packet forwarding
func (p *SimpleProxy) Start() error {
	log.Printf("TUN: Starting simple packet proxy")

	// Start packet read loop
	p.wg.Add(1)
	go p.readLoop()

	// Start connection cleanup
	p.wg.Add(1)
	go p.cleanupLoop()

	log.Printf("TUN: Simple proxy started")
	return nil
}

// readLoop reads packets from TUN and forwards them
func (p *SimpleProxy) readLoop() {
	defer p.wg.Done()

	buf := make([]byte, 1500) // MTU

	for {
		select {
		case <-p.stopCh:
			return
		default:
		}

		n, err := p.tunFile.Read(buf)
		if err != nil {
			if err != io.EOF {
				log.Printf("TUN: Read error: %v", err)
			}
			continue
		}

		if n < 20 { // Minimum IP header
			continue
		}

		packet := buf[:n]

		// Parse IP header
		version := packet[0] >> 4
		if version != 4 {
			continue // Only IPv4 for now
		}

		headerLen := int(packet[0]&0x0F) * 4
		if n < headerLen {
			continue
		}

		protocol := packet[9]
		srcIP := net.IPv4(packet[12], packet[13], packet[14], packet[15])
		dstIP := net.IPv4(packet[16], packet[17], packet[18], packet[19])

		// Handle TCP (6) and UDP (17)
		switch protocol {
		case 6: // TCP
			if n < headerLen+20 {
				continue
			}
			p.handleTCP(packet, srcIP, dstIP, headerLen)
		case 17: // UDP
			if n < headerLen+8 {
				continue
			}
			p.handleUDP(packet, srcIP, dstIP, headerLen)
		default:
			// Ignore other protocols (ICMP, etc.) for now
			continue
		}
	}
}

// handleTCP forwards TCP packets through smux
func (p *SimpleProxy) handleTCP(packet []byte, srcIP, dstIP net.IP, headerLen int) {
	tcpStart := headerLen
	srcPort := binary.BigEndian.Uint16(packet[tcpStart : tcpStart+2])
	dstPort := binary.BigEndian.Uint16(packet[tcpStart+2 : tcpStart+4])

	connKey := fmt.Sprintf("tcp:%s:%d->%s:%d", srcIP, srcPort, dstIP, dstPort)

	p.connsMu.Lock()
	conn, exists := p.conns[connKey]
	if !exists {
		// New connection - open smux stream
		stream, err := p.session.OpenStream()
		if err != nil {
			p.connsMu.Unlock()
			log.Printf("TUN: Failed to open smux stream: %v", err)
			return
		}

		// Send metadata
		metadata := fmt.Sprintf("CONNECT %s %d\n", dstIP.String(), dstPort)
		if _, err := stream.Write([]byte(metadata)); err != nil {
			stream.Close()
			p.connsMu.Unlock()
			log.Printf("TUN: Failed to send metadata: %v", err)
			return
		}

		conn = &proxyConn{
			stream:   stream,
			lastSeen: time.Now(),
			tunFile:  p.tunFile,
			srcIP:    srcIP,
			srcPort:  srcPort,
			dstIP:    dstIP,
			dstPort:  dstPort,
			protocol: 6,
		}
		p.conns[connKey] = conn

		// Start reverse proxy (server -> client)
		p.wg.Add(1)
		go p.reverseProxy(conn, connKey)

		log.Printf("TUN: New TCP connection: %s", connKey)
	}
	conn.lastSeen = time.Now()
	p.connsMu.Unlock()

	// Extract TCP payload
	dataOffset := int(packet[tcpStart+12]>>4) * 4
	tcpPayload := packet[tcpStart+dataOffset:]

	if len(tcpPayload) > 0 {
		// Forward payload to server
		if _, err := conn.stream.Write(tcpPayload); err != nil {
			log.Printf("TUN: Write to stream failed: %v", err)
			p.closeConn(connKey)
		}
	}
}

// handleUDP forwards UDP packets through smux
func (p *SimpleProxy) handleUDP(packet []byte, srcIP, dstIP net.IP, headerLen int) {
	udpStart := headerLen
	srcPort := binary.BigEndian.Uint16(packet[udpStart : udpStart+2])
	dstPort := binary.BigEndian.Uint16(packet[udpStart+2 : udpStart+4])

	connKey := fmt.Sprintf("udp:%s:%d->%s:%d", srcIP, srcPort, dstIP, dstPort)

	p.connsMu.Lock()
	conn, exists := p.conns[connKey]
	if !exists {
		// New UDP "connection"
		stream, err := p.session.OpenStream()
		if err != nil {
			p.connsMu.Unlock()
			return
		}

		metadata := fmt.Sprintf("UDP %s %d\n", dstIP.String(), dstPort)
		stream.Write([]byte(metadata))

		conn = &proxyConn{
			stream:   stream,
			lastSeen: time.Now(),
			tunFile:  p.tunFile,
			srcIP:    srcIP,
			srcPort:  srcPort,
			dstIP:    dstIP,
			dstPort:  dstPort,
			protocol: 17,
		}
		p.conns[connKey] = conn

		p.wg.Add(1)
		go p.reverseProxy(conn, connKey)

		log.Printf("TUN: New UDP session: %s", connKey)
	}
	conn.lastSeen = time.Now()
	p.connsMu.Unlock()

	// Extract UDP payload
	udpPayload := packet[udpStart+8:]
	if len(udpPayload) > 0 {
		conn.stream.Write(udpPayload)
	}
}

// reverseProxy reads from server and writes back to TUN
func (p *SimpleProxy) reverseProxy(conn *proxyConn, connKey string) {
	defer p.wg.Done()
	defer p.closeConn(connKey)

	buf := make([]byte, 1500)
	for {
		select {
		case <-p.stopCh:
			return
		default:
		}

		conn.stream.SetReadDeadline(time.Now().Add(30 * time.Second))
		n, err := conn.stream.Read(buf)
		if err != nil {
			return
		}

		if n > 0 {
			// Build response packet and write to TUN
			respPacket := p.buildResponsePacket(conn, buf[:n])
			if _, err := conn.tunFile.Write(respPacket); err != nil {
				log.Printf("TUN: Failed to write response: %v", err)
				return
			}
		}
	}
}

// buildResponsePacket creates an IP packet for the response
func (p *SimpleProxy) buildResponsePacket(conn *proxyConn, payload []byte) []byte {
	// This is simplified - real implementation needs proper TCP/UDP header construction
	// For now, just log that we would send it
	log.Printf("TUN: Would send %d bytes back to %s:%d", len(payload), conn.srcIP, conn.srcPort)

	// TODO: Construct proper IP/TCP or IP/UDP packet
	// This requires understanding TCP seq/ack numbers, checksums, etc.
	// For MVP, backend server should handle the reverse connection separately

	return []byte{}
}

// closeConn closes a proxied connection
func (p *SimpleProxy) closeConn(connKey string) {
	p.connsMu.Lock()
	defer p.connsMu.Unlock()

	if conn, exists := p.conns[connKey]; exists {
		conn.stream.Close()
		delete(p.conns, connKey)
		log.Printf("TUN: Closed connection: %s", connKey)
	}
}

// cleanupLoop periodically removes stale connections
func (p *SimpleProxy) cleanupLoop() {
	defer p.wg.Done()

	ticker := time.NewTicker(10 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-p.stopCh:
			return
		case <-ticker.C:
			p.connsMu.Lock()
			now := time.Now()
			for key, conn := range p.conns {
				if now.Sub(conn.lastSeen) > 2*time.Minute {
					conn.stream.Close()
					delete(p.conns, key)
					log.Printf("TUN: Cleaned up stale connection: %s", key)
				}
			}
			p.connsMu.Unlock()
		}
	}
}

// Stop gracefully shuts down the proxy
func (p *SimpleProxy) Stop() {
	log.Printf("TUN: Stopping simple proxy")
	close(p.stopCh)

	// Close all connections
	p.connsMu.Lock()
	for _, conn := range p.conns {
		conn.stream.Close()
	}
	p.conns = make(map[string]*proxyConn)
	p.connsMu.Unlock()

	p.wg.Wait()

	if p.tunFile != nil {
		p.tunFile.Close()
	}

	log.Printf("TUN: Simple proxy stopped")
}
