package xray

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"sync"
)

// Full Xray Config Definitions
type XrayConfig struct {
	Log       LogConfig  `json:"log"`
	Inbounds  []Inbound  `json:"inbounds"`
	Outbounds []Outbound `json:"outbounds"`
}

type LogConfig struct {
	LogLevel string `json:"loglevel"`
}

type Inbound struct {
	Port           int             `json:"port"`
	Protocol       string          `json:"protocol"`
	Settings       json.RawMessage `json:"settings"` // Polymorphic
	StreamSettings *StreamSettings `json:"streamSettings,omitempty"`
	Tag            string          `json:"tag"`
	Sniffing       *SniffingConfig `json:"sniffing,omitempty"`
}

type SniffingConfig struct {
	Enabled      bool     `json:"enabled"`
	DestOverride []string `json:"destOverride"`
}

// Protocol Specific Settings

type VLESSSettings struct {
	Clients    []VLESSClient `json:"clients"`
	Decryption string        `json:"decryption"`
	Fallbacks  []Fallback    `json:"fallbacks,omitempty"`
}

type VLESSClient struct {
	ID    string `json:"id"`
	Flow  string `json:"flow"`
	Email string `json:"email"`
}

type VMessSettings struct {
	Clients []VMessClient `json:"clients"`
}

type VMessClient struct {
	ID      string `json:"id"`
	AlterId int    `json:"alterId"`
	Email   string `json:"email"`
}

type TrojanSettings struct {
	Clients   []TrojanClient `json:"clients"`
	Fallbacks []Fallback     `json:"fallbacks,omitempty"`
}

type TrojanClient struct {
	Password string `json:"password"`
	Email    string `json:"email"`
}

type SOCKSSettings struct {
	Auth     string         `json:"auth"`
	Accounts []SOCKSAccount `json:"accounts,omitempty"`
	UDP      bool           `json:"udp"`
}

type SOCKSAccount struct {
	User string `json:"user"`
	Pass string `json:"pass"`
}

type Fallback struct {
	Dest string `json:"dest"`
	Xver int    `json:"xver"`
}

// Stream Settings

type StreamSettings struct {
	Network         string           `json:"network"`
	Security        string           `json:"security"`
	RealitySettings *RealitySettings `json:"realitySettings,omitempty"`
	WSSettings      *WSSettings      `json:"wsSettings,omitempty"`
	TCPSettings     *TCPSettings     `json:"tcpSettings,omitempty"`
	XHTTPSettings   *XHTTPSettings   `json:"xhttpSettings,omitempty"` // XIP v2 / XHTTP
}

type RealitySettings struct {
	Show        bool     `json:"show"`
	Dest        string   `json:"dest"`
	Xver        int      `json:"xver"`
	ServerNames []string `json:"serverNames"`
	PrivateKey  string   `json:"privateKey"`
	ShortIds    []string `json:"shortIds"`
}

type WSSettings struct {
	Path string `json:"path"`
}

type TCPSettings struct {
	Header TCPHeader `json:"header"`
}

type TCPHeader struct {
	Type string `json:"type"`
}

type XHTTPSettings struct {
	Mode string `json:"mode"` // "auto" or "packet"
	Path string `json:"path"`
}

type Outbound struct {
	Protocol string `json:"protocol"`
}

// Manager handles the local Xray Instance
type Manager struct {
	mu            sync.Mutex
	cmd           *exec.Cmd
	configPath    string
	binPath       string
	CurrentConfig *XrayConfig
}

var GlobalManager *Manager

func InitManager(binPath string) *Manager {
	if binPath == "" {
		binPath = "./xray-core"
	}
	mgr := &Manager{binPath: binPath, configPath: "xray_config.json"}
	if err := mgr.loadConfig(); err != nil {
		mgr.initConfig()
	}
	GlobalManager = mgr
	return mgr
}

