package main

import (
	"crypto/tls"
	"fmt"
	"log"
	"net"
	"strings"
	"sync"
	"time"

	"aether/internal/common"
)

// ListenerManager handles dynamic listeners based on Horizon configs
type ListenerManager struct {
	listeners map[string]net.Listener
	mu        sync.Mutex
	stopCh    chan struct{}
}

func NewListenerManager() *ListenerManager {
	return &ListenerManager{
		listeners: make(map[string]net.Listener),
		stopCh:    make(chan struct{}),
	}
}

// StartDynamicListeners fetches configs and starts listeners
func (lm *ListenerManager) StartDynamicListeners(nodeID int) {
	log.Printf("🎧 Starting Dynamic Listeners for Node %d...", nodeID)

	// Initial load
	lm.refreshListeners(nodeID)

	// Start refresh loop (every 30 seconds)
	go func() {
		ticker := time.NewTicker(30 * time.Second)
		defer ticker.Stop()

		for {
			select {
			case <-lm.stopCh:
				return
			case <-ticker.C:
				lm.refreshListeners(nodeID)
			}
		}
	}()
}

func (lm *ListenerManager) refreshListeners(nodeID int) {
	configs, err := horizonLoader.GetNodeConfigs(nodeID)
	if err != nil {
		log.Printf("⚠️ Failed to fetch node configs: %v", err)
		return
	}

	activeKeys := make(map[string]bool)

	for _, cfg := range configs {
		port := cfg.Port
		protocols := parseProtocols(cfg.Protocol)

		if cfg.Protocol == "auto" {
			protocols = []string{"flux", "darkmatter", "nebula", "siren"}
		}

		// For simplicity/conflicts, we assume one primary protocol per port,
		// OR we start a "Universal Listener" that multiplexes.
		// Aether's Protocol Detection (Phase 2) allows us to listen on ONE port
		// and handle ALL protocols.

		key := fmt.Sprintf(":%d", port)
		activeKeys[key] = true

		lm.mu.Lock()
		if _, exists := lm.listeners[key]; !exists {
			// Start new listener
			go lm.startListener(port, protocols)
		}
		lm.mu.Unlock()
	}

	// TODO: Close listeners that are no longer in activeKeys
	// (Skipped for MVP simplicity, as closing listeners cleanly with active conns is complex)
}

func (lm *ListenerManager) startListener(port int, supportedProtocols []string) {
	addr := fmt.Sprintf("0.0.0.0:%d", port)
	ln, err := net.Listen("tcp", addr)
	if err != nil {
		log.Printf("❌ Failed to bind %s: %v", addr, err)
		return
	}

	lm.mu.Lock()
	lm.listeners[addr] = ln
	lm.mu.Unlock()

	log.Printf("🚀 Dynamic Listener Started on %s [%s]", addr, strings.Join(supportedProtocols, ","))

	for {
		conn, err := ln.Accept()
		if err != nil {
			return
		}

		// 🔀 Route Connection
		// We use the existing handleTCPConnection which now has protocol validation!
		tlsConn := tls.Server(conn, common.GenerateTLSConfig())
		go handleTCPConnection(tlsConn)
	}
}

// Helper to parse protocols (duplicate but needed if not exported)
// In real code, move to a shared utils package.
func parseProtocols(s string) []string {
	if s == "" {
		return []string{}
	}
	return strings.Split(s, ",")
}
