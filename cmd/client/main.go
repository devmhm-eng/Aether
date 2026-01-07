package main

import (
	"context"
	"crypto/tls"
	"fmt"
	"io"
	"log"
	"net"
	"os"
	"sync"
	"time"

	"aether/pkg/config"
	"aether/pkg/flux"

	"github.com/xtaci/smux"
)

var (
	sess     *smux.Session
	sessLock sync.RWMutex
	cfg      *config.Config
)

func main() {
	var err error
	// Try client_config_test.json first (Explicit Test), then client_config.json (Dev), then config.json (Prod)
	if _, e := os.Stat("client_config_test.json"); e == nil {
		cfg, err = config.LoadConfig("client_config_test.json")
	} else if _, e := os.Stat("client_config.json"); e == nil {
		cfg, err = config.LoadConfig("client_config.json")
	} else {
		cfg, err = config.LoadConfig("config.json")
	}

	if err != nil {
		log.Fatal("❌ Config Error:", err)
	}

	// UUID Validation
	if cfg.ClientUUID == "" {
		log.Fatal("❌ Config Error: 'uuid' is required in Phase 7.")
	}

	log.Printf("🚀 Aether Client starting on port %d...", cfg.LocalPort)
	go maintainConnection()

	ln, err := net.Listen("tcp", fmt.Sprintf(":%d", cfg.LocalPort))
	if err != nil {
		log.Fatal("❌ Listen Error:", err)
	}

	for {
		clientConn, err := ln.Accept()
		if err != nil {
			continue
		}
		go handleSocks5(clientConn)
	}
}

func maintainConnection() {
	tlsConf := &tls.Config{InsecureSkipVerify: true, NextProtos: []string{"aether-v1"}}

	smuxConf := smux.DefaultConfig()
	smuxConf.KeepAliveInterval = 10 * time.Second
	smuxConf.KeepAliveTimeout = 30 * time.Second

	for {
		log.Println("🔄 Connecting...")

		// PASS Config (includes Dark Matter secret) and TLS
		conn, err := flux.Dial(cfg, tlsConf)
		if err != nil {
			log.Printf("⚠️ Dial Failed: %v", err)
			time.Sleep(3 * time.Second)
			continue
		}

		session, err := smux.Client(conn, smuxConf)
		if err != nil {
			log.Printf("⚠️ Handshake Failed: %v", err)
			conn.Close()
			time.Sleep(3 * time.Second)
			continue
		}

		sessLock.Lock()
		sess = session
		sessLock.Unlock()

		log.Println("✅ Tunnel Established!")
		<-session.CloseChan()

		sessLock.Lock()
		sess = nil
		sessLock.Unlock()
	}
}

func getSession() *smux.Session {
	sessLock.RLock()
	defer sessLock.RUnlock()
	return sess
}

func handleSocks5(clientConn net.Conn) {
	defer clientConn.Close()

	var session *smux.Session
	for i := 0; i < 5; i++ {
		session = getSession()
		if session != nil && !session.IsClosed() {
			break
		}
		time.Sleep(500 * time.Millisecond)
	}
	if session == nil {
		return
	}

	clientConn.SetReadDeadline(time.Now().Add(5 * time.Second))
	buf := make([]byte, 262) // Version + nMethods + Methods
	if _, err := io.ReadFull(clientConn, buf[:2]); err != nil {
		return
	}

	nMethods := int(buf[1])
	if _, err := io.ReadFull(clientConn, buf[2:2+nMethods]); err != nil {
		return
	}
	clientConn.SetReadDeadline(time.Time{})
	log.Println("🔌 SOCKS5 Handshake...")
	clientConn.Write([]byte{0x05, 0x00})

	header := make([]byte, 4)
	if _, err := io.ReadFull(clientConn, header); err != nil {
		log.Println("❌ SOCKS5 Header Read Failed:", err)
		return
	}

	log.Printf("📥 SOCKS5 Request: CMD=%d TYPE=%d", header[1], header[3])

	stream, err := session.OpenStream()
	if err != nil {
		log.Println("❌ Smux OpenStream Failed:", err)
		return
	}
	log.Println("🚀 Stream Opened! Morphing traffic...")
	defer stream.Close()

	stream.Write(header)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	go func() { defer cancel(); io.Copy(stream, clientConn) }()
	go func() { defer cancel(); io.Copy(clientConn, stream) }()

	<-ctx.Done()
}
