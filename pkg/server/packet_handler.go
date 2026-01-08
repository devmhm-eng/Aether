package server

import (
	"bufio"
	"fmt"
	"io"
	"log"
	"net"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/xtaci/smux"
)

// PacketHandler manages VPN traffic forwarding
type PacketHandler struct {
	// Connection stats
	mu               sync.RWMutex
	activeStreams    int
	totalBytes       uint64
	totalConnections uint64
}

// NewPacketHandler creates a new packet handler
func NewPacketHandler() *PacketHandler {
	return &PacketHandler{}
}

// HandleStream processes incoming smux streams from VPN clients
func (h *PacketHandler) HandleStream(stream *smux.Stream) {
	defer stream.Close()

	h.mu.Lock()
	h.activeStreams++
	h.totalConnections++
	connID := h.totalConnections
	h.mu.Unlock()

	defer func() {
		h.mu.Lock()
		h.activeStreams--
		h.mu.Unlock()
	}()

	// Read metadata (first line)
	reader := bufio.NewReader(stream)
	metadataLine, err := reader.ReadString('\n')
	if err != nil {
		log.Printf("PacketHandler[%d]: Failed to read metadata: %v", connID, err)
		return
	}

	metadataLine = strings.TrimSpace(metadataLine)
	parts := strings.Fields(metadataLine)

	if len(parts) < 3 {
		log.Printf("PacketHandler[%d]: Invalid metadata: %s", connID, metadataLine)
		return
	}

	protocol := parts[0] // "CONNECT", "TCP", "UDP"
	destHost := parts[1]
	destPort := parts[2]

	log.Printf("PacketHandler[%d]: %s request to %s:%s", connID, protocol, destHost, destPort)

	// Handle based on protocol
	switch protocol {
	case "CONNECT", "TCP":
		h.handleTCP(stream, reader, destHost, destPort, connID)
	case "UDP":
		h.handleUDP(stream, reader, destHost, destPort, connID)
	default:
		log.Printf("PacketHandler[%d]: Unknown protocol: %s", connID, protocol)
	}
}

// handleTCP proxies TCP connections to the internet
func (h *PacketHandler) handleTCP(stream *smux.Stream, reader *bufio.Reader, host, port string, connID uint64) {
	// Connect to actual destination
	destAddr := net.JoinHostPort(host, port)

	conn, err := net.DialTimeout("tcp", destAddr, 10*time.Second)
	if err != nil {
		log.Printf("PacketHandler[%d]: Failed to connect to %s: %v", connID, destAddr, err)
		return
	}
	defer conn.Close()

	log.Printf("PacketHandler[%d]: Connected to %s", connID, destAddr)

	// Bidirectional copy
	var wg sync.WaitGroup
	wg.Add(2)

	// Client -> Internet
	go func() {
		defer wg.Done()
		// Use reader since we already wrapped the stream
		written, err := io.Copy(conn, reader)
		if err != nil && err != io.EOF {
			log.Printf("PacketHandler[%d]: Client->Server copy error: %v", connID, err)
		}
		h.mu.Lock()
		h.totalBytes += uint64(written)
		h.mu.Unlock()
	}()

	// Internet -> Client
	go func() {
		defer wg.Done()
		written, err := io.Copy(stream, conn)
		if err != nil && err != io.EOF {
			log.Printf("PacketHandler[%d]: Server->Client copy error: %v", connID, err)
		}
		h.mu.Lock()
		h.totalBytes += uint64(written)
		h.mu.Unlock()
	}()

	wg.Wait()
	log.Printf("PacketHandler[%d]: Connection closed to %s", connID, destAddr)
}

// handleUDP proxies UDP packets to the internet
func (h *PacketHandler) handleUDP(stream *smux.Stream, reader *bufio.Reader, host, port string, connID uint64) {
	// Resolve destination
	portNum, err := strconv.Atoi(port)
	if err != nil {
		log.Printf("PacketHandler[%d]: Invalid UDP port: %s", connID, port)
		return
	}

	destAddr := &net.UDPAddr{
		IP:   net.ParseIP(host),
		Port: portNum,
	}

	// If host is not an IP, resolve it
	if destAddr.IP == nil {
		addr, err := net.ResolveUDPAddr("udp", net.JoinHostPort(host, port))
		if err != nil {
			log.Printf("PacketHandler[%d]: Failed to resolve %s: %v", connID, host, err)
			return
		}
		destAddr = addr
	}

	// Create UDP connection
	conn, err := net.DialUDP("udp", nil, destAddr)
	if err != nil {
		log.Printf("PacketHandler[%d]: Failed to dial UDP %s: %v", connID, destAddr, err)
		return
	}
	defer conn.Close()

	log.Printf("PacketHandler[%d]: UDP session to %s", connID, destAddr)

	// Set timeout for UDP
	conn.SetDeadline(time.Now().Add(30 * time.Second))

	var wg sync.WaitGroup
	wg.Add(2)

	// Client -> Internet
	go func() {
		defer wg.Done()
		buf := make([]byte, 1500)
		for {
			n, err := reader.Read(buf)
			if err != nil {
				return
			}
			if _, err := conn.Write(buf[:n]); err != nil {
				log.Printf("PacketHandler[%d]: UDP write error: %v", connID, err)
				return
			}
			h.mu.Lock()
			h.totalBytes += uint64(n)
			h.mu.Unlock()
		}
	}()

	// Internet -> Client
	go func() {
		defer wg.Done()
		buf := make([]byte, 1500)
		for {
			conn.SetReadDeadline(time.Now().Add(5 * time.Second))
			n, err := conn.Read(buf)
			if err != nil {
				return
			}
			if _, err := stream.Write(buf[:n]); err != nil {
				log.Printf("PacketHandler[%d]: UDP stream write error: %v", connID, err)
				return
			}
			h.mu.Lock()
			h.totalBytes += uint64(n)
			h.mu.Unlock()
		}
	}()

	wg.Wait()
	log.Printf("PacketHandler[%d]: UDP session closed to %s", connID, destAddr)
}

// GetStats returns current handler statistics
func (h *PacketHandler) GetStats() (activeStreams int, totalBytes uint64, totalConnections uint64) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return h.activeStreams, h.totalBytes, h.totalConnections
}

// LogStats periodically logs statistics
func (h *PacketHandler) LogStats() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		active, bytes, total := h.GetStats()
		log.Printf("PacketHandler Stats: Active=%d, TotalConns=%d, TotalBytes=%s",
			active, total, formatBytes(bytes))
	}
}

func formatBytes(bytes uint64) string {
	const unit = 1024
	if bytes < unit {
		return fmt.Sprintf("%d B", bytes)
	}
	div, exp := uint64(unit), 0
	for n := bytes / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %ciB", float64(bytes)/float64(div), "KMGTPE"[exp])
}
