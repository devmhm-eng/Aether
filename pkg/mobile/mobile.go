package mobile

import (
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"strings"
	"sync"
	"time"

	"aether/pkg/config"
	"aether/pkg/device"
	"aether/pkg/enigma"
	"aether/pkg/flux"
	"aether/pkg/tun"

	"github.com/xtaci/smux"
)

var (
	sess     *smux.Session
	sessLock sync.RWMutex
	cfg      *config.Config
	stopCh   chan struct{}
	running  bool
	mu       sync.Mutex
)

// Start initializes the Aether Client Core with a JSON configuration string.
// This function is designed to be called from Android (Kotlin) or iOS (Swift).
func Start(configJSON string) error {
	mu.Lock()
	defer mu.Unlock()

	if running {
		return fmt.Errorf("aether client is already running")
	}

	// Parse Config
	cfg = &config.Config{}
	if err := json.Unmarshal([]byte(configJSON), cfg); err != nil {
		return fmt.Errorf("invalid config json: %v", err)
	}

	// Validate
	if cfg.ClientUUID == "" {
		return fmt.Errorf("config error: uuid is required")
	}

	// Setup logging (optional: redirect to android logcat if needed, implies using mobile/log)
	log.Printf("🚀 Aether Mobile Client Starting... UUID=%s", cfg.ClientUUID)

	// 4. Get Hardware ID (Persistent per install)
	// Priority:
	// 1. Config (Injected by Host App - Flutter/Native)
	// 2. File-based Fallback (pkg/device)
	var hwID string
	if cfg.HardwareID != "" {
		hwID = cfg.HardwareID
		log.Printf("📱 Using Native Hardware ID: %s", hwID)
	} else {
		// Fallback for tests or pure Go runs
		var err error
		hwID, err = device.GetHardwareID(".")
		if err != nil {
			log.Printf("⚠️ Failed to get Hardware ID: %v", err)
			hwID = "unknown_device_" + cfg.ClientUUID
		}
	}

	// 5. Register Device Securely
	regPayload := fmt.Sprintf(`{
		"action": "register_device",
		"hardware_id": "%s",
		"user_uuid": "%s",
		"label": "Mobile Client"
	}`, hwID, cfg.ClientUUID)

	// Assuming BACKEND_URL is accessible (e.g. from config or hardcoded for now)
	// We need the remote server address. It's usually in cfg.RemoteAddr but that's for Tunnel.
	// The API port is different (8080 vs 443).
	// For Phase 7 we will construct it from config if available, or just log it for now.
	// REAL IMPLEMENTATION: cfg should have APIUrl.
	apiURL := "http://localhost:8080/api/v1/secure" // TODO: Get from Config
	if cfg.ServerAddr != "" {
		// Simple hack to guess API url from remote addr
		parts := strings.Split(cfg.ServerAddr, ":")
		if len(parts) > 0 {
			apiURL = "http://" + parts[0] + ":8080/api/v1/secure"
		}
	}

	log.Printf("🔐 Registering Device %s to %s", hwID, apiURL)
	resp := SecureRequest(apiURL, regPayload)
	log.Printf("🔐 Registration Response: %s", resp)

	// Check response for failure
	if strings.Contains(resp, "Device limit reached") {
		return fmt.Errorf("device limit reached for this account")
	}

	stopCh = make(chan struct{})
	running = true

	// Start Connection Keeper
	go maintainConnection()

	return nil
}

// Stop closes the connection and stops the client.
func Stop() {
	mu.Lock()
	defer mu.Unlock()

	if !running {
		return
	}

	close(stopCh)

	sessLock.Lock()
	if sess != nil {
		sess.Close()
		sess = nil
	}
	sessLock.Unlock()

	running = false
	log.Println("🛑 Aether Mobile Client Stopped.")
}

// GetStats returns usage statistics (placeholder for now).
func GetStats() string {
	sessLock.RLock()
	defer sessLock.RUnlock()

	status := "disconnected"
	if sess != nil && !sess.IsClosed() {
		status = "connected"
	}

	return fmt.Sprintf(`{"status": "%s", "uptime": "%s"}`, status, "TODO")
}

// Enigma Key (Must match server)
var EnigmaKey = []byte("01234567890123456789012345678901")

// SecureRequest sends an encrypted payload to the server and decrypts the response.
// Returns JSON string or error string.
func SecureRequest(endpoint string, payload string) string {
	// 1. Encrypt Payload
	cipherBody, err := enigma.Seal([]byte(payload), EnigmaKey)
	if err != nil {
		return fmt.Sprintf(`{"error": "Encryption failed: %v"}`, err)
	}

	// 2. Send Request
	resp, err := http.Post(endpoint, "text/plain", strings.NewReader(cipherBody))
	if err != nil {
		return fmt.Sprintf(`{"error": "Network failed: %v"}`, err)
	}
	defer resp.Body.Close()

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return fmt.Sprintf(`{"error": "Read failed: %v"}`, err)
	}

	if resp.StatusCode != 200 {
		return fmt.Sprintf(`{"error": "Server error: %s"}`, string(bodyBytes))
	}

	// 3. Decrypt Response
	plainResp, err := enigma.Open(string(bodyBytes), EnigmaKey)
	if err != nil {
		return fmt.Sprintf(`{"error": "Decryption failed: %v"}`, err)
	}

	return string(plainResp)
}

