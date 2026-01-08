package client

import (
	"database/sql"
	"strings"

	_ "github.com/mattn/go-sqlite3"
)

// ConfigLoader reads user configurations from Horizon database
type ConfigLoader struct {
	DB *sql.DB
}

// UserConfig represents a user's VPN configuration from Horizon
type UserConfig struct {
	UUID      string
	Name      string
	LimitGB   float64
	UsedBytes int64
	Protocols []string // ["flux", "darkmatter", "nebula"]
	GroupName string
}

// NewConfigLoader creates a new config loader connected to Horizon database
func NewConfigLoader(dbPath string) (*ConfigLoader, error) {
	db, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		return nil, err
	}

	// Test connection
	if err := db.Ping(); err != nil {
		return nil, err
	}

	return &ConfigLoader{DB: db}, nil
}

// GetUserConfig returns the configuration for a specific user
func (cl *ConfigLoader) GetUserConfig(uuid string) (*UserConfig, error) {
	uc := &UserConfig{UUID: uuid}

	// 1. Get user basic info
	err := cl.DB.QueryRow(`
		SELECT name, limit_gb, used_bytes, status
		FROM users WHERE uuid = ?
	`, uuid).Scan(&uc.Name, &uc.LimitGB, &uc.UsedBytes, new(string))

	if err != nil {
		return nil, err // User not found
	}

	// 2. Get user's group
	var groupID int
	var groupName string
	err = cl.DB.QueryRow(`
		SELECT g.id, g.name
		FROM groups g
		JOIN user_groups ug ON g.id = ug.group_id
		WHERE ug.user_uuid = ?
	`, uuid).Scan(&groupID, &groupName)

	if err == sql.ErrNoRows {
		// User not in any group - no protocols assigned
		uc.Protocols = []string{}
		return uc, nil
	} else if err != nil {
		return nil, err
	}

	uc.GroupName = groupName

	// 3. Get all configs assigned to the group
	rows, err := cl.DB.Query(`
		SELECT DISTINCT c.protocol
		FROM core_configs c
		JOIN group_configs gc ON c.id = gc.config_id
		WHERE gc.group_id = ? AND c.status = 'active'
	`, groupID)

	if err != nil {
		return nil, err
	}
	defer rows.Close()

	protocolSet := make(map[string]bool)

	for rows.Next() {
		var protocolStr string
		rows.Scan(&protocolStr)

		// Handle "auto" - all protocols
		if protocolStr == "auto" {
			uc.Protocols = []string{"flux", "darkmatter", "nebula", "siren"}
			return uc, nil
		}

		// Handle comma-separated protocols: "flux,darkmatter,nebula"
		protocols := parseProtocols(protocolStr)
		for _, p := range protocols {
			protocolSet[p] = true
		}
	}

	// Convert set to slice
	for p := range protocolSet {
		uc.Protocols = append(uc.Protocols, p)
	}

	return uc, nil
}

// IsProtocolAllowed checks if user is allowed to use a specific protocol
func (cl *ConfigLoader) IsProtocolAllowed(uuid, protocol string) bool {
	config, err := cl.GetUserConfig(uuid)
	if err != nil {
		return false
	}

	for _, p := range config.Protocols {
		if p == protocol {
			return true
		}
	}
	return false
}

// GetAllUsers returns all users in Horizon database
func (cl *ConfigLoader) GetAllUsers() ([]UserConfig, error) {
	rows, err := cl.DB.Query(`SELECT uuid FROM users`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var users []UserConfig
	for rows.Next() {
		var uuid string
		rows.Scan(&uuid)

		config, err := cl.GetUserConfig(uuid)
		if err != nil {
			continue // Skip invalid users
		}
		users = append(users, *config)
	}

	return users, nil
}

// NodeConfig represents a server-side listener configuration
type NodeConfig struct {
	Protocol string
	Port     int
	Settings string
}

// GetNodeConfigs returns all active configurations for a specific node
func (cl *ConfigLoader) GetNodeConfigs(nodeID int) ([]NodeConfig, error) {
	rows, err := cl.DB.Query(`
		SELECT protocol, port, settings 
		FROM core_configs 
		WHERE node_id = ? AND status = 'active'
	`, nodeID)

	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var configs []NodeConfig
	for rows.Next() {
		var nc NodeConfig
		rows.Scan(&nc.Protocol, &nc.Port, &nc.Settings)
		configs = append(configs, nc)
	}

	return configs, nil
}

// Close closes the database connection
func (cl *ConfigLoader) Close() error {
	return cl.DB.Close()
}

// parseProtocols splits comma-separated protocol string
func parseProtocols(s string) []string {
	if s == "" {
		return []string{}
	}

	parts := strings.Split(s, ",")
	var result []string
	for _, p := range parts {
		trimmed := strings.TrimSpace(p)
		if trimmed != "" {
			result = append(result, trimmed)
		}
	}
	return result
}