func (m *Manager) initConfig() {
	// Generate Default Config with ALL Protocols

	// 1. VLESS Reality (443)
	vlessSettings := VLESSSettings{
		Decryption: "none",
		Clients:    []VLESSClient{},
	}
	vlessBytes, _ := json.Marshal(vlessSettings)

	// 2. VMess WebSocket (8080)
	vmessSettings := VMessSettings{
		Clients: []VMessClient{},
	}
	vmessBytes, _ := json.Marshal(vmessSettings)

	// 3. Trojan TCP (8443) - Simplified (Ideally XTLS too, but standard TCP for now)
	trojanSettings := TrojanSettings{
		Clients: []TrojanClient{},
	}
	trojanBytes, _ := json.Marshal(trojanSettings)

	// 4. SOCKS5 (1080)
	socksSettings := SOCKSSettings{
		Auth: "noauth",
		UDP:  true,
	}
	socksBytes, _ := json.Marshal(socksSettings)

	// 5. VLESS XHTTP (4433) - Experimental
	vlessXhttpBytes, _ := json.Marshal(vlessSettings)

	m.CurrentConfig = &XrayConfig{
		Log: LogConfig{LogLevel: "warning"},
		Inbounds: []Inbound{
			// VLESS Reality
			{
				Tag:      "vless-reality",
				Port:     443,
				Protocol: "vless",
				Settings: vlessBytes,
				StreamSettings: &StreamSettings{
					Network:  "tcp",
					Security: "reality",
					RealitySettings: &RealitySettings{
						Show:        false,
						Dest:        "www.microsoft.com:443",
						Xver:        0,
						ServerNames: []string{"www.microsoft.com"},
						PrivateKey:  "-HLhq9AlpBb9lBLPUbinwvvLT2eqV4Ex3--eYwlmOU4",
						ShortIds:    []string{"12345678"},
					},
				},
				Sniffing: &SniffingConfig{Enabled: true, DestOverride: []string{"http", "tls"}},
			},
			// VMess WebSocket
			{
				Tag:      "vmess-ws",
				Port:     8080,
				Protocol: "vmess",
				Settings: vmessBytes,
				StreamSettings: &StreamSettings{
					Network:    "ws",
					Security:   "none",
					WSSettings: &WSSettings{Path: "/ws"},
				},
			},
			// Trojan
			{
				Tag:      "trojan-tcp",
				Port:     8443,
				Protocol: "trojan",
				Settings: trojanBytes,
				StreamSettings: &StreamSettings{
					Network:  "tcp",
					Security: "none", // Assuming external Nginx handles TLS or simple TCP
				},
			},
			// SOCKS
			{
				Tag:      "socks",
				Port:     1080,
				Protocol: "socks",
				Settings: socksBytes,
			},
			// XHTTP (VLESS)
			{
				Tag:      "vless-xhttp",
				Port:     4433,
				Protocol: "vless",
				Settings: vlessXhttpBytes,
				StreamSettings: &StreamSettings{
					Network:       "xhttp",
					Security:      "none",
					XHTTPSettings: &XHTTPSettings{Mode: "auto", Path: "/xhttp"},
				},
			},
		},
		Outbounds: []Outbound{
			{Protocol: "freedom"},
		},
	}
	m.saveConfig()
}

// ... Load/Save/Start/Stop methods (same as before) ...
func (m *Manager) loadConfig() error {
	data, err := os.ReadFile(m.configPath)
	if err != nil {
		return err
	}
	m.CurrentConfig = &XrayConfig{}
	return json.Unmarshal(data, m.CurrentConfig)
}

func (m *Manager) saveConfig() error {
	data, err := json.MarshalIndent(m.CurrentConfig, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(m.configPath, data, 0644)
}

// UpdateConfig replaces the entire Xray config with the provided JSON
func (m *Manager) UpdateConfig(jsonBytes []byte) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	// Validate JSON
	tempConfig := &XrayConfig{}
	if err := json.Unmarshal(jsonBytes, tempConfig); err != nil {
		return fmt.Errorf("invalid json: %v", err)
	}

	// Backup old config
	os.Rename(m.configPath, m.configPath+".bak")

	// Write new config
	if err := os.WriteFile(m.configPath, jsonBytes, 0644); err != nil {
		return err
	}

	m.CurrentConfig = tempConfig
	return nil
}