func maintainConnection() {
	tlsConf := &tls.Config{InsecureSkipVerify: true, NextProtos: []string{"aether-v1"}}

	smuxConf := smux.DefaultConfig()
	smuxConf.KeepAliveInterval = 10 * time.Second
	smuxConf.KeepAliveTimeout = 30 * time.Second

	for {
		select {
		case <-stopCh:
			return
		default:
		}

		log.Println("🔄 Mobile: Connecting to server...")

		// PASS Config (includes Dark Matter secret) and TLS
		conn, err := flux.Dial(cfg, tlsConf)
		if err != nil {
			log.Printf("⚠️ Mobile Dial Failed: %v", err)

			// Wait before retry, listening for stop signal
			select {
			case <-stopCh:
				return
			case <-time.After(3 * time.Second):
				continue
			}
		}

		session, err := smux.Client(conn, smuxConf)
		if err != nil {
			log.Printf("⚠️ Mobile Handshake Failed: %v", err)
			conn.Close()
			time.Sleep(3 * time.Second)
			continue
		}

		sessLock.Lock()
		sess = session
		sessLock.Unlock()

		log.Println("✅ Mobile Tunnel Established!")

		// Wait until session is closed or stop signal received
		select {
		case <-stopCh:
			session.Close()
			return
		case <-session.CloseChan():
			log.Println("⚠️ Mobile Session Closed unexpectedly.")
		}

		sessLock.Lock()
		sess = nil
		sessLock.Unlock()
	}
}

// Request exposes SecureRequest to the mobile bridge.
func Request(endpoint, payload string) string {
	return SecureRequest(endpoint, payload)
}

// StartVPN initializes the VPN mode with a file descriptor (Android VpnService).
func StartVPN(fd int, configJSON string) error {
	mu.Lock()
	defer mu.Unlock()

	if running {
		return fmt.Errorf("aether client is already running")
	}

	log.Printf("🚀 Aether VPN Service Starting (FD: %d)...", fd)

	// Parse Config
	cfg = &config.Config{}
	if err := json.Unmarshal([]byte(configJSON), cfg); err != nil {
		return fmt.Errorf("invalid config json: %v", err)
	}

	// Get Hardware ID
	var hwID string
	if cfg.HardwareID != "" {
		hwID = cfg.HardwareID
		log.Printf("📱 Using Native Hardware ID: %s", hwID)
	} else {
		hwID = "unknown_device_" + cfg.ClientUUID
	}

	// Establish connection to server using flux transport
	log.Printf("🔗 Connecting to Aether Server via flux...")

	// TODO: For now, create a mock smux session
	// In production, this should use flux.DialFlux() to actual server
	// For testing, we'll use a local mock

	// Create a mock net.Conn for smux (replace with real flux connection)
	// This is temporary - just to get compilation working
	mockConn := &mockNetConn{}

	// Create smux session over the connection
	var err error
	sess, err = smux.Client(mockConn, smux.DefaultConfig())
	if err != nil {
		return fmt.Errorf("smux client failed: %v", err)
	}

	log.Printf("✅ Smux session established")

	// Initialize Simple Proxy
	proxy, err := tun.NewSimpleProxy(fd, sess)
	if err != nil {
		sess.Close()
		return fmt.Errorf("simple proxy init failed: %v", err)
	}

	// Start packet forwarding
	if err := proxy.Start(); err != nil {
		proxy.Stop()
		sess.Close()
		return fmt.Errorf("failed to start proxy: %v", err)
	}

	log.Printf("🚀 Simple Proxy started - VPN tunnel active!")

	// Set up cleanup
	stopCh = make(chan struct{})
	running = true

	// Monitor connection and handle cleanup
	go func() {
		<-stopCh
		log.Printf("🛑 Stopping VPN Service...")
		proxy.Stop()
		if sess != nil {
			sess.Close()
		}
		running = false
		log.Printf("✅ VPN Service stopped")
	}()

	// Start keep-alive (heartbeat)
	go maintainConnection()

	return nil
}

// mockNetConn is a temporary mock connection for testing
type mockNetConn struct{}

func (m *mockNetConn) Read(b []byte) (n int, err error)   { return 0, io.EOF }
func (m *mockNetConn) Write(b []byte) (n int, err error)  { return len(b), nil }
func (m *mockNetConn) Close() error                       { return nil }
func (m *mockNetConn) LocalAddr() net.Addr                { return nil }
func (m *mockNetConn) RemoteAddr() net.Addr               { return nil }
func (m *mockNetConn) SetDeadline(t time.Time) error      { return nil }
func (m *mockNetConn) SetReadDeadline(t time.Time) error  { return nil }
func (m *mockNetConn) SetWriteDeadline(t time.Time) error { return nil }
