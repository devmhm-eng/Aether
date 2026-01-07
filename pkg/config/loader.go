package config

import (
	"encoding/json"
	"os"
)

type User struct {
	UUID       string  `json:"uuid"`
	LimitGB    float64 `json:"limit_gb"`    // 0 = Unlimited, Supports decimals (e.g. 0.12)
	UsageBytes int64   `json:"usage_bytes"` // Exact byte count
}

type Config struct {
	ServerAddr string `json:"server_addr"`
	LocalPort  int    `json:"local_port"`
	// Client Side
	ClientUUID string `json:"uuid,omitempty"`
	Transport  string `json:"transport,omitempty"` // "auto", "tcp", "ws"

	// Server Side
	Users        []User `json:"users,omitempty"`
	EnableNebula bool   `json:"enable_nebula,omitempty"`
	IPv6Subnet   string `json:"ipv6_subnet,omitempty"` // e.g. "2001:db8::/64"

	// Client/Server Shared (Dark Matter)
	EnableDarkMatter bool   `json:"enable_dark_matter,omitempty"`
	DarkMatterSecret string `json:"dark_matter_secret,omitempty"`

	// Admin API
	AdminPort  string `json:"admin_port,omitempty"`  // Default 8081
	AdminToken string `json:"admin_token,omitempty"` // Security Token
}

func LoadConfig(path string) (*Config, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	cfg := &Config{}
	dec := json.NewDecoder(file)
	if err := dec.Decode(cfg); err != nil {
		return nil, err
	}
	return cfg, nil
}