func (m *Manager) Start() error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.cmd != nil {
		return fmt.Errorf("running")
	}
	m.cmd = exec.Command(m.binPath, "-config", m.configPath)
	m.cmd.Stdout = os.Stdout
	m.cmd.Stderr = os.Stderr
	return m.cmd.Start()
}

func (m *Manager) Stop() error {
	m.mu.Lock()
	defer m.mu.Unlock()
	if m.cmd != nil && m.cmd.Process != nil {
		m.cmd.Process.Kill()
	}
	m.cmd = nil
	return nil
}

func (m *Manager) Restart() error { m.Stop(); return m.Start() }

// Unified User Management
// Adds the user to ALL supported protocols (VLESS/VMess/Trojan)
func (m *Manager) AddUser(uuid, email string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	for i, in := range m.CurrentConfig.Inbounds {
		switch in.Protocol {
		case "vless":
			var settings VLESSSettings
			json.Unmarshal(in.Settings, &settings)
			found := false
			for _, c := range settings.Clients {
				if c.ID == uuid {
					found = true
				}
			}
			if !found {
				settings.Clients = append(settings.Clients, VLESSClient{ID: uuid, Flow: "xtls-rprx-vision", Email: email})
				bytes, _ := json.Marshal(settings)
				m.CurrentConfig.Inbounds[i].Settings = bytes
			}
		case "vmess":
			var settings VMessSettings
			json.Unmarshal(in.Settings, &settings)
			found := false
			for _, c := range settings.Clients {
				if c.ID == uuid {
					found = true
				}
			}
			if !found {
				settings.Clients = append(settings.Clients, VMessClient{ID: uuid, AlterId: 0, Email: email})
				bytes, _ := json.Marshal(settings)
				m.CurrentConfig.Inbounds[i].Settings = bytes
			}
		case "trojan":
			var settings TrojanSettings
			json.Unmarshal(in.Settings, &settings)
			// Use UUID as Password for simplicity in unified mode
			found := false
			for _, c := range settings.Clients {
				if c.Password == uuid {
					found = true
				}
			}
			if !found {
				settings.Clients = append(settings.Clients, TrojanClient{Password: uuid, Email: email})
				bytes, _ := json.Marshal(settings)
				m.CurrentConfig.Inbounds[i].Settings = bytes
			}
		}
	}
	m.saveConfig()
	return nil
}

func (m *Manager) RemoveUser(uuid string) error {
	m.mu.Lock()
	defer m.mu.Unlock()

	for i, in := range m.CurrentConfig.Inbounds {
		switch in.Protocol {
		case "vless":
			var settings VLESSSettings
			json.Unmarshal(in.Settings, &settings)
			clients := []VLESSClient{}
			for _, c := range settings.Clients {
				if c.ID != uuid {
					clients = append(clients, c)
				}
			}
			settings.Clients = clients
			bytes, _ := json.Marshal(settings)
			m.CurrentConfig.Inbounds[i].Settings = bytes
		case "vmess":
			var settings VMessSettings
			json.Unmarshal(in.Settings, &settings)
			clients := []VMessClient{}
			for _, c := range settings.Clients {
				if c.ID != uuid {
					clients = append(clients, c)
				}
			}
			settings.Clients = clients
			bytes, _ := json.Marshal(settings)
			m.CurrentConfig.Inbounds[i].Settings = bytes
		case "trojan":
			var settings TrojanSettings
			json.Unmarshal(in.Settings, &settings)
			clients := []TrojanClient{}
			for _, c := range settings.Clients {
				if c.Password != uuid {
					clients = append(clients, c)
				}
			}
			settings.Clients = clients
			bytes, _ := json.Marshal(settings)
			m.CurrentConfig.Inbounds[i].Settings = bytes
		}
	}
	m.saveConfig()
	return nil
}
