package main

import (
	"bytes"
	"crypto/sha256"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"aether/internal/horizon/core"
	"aether/internal/horizon/db"
	"aether/pkg/enigma"

	"github.com/google/uuid"
)

func main() {
	log.Println("🌅 Starting Project Horizon (Backend)...")
	db.Init("horizon.db")
	go core.StartSyncer()

	// Existing APIs
	http.HandleFunc("/api/nodes", handleNodes)
	http.HandleFunc("/api/nodes/config", handleNodesConfig)
	http.HandleFunc("/api/nodes/assign", handleNodeConfigsAssign)
	http.HandleFunc("/api/users", handleUsers)
	http.HandleFunc("/api/stats", handleStats)
	http.HandleFunc("/api/user/config", handleUserConfig)
	http.HandleFunc("/api/user/renew", handleUserRenew)

	// New Multi-Tenant APIs
	http.HandleFunc("/api/configs", handleConfigs) // Defined
	http.HandleFunc("/api/groups", handleGroups)
	http.HandleFunc("/api/user_templates", handleUserTemplates)
	http.HandleFunc("/api/user/from_template", handleUserFromTemplate)
	http.HandleFunc("/api/users/bulk/from_template", handleUsersBulkFromTemplate)
	http.HandleFunc("/sub", handleSubscription)
	http.HandleFunc("/api/admin/stats", handleAdminStats)
	// http.HandleFunc("/api/groups/configs", handleGroupConfigs)
	http.HandleFunc("/api/users/assign-group", handleUserGroup)

	// 🛡️ Project Enigma
	// http.HandleFunc("/api/v1/secure", handleSecure)
	// http.HandleFunc("/api/v1/test-secure", handleTestSecure) // Unencrypted for development
	http.HandleFunc("/api/devices", handleDevices)

	log.Println("🚀 Horizon Backend running on :8080")
	log.Println("🚀 Horizon Backend running on :8080")

	// Run Migrations Synchronously
	migrateSchema()

	http.ListenAndServe(":8080", nil)
}

func migrateSchema() {
	log.Println("🔄 Checking Database Schema...")

	// 1. Configs Port Migration (Int -> Text)
	var cid int
	var name, ctype string
	var notnull, pk int
	var dfltValue interface{}

	needsPortMigration := false
	rows, err := db.DB.Query("PRAGMA table_info(core_configs)")
	if err != nil {
		log.Println("❌ Schema Check Error (core_configs):", err)
	} else {
		for rows.Next() {
			rows.Scan(&cid, &name, &ctype, &notnull, &dfltValue, &pk)
			if name == "port" && ctype != "TEXT" {
				needsPortMigration = true
			}
		}
		rows.Close()
	}

	if needsPortMigration {
		log.Println("⚠️ Migrating 'port' column to TEXT...")
		_, err := db.DB.Exec(`
			ALTER TABLE core_configs ADD COLUMN port_new TEXT;
			UPDATE core_configs SET port_new = CAST(port AS TEXT);
			ALTER TABLE core_configs DROP COLUMN port;
			ALTER TABLE core_configs RENAME COLUMN port_new TO port;
		`)
		if err != nil {
			log.Println("❌ Port Migration Failed:", err)
		} else {
			log.Println("✅ Port Migration Successful.")
		}
	}

	// 2. Users Device Limit Migration
	needsLimitMigration := true
	rows, err = db.DB.Query("PRAGMA table_info(users)")
	if err != nil {
		log.Println("❌ Schema Check Error (users):", err)
	} else {
		log.Println("🔍 Inspecting 'users' table columns:")
		for rows.Next() {
			rows.Scan(&cid, &name, &ctype, &notnull, &dfltValue, &pk)
			log.Printf("   - Column: %s (%s)", name, ctype)
			if name == "device_limit" {
				needsLimitMigration = false
			}
		}
		rows.Close()
	}

	if needsLimitMigration {
		log.Println("⚠️ Adding 'device_limit' column to users...")
		_, err := db.DB.Exec("ALTER TABLE users ADD COLUMN device_limit INTEGER DEFAULT 3")
		if err != nil {
			log.Println("❌ Device Limit Migration Failed:", err)
		} else {
			log.Println("✅ Device Limit Migration Successful.")
		}
	} else {
		log.Println("✅ 'device_limit' column exists.")
	}

	// 3. Multi-Node Configs Migration (Phase 13)
	// Create node_configs table for M:N relationship
	_, err = db.DB.Exec(`
		CREATE TABLE IF NOT EXISTS node_configs (
			node_id INTEGER,
			config_id INTEGER,
			PRIMARY KEY (node_id, config_id),
			FOREIGN KEY(node_id) REFERENCES nodes(id),
			FOREIGN KEY(config_id) REFERENCES core_configs(id)
		)
	`)
	if err != nil {
		log.Println("❌ Failed to create table node_configs:", err)
	}

	// Add raw_inbounds to core_configs if not exists
	needsRawMigration := true
	rows, err = db.DB.Query("PRAGMA table_info(core_configs)")
	if err == nil {
		for rows.Next() {
			rows.Scan(&cid, &name, &ctype, &notnull, &dfltValue, &pk)
			if name == "raw_inbounds" {
				needsRawMigration = false
			}
		}
		rows.Close()
	}

	if needsRawMigration {
		log.Println("⚠️ Adding 'raw_inbounds' column to core_configs...")
		_, err := db.DB.Exec("ALTER TABLE core_configs ADD COLUMN raw_inbounds TEXT")
		if err != nil {
			log.Println("❌ Raw Inbounds Migration Failed:", err)
		} else {
			log.Println("✅ Raw Inbounds Migration Successful.")
		}
	}

	// Phase 13.5: Add base_config to nodes for Global Settings (DNS/Routing)
	needsBaseConfig := true
	rows, err = db.DB.Query("PRAGMA table_info(nodes)")
	if err == nil {
		for rows.Next() {
			rows.Scan(&cid, &name, &ctype, &notnull, &dfltValue, &pk)
			if name == "base_config" {
				needsBaseConfig = false
			}
		}
		rows.Close()
	}

	if needsBaseConfig {
		log.Println("⚠️ Adding 'base_config' column to nodes...")
		_, err := db.DB.Exec("ALTER TABLE nodes ADD COLUMN base_config TEXT")
		if err != nil {
			log.Println("❌ Base Config Migration Failed:", err)
		} else {
			log.Println("✅ Base Config Migration Successful.")
		}
	}

	// Phase 14: Groups Access Control Migration
	_, err = db.DB.Exec(`
		CREATE TABLE IF NOT EXISTS groups (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			name TEXT UNIQUE NOT NULL,
			is_disabled BOOLEAN DEFAULT 0
		);

		CREATE TABLE IF NOT EXISTS group_inbounds (
			group_id INTEGER,
			inbound_tag TEXT,
			PRIMARY KEY (group_id, inbound_tag),
			FOREIGN KEY(group_id) REFERENCES groups(id) ON DELETE CASCADE
		);

		CREATE TABLE IF NOT EXISTS user_groups (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			user_uuid TEXT NOT NULL,
			group_id INTEGER NOT NULL,
			FOREIGN KEY(user_uuid) REFERENCES users(uuid) ON DELETE CASCADE,
			FOREIGN KEY(group_id) REFERENCES groups(id) ON DELETE CASCADE,
			UNIQUE(user_uuid, group_id)
		);
	`)
	if err != nil {
		log.Println("❌ Failed to create Group tables:", err)
	}

	// 14.1 Fix Legacy Groups Table (Missing is_disabled)
	needsGroupDisabled := true
	rows, err = db.DB.Query("PRAGMA table_info(groups)")
	if err == nil {
		for rows.Next() {
			rows.Scan(&cid, &name, &ctype, &notnull, &dfltValue, &pk)
			if name == "is_disabled" {
				needsGroupDisabled = false
			}
		}
		rows.Close()
	}

	if needsGroupDisabled {
		log.Println("⚠️ Adding 'is_disabled' column to groups...")
		_, err := db.DB.Exec("ALTER TABLE groups ADD COLUMN is_disabled BOOLEAN DEFAULT 0")
		if err != nil {
			log.Println("❌ Group Disabled Migration Failed:", err)
		} else {
			log.Println("✅ Group Disabled Migration Successful.")
		}
	}

	// Phase 15: User Templates Migration
	_, err = db.DB.Exec(`
		CREATE TABLE IF NOT EXISTS user_templates (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			name TEXT UNIQUE NOT NULL,
			data_limit INTEGER DEFAULT 0,
			expire_duration INTEGER DEFAULT 0,
			username_prefix TEXT,
			username_suffix TEXT,
			status TEXT DEFAULT 'active',
			data_limit_reset_strategy TEXT DEFAULT 'no_reset',
			extra_settings TEXT, -- JSON
			is_disabled BOOLEAN DEFAULT 0
		);

		CREATE TABLE IF NOT EXISTS template_group_association (
			template_id INTEGER,
			group_id INTEGER,
			PRIMARY KEY (template_id, group_id),
			FOREIGN KEY(template_id) REFERENCES user_templates(id) ON DELETE CASCADE,
			FOREIGN KEY(group_id) REFERENCES groups(id) ON DELETE CASCADE
		);
	`)
	if err != nil {
		log.Println("❌ Failed to create User Template tables:", err)
	} else {
		log.Println("✅ User Template tables verified.")
	}

	log.Println("✅ Schema Check Complete.")
}

// ========== EXISTING HANDLERS ==========

func handleNodes(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		rows, _ := db.DB.Query("SELECT id, name, ip, admin_port, master_key, status, base_config FROM nodes")
		defer rows.Close()
		var list []map[string]interface{}
		for rows.Next() {
			var id int
			var name, ip, adminPort, masterKey, status string
			var baseConfig sql.NullString
			rows.Scan(&id, &name, &ip, &adminPort, &masterKey, &status, &baseConfig)
			list = append(list, map[string]interface{}{
				"id": id, "name": name, "ip": ip, "admin_port": adminPort,
				"master_key": masterKey, "status": status,
				"base_config": baseConfig.String,
			})
		}
		json.NewEncoder(w).Encode(list)
	case "POST":
		var n struct {
			Name string `json:"name"`
			IP   string `json:"ip"`
		}
		json.NewDecoder(r.Body).Decode(&n)
		// Default base_config with safe defaults
		defaultBase := `{
  "log": { "loglevel": "warning" },
  "dns": { "servers": ["8.8.8.8", "1.1.1.1"] },
  "routing": { "domainStrategy": "IPIfNonMatch", "rules": [] },
  "outbounds": [{ "protocol": "freedom", "tag": "DIRECT" }]
}`
		// Generate Master Key
		masterKey := generateRandomKey()
		adminPort := "8081"

		res, err := db.DB.Exec("INSERT INTO nodes (name, ip, admin_port, master_key, status, base_config) VALUES (?, ?, ?, ?, 'offline', ?)",
			n.Name, n.IP, adminPort, masterKey, defaultBase)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		id, _ := res.LastInsertId()

		json.NewEncoder(w).Encode(map[string]interface{}{
			"id": int(id), "name": n.Name, "ip": n.IP,
			"admin_port": adminPort, "master_key": masterKey,
			"status": "offline", "base_config": defaultBase,
		})

	case "PUT":
		var n struct {
			ID         int    `json:"id"`
			Name       string `json:"name"`
			IP         string `json:"ip"`
			BaseConfig string `json:"base_config"`
		}
		json.NewDecoder(r.Body).Decode(&n)

		// If BaseConfig is provided, update it too
		if n.BaseConfig != "" {
			_, err := db.DB.Exec("UPDATE nodes SET name=?, ip=?, base_config=? WHERE id=?", n.Name, n.IP, n.BaseConfig, n.ID)
			if err != nil {
				http.Error(w, err.Error(), 500)
				return
			}
		} else {
			_, err := db.DB.Exec("UPDATE nodes SET name=?, ip=? WHERE id=?", n.Name, n.IP, n.ID)
			if err != nil {
				http.Error(w, err.Error(), 500)
				return
			}
		}

		// Re-fetch to return full object including master key
		var id int
		var name, ip, adminPort, masterKey, status string
		var baseConfig sql.NullString
		db.DB.QueryRow("SELECT id, name, ip, admin_port, master_key, status, base_config FROM nodes WHERE id=?", n.ID).
			Scan(&id, &name, &ip, &adminPort, &masterKey, &status, &baseConfig)

		json.NewEncoder(w).Encode(map[string]interface{}{
			"id": id, "name": name, "ip": ip, "admin_port": adminPort,
			"master_key": masterKey, "status": status,
			"base_config": baseConfig.String,
		})
	case "DELETE":
		id := r.URL.Query().Get("id")
		db.DB.Exec("DELETE FROM node_configs WHERE node_id=?", id)
		_, err := db.DB.Exec("DELETE FROM nodes WHERE id=?", id)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	}
}

// Proxy: Forward /api/nodes/config -> http://<NodeIP>:8081/api/config
func handleNodesConfig(w http.ResponseWriter, r *http.Request) {
	idStr := r.URL.Query().Get("id")
	if idStr == "" {
		http.Error(w, "missing node id", 400)
		return
	}

	// 1. Get Node IP
	var ip string
	err := db.DB.QueryRow("SELECT ip FROM nodes WHERE id=?", idStr).Scan(&ip)
	if err != nil {
		http.Error(w, "node not found", 404)
		return
	}

	// 2. Construct Target URL
	targetURL := Stringf("http://%s:8081/api/config", ip)

	// 3. Create Request
	proxyReq, err := http.NewRequest(r.Method, targetURL, r.Body)
	if err != nil {
		http.Error(w, "failed to create request", 500)
		return
	}
	proxyReq.Header = r.Header

	// 4. Send Request
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Do(proxyReq)
	if err != nil {
		http.Error(w, "failed to contact node: "+err.Error(), 502)
		return
	}
	defer resp.Body.Close()

	// 5. Proxy Response
	w.WriteHeader(resp.StatusCode)
	io.Copy(w, resp.Body)
}

// Helper needed because standard fmt.Sprintf is annoying to type repeatedly
func Stringf(format string, a ...any) string {
	return fmt.Sprintf(format, a...)
}

func handleUsers(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		// Modified query to include group_name using LEFT JOIN and device_count
		rows, err := db.DB.Query(`
			SELECT u.uuid, u.name, u.limit_gb, u.device_limit, u.used_bytes, u.expiry, u.status, 
			       g.name, g.id,
			       (SELECT COUNT(*) FROM user_devices WHERE user_uuid = u.uuid) as device_count
			FROM users u
			LEFT JOIN user_groups ug ON u.uuid = ug.user_uuid
			LEFT JOIN groups g ON ug.group_id = g.id
		`)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		defer rows.Close()

		users := []map[string]interface{}{}
		for rows.Next() {
			var uuid, name, status string
			var groupName sql.NullString
			var groupID sql.NullInt64
			var limitGB float64
			var deviceLimit, deviceCount int
			var usedBytes, expiry int64

			err := rows.Scan(&uuid, &name, &limitGB, &deviceLimit, &usedBytes, &expiry, &status, &groupName, &groupID, &deviceCount)
			if err != nil {
				continue
			}

			userMap := map[string]interface{}{
				"uuid":         uuid,
				"name":         name,
				"limit_gb":     limitGB,
				"device_limit": deviceLimit,
				"device_count": deviceCount,
				"used_bytes":   usedBytes,
				"expiry":       expiry,
				"status":       status,
			}

			if groupName.Valid {
				userMap["group_name"] = groupName.String
				userMap["group_id"] = groupID.Int64
			}

			users = append(users, userMap)
		}
		json.NewEncoder(w).Encode(users)
	case "POST":
		var u struct {
			UUID        string  `json:"uuid"`
			Name        string  `json:"name"`
			LimitGB     float64 `json:"limit_gb"`
			DeviceLimit int     `json:"device_limit"`
			Expiry      int64   `json:"expiry"`
		}
		json.NewDecoder(r.Body).Decode(&u)
		if u.UUID == "" {
			u.UUID = uuid.New().String()
		}
		if u.DeviceLimit == 0 {
			u.DeviceLimit = 3
		}
		_, err := db.DB.Exec("INSERT INTO users (uuid, name, limit_gb, device_limit, expiry) VALUES (?, ?, ?, ?, ?)",
			u.UUID, u.Name, u.LimitGB, u.DeviceLimit, u.Expiry)

		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok", "uuid": u.UUID})

	case "PUT":
		var u struct {
			UUID        string  `json:"uuid"`
			Name        string  `json:"name"`
			LimitGB     float64 `json:"limit_gb"`
			DeviceLimit int     `json:"device_limit"`
			Expiry      int64   `json:"expiry"`
			Status      string  `json:"status"`
		}
		json.NewDecoder(r.Body).Decode(&u)

		_, err := db.DB.Exec("UPDATE users SET name=?, limit_gb=?, device_limit=?, expiry=?, status=? WHERE uuid=?",
			u.Name, u.LimitGB, u.DeviceLimit, u.Expiry, u.Status, u.UUID)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	case "DELETE":
		uuid := r.URL.Query().Get("uuid")
		_, err := db.DB.Exec("DELETE FROM users WHERE uuid=?", uuid)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	}
}

func handleStats(w http.ResponseWriter, r *http.Request) {
	var totalUsers, activeNodes int
	var totalTraffic int64
	db.DB.QueryRow("SELECT COUNT(*) FROM users").Scan(&totalUsers)
	db.DB.QueryRow("SELECT COUNT(*) FROM nodes WHERE status='active'").Scan(&activeNodes)
	db.DB.QueryRow("SELECT IFNULL(SUM(used_bytes), 0) FROM users").Scan(&totalTraffic)
	stats := map[string]interface{}{
		"total_users":      totalUsers,
		"active_nodes":     activeNodes,
		"total_traffic":    totalTraffic,
		"total_traffic_gb": float64(totalTraffic) / 1e9,
	}
	json.NewEncoder(w).Encode(stats)
}

func handleUserConfig(w http.ResponseWriter, r *http.Request) {
	uuid := r.URL.Query().Get("uuid")
	if uuid == "" {
		http.Error(w, "uuid required", 400)
		return
	}

	// 1. Get user name (check existence)
	var name string
	err := db.DB.QueryRow("SELECT name FROM users WHERE uuid=?", uuid).Scan(&name)
	if err != nil {
		http.Error(w, "user not found", 404)
		return
	}

	// 2. Get user's group (ensure it exists in groups table)
	var groupID int
	err = db.DB.QueryRow(`
		SELECT ug.group_id 
		FROM user_groups ug 
		JOIN groups g ON ug.group_id = g.id 
		WHERE ug.user_uuid=?`, uuid).Scan(&groupID)

	// If user is not in a group, fall back to "Main Server" default config (flux/tcp)
	// If user is not in a group, return empty configs
	if err == sql.ErrNoRows {
		json.NewEncoder(w).Encode(map[string]interface{}{
			"user":    uuid,
			"configs": []map[string]interface{}{},
		})
		return
	}

	// 3. Fetch configs for the group
	rows, err := db.DB.Query(`
		SELECT c.name, c.protocol, c.port, c.settings, n.ip 
		FROM core_configs c
		JOIN group_configs gc ON c.id = gc.config_id
		JOIN nodes n ON c.node_id = n.id
		WHERE gc.group_id = ? AND c.status = 'active'
	`, groupID)

	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	defer rows.Close()

	var clientConfigs []map[string]interface{}

	for rows.Next() {
		var cName, protocolStr, settings, nodeIP, portStr string
		rows.Scan(&cName, &protocolStr, &portStr, &settings, &nodeIP)

		// Parse protocols
		var protocols []string
		if protocolStr == "auto" {
			protocols = []string{"flux", "darkmatter", "nebula", "siren"}
		} else {
			parts := strings.Split(protocolStr, ",")
			for _, p := range parts {
				p = strings.TrimSpace(p)
				if p != "" {
					protocols = append(protocols, p)
				}
			}
		}

		// Create entry for each protocol
		for _, p := range protocols {
			// Try to convert port to int for standard clients
			var portVal interface{} = portStr
			if pInt, err := strconv.Atoi(portStr); err == nil {
				portVal = pInt
			}

			clientConfigs = append(clientConfigs, map[string]interface{}{
				"label":    fmt.Sprintf("%s - %s", cName, strings.ToUpper(p)),
				"protocol": p,
				"server":   nodeIP,
				"port":     portVal,
				"uuid":     uuid,
				"settings": settings,
				"_meta": map[string]string{
					"core_name":        cName,
					"protocol_display": strings.ToUpper(p),
				},
			})
		}
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"user":    uuid,
		"configs": clientConfigs,
	})
}

func handleUserRenew(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "POST required", 405)
		return
	}
	var req struct {
		OldUUID string `json:"old_uuid"`
	}
	json.NewDecoder(r.Body).Decode(&req)
	newUUID := fmt.Sprintf("%x", sha256.Sum256([]byte(fmt.Sprintf("%d", time.Now().UnixNano()))))[:32]
	_, err := db.DB.Exec("UPDATE users SET uuid=? WHERE uuid=?", newUUID, req.OldUUID)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	json.NewEncoder(w).Encode(map[string]string{
		"status":   "ok",
		"new_uuid": newUUID,
	})
}

// ========== NEW MULTI-TENANT HANDLERS ==========

func handleConfigs(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		// Phase 13: Fetch configs. If node_id is null, it's a template.
		// Also fetch node count for templates.
		rows, _ := db.DB.Query(`
			SELECT c.id, c.name, c.protocol, c.port, c.status, c.raw_inbounds,
			       COUNT(nc.node_id) as node_count
			FROM core_configs c
			LEFT JOIN node_configs nc ON c.id = nc.config_id
			GROUP BY c.id
		`)
		defer rows.Close()
		var list []map[string]interface{}
		for rows.Next() {
			var id, nodeCount int
			var name, protocol, port, status string
			var rawInbounds sql.NullString
			rows.Scan(&id, &name, &protocol, &port, &status, &rawInbounds, &nodeCount)
			list = append(list, map[string]interface{}{
				"id": id, "name": name, "protocol": protocol, "port": port,
				"status": status, "raw_inbounds": rawInbounds.String, "node_count": nodeCount,
			})
		}
		json.NewEncoder(w).Encode(list)
	case "POST":
		var c struct {
			Name        string `json:"name"`
			Protocol    string `json:"protocol"`
			Port        string `json:"port"`
			Settings    string `json:"settings"`
			RawInbounds string `json:"raw_inbounds"`
		}
		json.NewDecoder(r.Body).Decode(&c)
		// NodeID is no longer required for Templates
		_, err := db.DB.Exec("INSERT INTO core_configs (name, protocol, port, settings, raw_inbounds) VALUES (?, ?, ?, ?, ?)",
			c.Name, c.Protocol, c.Port, c.Settings, c.RawInbounds)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	case "PUT":
		var c struct {
			ID          int    `json:"id"`
			Name        string `json:"name"`
			Protocol    string `json:"protocol"`
			Port        string `json:"port"`
			RawInbounds string `json:"raw_inbounds"`
		}
		json.NewDecoder(r.Body).Decode(&c)
		_, err := db.DB.Exec("UPDATE core_configs SET name=?, protocol=?, port=?, raw_inbounds=? WHERE id=?",
			c.Name, c.Protocol, c.Port, c.RawInbounds, c.ID)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	case "DELETE":
		id := r.URL.Query().Get("id")
		// Clean up links first
		db.DB.Exec("DELETE FROM node_configs WHERE config_id=?", id)
		db.DB.Exec("DELETE FROM group_configs WHERE config_id=?", id)
		_, err := db.DB.Exec("DELETE FROM core_configs WHERE id=?", id)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	}
}

// Phase 13: Manage Node <-> Config Assignments
func handleNodeConfigsAssign(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET": // Get assigned config IDs for a node
		nodeID := r.URL.Query().Get("node_id")
		rows, _ := db.DB.Query("SELECT config_id FROM node_configs WHERE node_id=?", nodeID)
		defer rows.Close()
		var ids []int
		for rows.Next() {
			var cid int
			rows.Scan(&cid)
			ids = append(ids, cid)
		}
		json.NewEncoder(w).Encode(ids)
	case "POST": // Assign multiple configs to a node (Replace All)
		var req struct {
			NodeID    int   `json:"node_id"`
			ConfigIDs []int `json:"config_ids"`
		}
		json.NewDecoder(r.Body).Decode(&req)

		// Transaction? Simulating for now.
		// 1. Clear existing
		_, err := db.DB.Exec("DELETE FROM node_configs WHERE node_id=?", req.NodeID)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}

		// 2. Add new
		for _, cid := range req.ConfigIDs {
			db.DB.Exec("INSERT INTO node_configs (node_id, config_id) VALUES (?, ?)", req.NodeID, cid)
		}

		// 3. Trigger Config Push to Agent
		if err := pushNodeConfig(req.NodeID); err != nil {
			log.Printf("⚠️ Config Push Failed for Node %d: %v", req.NodeID, err)
			http.Error(w, "Saved, but failed to push to node: "+err.Error(), 500)
			return
		}

		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	}
}

// pushNodeConfig fetches all assigned configs, merges them, and pushes to Agent
func pushNodeConfig(nodeID int) error {
	// 1. Get Node Information
	var ip, adminPort, masterKey string
	var baseConfigRaw sql.NullString
	err := db.DB.QueryRow("SELECT ip, admin_port, master_key, base_config FROM nodes WHERE id=?", nodeID).
		Scan(&ip, &adminPort, &masterKey, &baseConfigRaw)
	if err != nil {
		return fmt.Errorf("node not found")
	}

	// 2. Fetch all raw_inbounds for this node
	rows, err := db.DB.Query(`
		SELECT c.raw_inbounds 
		FROM core_configs c 
		JOIN node_configs nc ON c.id = nc.config_id 
		WHERE nc.node_id = ?
	`, nodeID)
	if err != nil {
		return err
	}
	defer rows.Close()

	var allInbounds []map[string]interface{}

	for rows.Next() {
		var raw sql.NullString
		rows.Scan(&raw)
		if raw.Valid && raw.String != "" {
			trimmed := strings.TrimSpace(raw.String)
			var list []map[string]interface{}

			// Handle Array vs Single Object
			if strings.HasPrefix(trimmed, "[") {
				json.Unmarshal([]byte(trimmed), &list)
			} else {
				var single map[string]interface{}
				json.Unmarshal([]byte(trimmed), &single)
				list = append(list, single)
			}

			// 2.5 Inject Users per Inbound
			for _, inbound := range list {
				// Get Protocol & Tag
				tag, _ := inbound["tag"].(string)
				protocol, _ := inbound["protocol"].(string)

				if tag == "" {
					allInbounds = append(allInbounds, inbound) // Skip if no tag
					continue
				}

				// Fetch Users allowed for this tag
				// TODO: Optimize query (prepare once)
				uRows, err := db.DB.Query(`
					SELECT u.uuid, u.name 
					FROM users u 
					JOIN user_groups ug ON u.uuid = ug.user_uuid 
					JOIN group_inbounds gi ON ug.group_id = gi.group_id 
					WHERE gi.inbound_tag = ? AND u.status = 'active'
				`, tag)

				if err != nil {
					log.Println("Error fetching users for tag:", tag, err)
					allInbounds = append(allInbounds, inbound)
					continue
				}

				var clients []map[string]interface{}

				// Read template flow/alterId from first client if exists
				var templateFlow string
				var templateAlterId float64 = 0

				settingsMap, _ := inbound["settings"].(map[string]interface{})
				if settingsMap != nil {
					if existingClients, ok := settingsMap["clients"].([]interface{}); ok && len(existingClients) > 0 {
						if first, ok := existingClients[0].(map[string]interface{}); ok {
							if f, ok := first["flow"].(string); ok {
								templateFlow = f
							}
							if a, ok := first["alterId"].(float64); ok {
								templateAlterId = a
							}
						}
					}
				} else {
					settingsMap = make(map[string]interface{})
				}

				for uRows.Next() {
					var uuid, name string
					uRows.Scan(&uuid, &name)

					client := map[string]interface{}{
						"id":    uuid,
						"email": name,
					}

					// Protocol Specifics
					if protocol == "vless" {
						if templateFlow != "" {
							client["flow"] = templateFlow
						}
					} else if protocol == "vmess" {
						client["alterId"] = templateAlterId
					} else if protocol == "trojan" {
						client["password"] = uuid
						delete(client, "id") // Trojan uses password
					}

					clients = append(clients, client)
				}
				uRows.Close()

				// Overwrite clients
				settingsMap["clients"] = clients
				inbound["settings"] = settingsMap

				allInbounds = append(allInbounds, inbound)
			}
		}
	}

	// 3. Construct Full Config
	var finalConfig map[string]interface{}
	defaultBase := `{
		"log": { "loglevel": "warning" },
	// 3. Construct Final Config
	finalConfig := make(map[string]interface{})
	if baseConfigRaw.Valid && baseConfigRaw.String != "" {
		json.Unmarshal([]byte(baseConfigRaw.String), &finalConfig)
	} else {
		// Use default if empty
		json.Unmarshal([]byte(defaultBase), &finalConfig)
	}

	// Always Overlay API, Stats, Policy (Required for Usage Tracking)
	finalConfig["stats"] = map[string]interface{}{}
	finalConfig["api"] = map[string]interface{}{
		"tag":      "api",
		"services": []string{"StatsService"},
	}
	finalConfig["policy"] = map[string]interface{}{
		"levels": map[string]interface{}{
			"0": map[string]interface{}{
				"statsUserUplink":   true,
				"statsUserDownlink": true,
			},
		},
	}
	// Merge routing rules or ensure API rule exists
	// Ideally we parse existing routing, but for now let's ensure API rule is present
	routing, _ := finalConfig["routing"].(map[string]interface{})
	if routing == nil {
		routing = make(map[string]interface{})
		finalConfig["routing"] = routing
	}
	rules, _ := routing["rules"].([]interface{})
	// Prepend API rule
	apiRule := map[string]interface{}{
		"type":        "field",
		"inboundTag":  []string{"api"},
		"outboundTag": "api",
	}
	// Check duplicates? For now just append to front or back. Front is safer.
	newRules := append([]interface{}{apiRule}, rules...)
	routing["rules"] = newRules

	// Add API Inbound
	apiInbound := map[string]interface{}{
		"tag":      "api",
		"port":     10085,
		"listen":   "127.0.0.1",
		"protocol": "dokodemo-door",
		"settings": map[string]interface{}{
			"address": "127.0.0.1",
		},
	}
	allInbounds = append(allInbounds, apiInbound)

	finalConfig["inbounds"] = allInbounds

	// Add API Outbound (to satisfy routing rule)
	apiOutbound := map[string]interface{}{
		"tag":      "api",
		"protocol": "freedom",
		"settings": map[string]interface{}{},
	}
	// Append apiOutbound to outbounds
	outbounds, _ := finalConfig["outbounds"].([]interface{})
	finalConfig["outbounds"] = append(outbounds, apiOutbound)

	configBytes, err := json.Marshal(finalConfig)
	if err != nil {
		return err
	}

	// --- 4. Push Config to Agent ---
	agentURL := fmt.Sprintf("http://%s:%s/api/config", ip, adminPort)
	req, err := http.NewRequest("POST", agentURL, bytes.NewBuffer(configBytes))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	if masterKey != "" {
		req.Header.Set("X-Master-Key", masterKey)
	}

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("agent rejected: code %d, body: %s", resp.StatusCode, string(body))
	}

	log.Printf("✅ Config with Users pushed to node %d", nodeID)
	return nil
}

// Helper
func generateRandomKey() string {
	return uuid.New().String()
}

type GroupConfigReq struct {
	GroupID  int `json:"group_id"`
	ConfigID int `json:"config_id"`
}

type UserGroupReq struct {
	UserUUID string `json:"user_uuid"`
	GroupID  int    `json:"group_id"`
}

func handleGroupConfigs(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "POST":
		var gc GroupConfigReq
		json.NewDecoder(r.Body).Decode(&gc)
		_, err := db.DB.Exec("INSERT INTO group_configs (group_id, config_id) VALUES (?, ?)",
			gc.GroupID, gc.ConfigID)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	case "DELETE":
		groupID := r.URL.Query().Get("group_id")
		configID := r.URL.Query().Get("config_id")
		_, err := db.DB.Exec("DELETE FROM group_configs WHERE group_id=? AND config_id=?", groupID, configID)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	}
}

func handleUserGroup(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "POST":
		var ug UserGroupReq
		json.NewDecoder(r.Body).Decode(&ug)
		// Remove existing group assignment first (since we only support 1 group per user for now)
		db.DB.Exec("DELETE FROM user_groups WHERE user_uuid=?", ug.UserUUID)

		// Insert new assignment
		_, err := db.DB.Exec("INSERT INTO user_groups (user_uuid, group_id) VALUES (?, ?)", ug.UserUUID, ug.GroupID)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	case "DELETE":
		userUUID := r.URL.Query().Get("user_uuid")
		groupID := r.URL.Query().Get("group_id")
		_, err := db.DB.Exec("DELETE FROM user_groups WHERE user_uuid=? AND group_id=?", userUUID, groupID)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	default:
		http.Error(w, "Method not allowed", 405)
	}
}

// Enigma Shared Key (In production, use ECDH or safe storage)
var EnigmaKey = []byte("01234567890123456789012345678901") // 32 bytes

func handleSecure(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", 405)
		return
	}

	// 1. Read Encrypted Body
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Read error", 500)
		return
	}
	defer r.Body.Close()

	// 2. Decrypt
	// Body is just the Base64 string directly
	plaintext, err := enigma.Open(string(body), EnigmaKey)
	if err != nil {
		http.Error(w, "Enigma: Decryption failed", 403) // Forbidden if can't decrypt
		return
	}

	log.Printf("🔓 Enigma Decrypted: %s", string(plaintext))

	// 3. Process Request (Simple Echo/Command processor)
	var req struct {
		Action     string `json:"action"`
		Payload    string `json:"payload"`
		HardwareID string `json:"hardware_id"`
		UserUUID   string `json:"user_uuid"`
		Label      string `json:"label"`
	}
	if err := json.Unmarshal(plaintext, &req); err != nil {
		http.Error(w, "Invalid JSON", 400)
		return
	}

	var responseJSON map[string]interface{}

	switch req.Action {
	case "register_device":
		// 1. Check User Limit
		var limit, count int
		err := db.DB.QueryRow("SELECT device_limit FROM users WHERE uuid=?", req.UserUUID).Scan(&limit)
		if err != nil {
			responseJSON = map[string]interface{}{"status": "error", "message": "User not found"}
			break
		}

		db.DB.QueryRow("SELECT COUNT(*) FROM user_devices WHERE user_uuid=?", req.UserUUID).Scan(&count)

		if count >= limit {
			// Check existing
			var existing int
			err := db.DB.QueryRow("SELECT 1 FROM user_devices ud JOIN devices d ON ud.device_id = d.id WHERE ud.user_uuid=? AND d.hardware_id=?", req.UserUUID, req.HardwareID).Scan(&existing)

			if err != nil {
				// Not found
				responseJSON = map[string]interface{}{"status": "error", "message": "Device limit reached"}
				break
			}
		}

		// 2. Insert Device (Ignore if exists)
		_, err = db.DB.Exec("INSERT OR IGNORE INTO devices (hardware_id, label) VALUES (?, ?)", req.HardwareID, req.Label)

		// 3. Link User
		var devID int
		db.DB.QueryRow("SELECT id FROM devices WHERE hardware_id=?", req.HardwareID).Scan(&devID)

		_, err = db.DB.Exec("INSERT OR IGNORE INTO user_devices (user_uuid, device_id) VALUES (?, ?)", req.UserUUID, devID)

		responseJSON = map[string]interface{}{"status": "ok", "message": "Device Registered"}

	case "get_config":
		// Return the full configuration for this user
		// 1. Find User
		var name string
		var limit float64
		err := db.DB.QueryRow("SELECT name, limit_gb FROM users WHERE uuid=?", req.UserUUID).Scan(&name, &limit)
		if err != nil {
			responseJSON = map[string]interface{}{"status": "error", "message": "User not found"}
			break
		}

		// 2. Find Active Nodes
		rows, err := db.DB.Query("SELECT ip, admin_port FROM nodes WHERE status='active'")
		if err != nil {
			responseJSON = map[string]interface{}{"status": "error", "message": "No active nodes"}
			break
		}
		defer rows.Close()

		var nodes []map[string]string
		for rows.Next() {
			var ip, port string
			rows.Scan(&ip, &port)
			// Construct a VLESS or simple config object here
			// For MVP, we pass the raw connection details the client needs
			nodeCfg := map[string]string{
				"type":   "vless",
				"server": ip,
				"port":   "443", // Assuming standard port or derive from node config
				"uuid":   req.UserUUID,
				"flow":   "xtls-rprx-vision",
			}
			nodes = append(nodes, nodeCfg)
		}

		responseJSON = map[string]interface{}{
			"status":           "ok",
			"user":             name,
			"configs":          nodes,
			"subscription_url": fmt.Sprintf("https://api.aether.com/sub/%s", req.UserUUID), // Future
		}

	default:
		responseJSON = map[string]interface{}{
			"status":      "ok",
			"server_time": time.Now().String(),
			"reply":       "Enigma Received: " + req.Action,
		}
	}

	respBytes, _ := json.Marshal(responseJSON)

	// 4. Encrypt Response
	cipherResp, err := enigma.Seal(respBytes, EnigmaKey)
	if err != nil {
		http.Error(w, "Encryption failed", 500)
		return
	}

	w.Write([]byte(cipherResp))
}

func handleDevices(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	switch r.Method {
	case "GET":
		var rows *sql.Rows
		var err error

		userUUID := r.URL.Query().Get("user_uuid")
		if userUUID != "" {
			// Filter by User
			rows, err = db.DB.Query("SELECT d.id, d.hardware_id, d.label, d.status, d.last_seen, u.uuid, u.name FROM devices d JOIN user_devices ud ON d.id = ud.device_id JOIN users u ON ud.user_uuid = u.uuid WHERE u.uuid = ?", userUUID)
		} else {
			// List All
			rows, err = db.DB.Query(`
				SELECT d.id, d.hardware_id, d.label, d.status, d.last_seen, u.uuid, u.name 
				FROM devices d 
				LEFT JOIN user_devices ud ON d.id = ud.device_id 
				LEFT JOIN users u ON ud.user_uuid = u.uuid`)
		}

		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		defer rows.Close()

		var devices []map[string]interface{}
		for rows.Next() {
			var id int
			var hwID, label, status, lastSeen string
			var uUUID, uName sql.NullString

			rows.Scan(&id, &hwID, &label, &status, &lastSeen, &uUUID, &uName)
			devices = append(devices, map[string]interface{}{
				"id":          id,
				"hardware_id": hwID,
				"label":       label,
				"status":      status,
				"last_seen":   lastSeen,
				"user_uuid":   uUUID.String,
				"user_name":   uName.String,
			})
		}
		json.NewEncoder(w).Encode(devices)

	case "POST":
		// Admin adds a device manually
		var req struct {
			UserUUID   string `json:"user_uuid"`
			HardwareID string `json:"hardware_id"`
			Label      string `json:"label"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid JSON", 400)
			return
		}

		// 1. Check Limit
		var limit, count int
		err := db.DB.QueryRow("SELECT device_limit FROM users WHERE uuid=?", req.UserUUID).Scan(&limit)
		if err != nil {
			http.Error(w, "User not found", 404)
			return
		}
		db.DB.QueryRow("SELECT COUNT(*) FROM user_devices WHERE user_uuid=?", req.UserUUID).Scan(&count)

		if count >= limit {
			http.Error(w, "Device limit reached for this user", 403)
			return
		}

		// 2. Insert Device
		_, err = db.DB.Exec("INSERT OR IGNORE INTO devices (hardware_id, label) VALUES (?, ?)", req.HardwareID, req.Label)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}

		// 3. Link User
		// We need the ID. If inserted, LastInsertId works. If ignored, we need to select.
		// Safe way: Select ID by HardwareID
		var devID int
		err = db.DB.QueryRow("SELECT id FROM devices WHERE hardware_id=?", req.HardwareID).Scan(&devID)
		if err != nil {
			http.Error(w, "Failed to retrieve device ID", 500)
			return
		}

		_, err = db.DB.Exec("INSERT OR IGNORE INTO user_devices (user_uuid, device_id) VALUES (?, ?)", req.UserUUID, devID)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}

		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})

	case "DELETE":
		id := r.URL.Query().Get("id")
		// Delete from devices (Cascades usually, but let's be safe or rely on DB checks)
		_, err := db.DB.Exec("DELETE FROM user_devices WHERE device_id=?", id)
		_, err = db.DB.Exec("DELETE FROM devices WHERE id=?", id)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	}
}

// Phase 14: Groups CRUD
func handleGroups(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	switch r.Method {
	case "GET":
		rows, err := db.DB.Query(`
			SELECT g.id, g.name, g.is_disabled, 
			       COUNT(DISTINCT ug.user_uuid) as total_users,
			       GROUP_CONCAT(gi.inbound_tag) as tags
			FROM groups g
			LEFT JOIN user_groups ug ON g.id = ug.group_id
			LEFT JOIN group_inbounds gi ON g.id = gi.group_id
			GROUP BY g.id
		`)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		defer rows.Close()

		var list []map[string]interface{}
		for rows.Next() {
			var id, totalUsers int
			var name string
			var isDisabled bool
			var tags sql.NullString
			rows.Scan(&id, &name, &isDisabled, &totalUsers, &tags)
			tagList := []string{}
			if tags.Valid && tags.String != "" {
				tagList = strings.Split(tags.String, ",")
			}
			list = append(list, map[string]interface{}{
				"id": id, "name": name, "is_disabled": isDisabled,
				"total_users": totalUsers, "inbound_tags": tagList,
			})
		}
		json.NewEncoder(w).Encode(list)

	case "POST":
		var req struct {
			Name        string   `json:"name"`
			InboundTags []string `json:"inbound_tags"`
			IsDisabled  bool     `json:"is_disabled"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid JSON", 400)
			return
		}

		res, err := db.DB.Exec("INSERT INTO groups (name, is_disabled) VALUES (?, ?)", req.Name, req.IsDisabled)
		if err != nil {
			http.Error(w, "Create Failed: "+err.Error(), 500)
			return
		}
		gid, _ := res.LastInsertId()

		// Insert Tags
		for _, tag := range req.InboundTags {
			db.DB.Exec("INSERT INTO group_inbounds (group_id, inbound_tag) VALUES (?, ?)", gid, tag)
		}
		json.NewEncoder(w).Encode(map[string]interface{}{"success": true, "id": gid})

	case "PUT":
		var req struct {
			Id          int      `json:"id"`
			Name        string   `json:"name"`
			InboundTags []string `json:"inbound_tags"`
			IsDisabled  bool     `json:"is_disabled"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid JSON", 400)
			return
		}
		_, err := db.DB.Exec("UPDATE groups SET name=?, is_disabled=? WHERE id=?", req.Name, req.IsDisabled, req.Id)
		if err != nil {
			http.Error(w, "Update Failed", 500)
			return
		}

		// Update Tags (Simple Wipe & Recreate)
		db.DB.Exec("DELETE FROM group_inbounds WHERE group_id=?", req.Id)
		for _, tag := range req.InboundTags {
			db.DB.Exec("INSERT INTO group_inbounds (group_id, inbound_tag) VALUES (?, ?)", req.Id, tag)
		}
		json.NewEncoder(w).Encode(map[string]interface{}{"success": true})

	case "DELETE":
		id := r.URL.Query().Get("id")
		if id == "" {
			http.Error(w, "Missing ID", 400)
			return
		}
		// Cascade delete handles user/inbound associations if ON DELETE CASCADE set.
		// Sqlite needs `PRAGMA foreign_keys = ON` usually, but we can delete manually to be safe.
		db.DB.Exec("DELETE FROM user_groups WHERE group_id=?", id)
		db.DB.Exec("DELETE FROM group_inbounds WHERE group_id=?", id)
		_, err := db.DB.Exec("DELETE FROM groups WHERE id=?", id)
		if err != nil {
			http.Error(w, "Delete Failed", 500)
			return
		}
		json.NewEncoder(w).Encode(map[string]interface{}{"success": true})
	}
}

func handleUserTemplates(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		rows, _ := db.DB.Query("SELECT id, name, data_limit, expire_duration, username_prefix, username_suffix, status, data_limit_reset_strategy, extra_settings, is_disabled FROM user_templates")
		defer rows.Close()
		var list []map[string]interface{}
		for rows.Next() {
			var t struct {
				ID                     int            `json:"id"`
				Name                   string         `json:"name"`
				DataLimit              int64          `json:"data_limit"`
				ExpireDuration         int64          `json:"expire_duration"`
				UsernamePrefix         sql.NullString `json:"username_prefix"`
				UsernameSuffix         sql.NullString `json:"username_suffix"`
				Status                 string         `json:"status"`
				DataLimitResetStrategy string         `json:"data_limit_reset_strategy"`
				ExtraSettings          sql.NullString `json:"extra_settings"`
				IsDisabled             bool           `json:"is_disabled"`
			}
			rows.Scan(&t.ID, &t.Name, &t.DataLimit, &t.ExpireDuration, &t.UsernamePrefix, &t.UsernameSuffix, &t.Status, &t.DataLimitResetStrategy, &t.ExtraSettings, &t.IsDisabled)

			// Get Groups
			gRows, _ := db.DB.Query("SELECT group_id FROM template_group_association WHERE template_id=?", t.ID)
			var groups []int
			for gRows.Next() {
				var gid int
				gRows.Scan(&gid)
				groups = append(groups, gid)
			}
			gRows.Close()

			list = append(list, map[string]interface{}{
				"id":                        t.ID,
				"name":                      t.Name,
				"data_limit":                t.DataLimit,
				"expire_duration":           t.ExpireDuration,
				"username_prefix":           t.UsernamePrefix.String,
				"username_suffix":           t.UsernameSuffix.String,
				"status":                    t.Status,
				"data_limit_reset_strategy": t.DataLimitResetStrategy,
				"extra_settings":            t.ExtraSettings.String,
				"is_disabled":               t.IsDisabled,
				"group_ids":                 groups,
			})
		}
		json.NewEncoder(w).Encode(list)

	case "POST":
		var req struct {
			Name                   string `json:"name"`
			DataLimit              int64  `json:"data_limit"`
			ExpireDuration         int64  `json:"expire_duration"`
			UsernamePrefix         string `json:"username_prefix"`
			UsernameSuffix         string `json:"username_suffix"`
			Status                 string `json:"status"`
			DataLimitResetStrategy string `json:"data_limit_reset_strategy"`
			ExtraSettings          string `json:"extra_settings"`
			IsDisabled             bool   `json:"is_disabled"`
			GroupIDs               []int  `json:"group_ids"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			http.Error(w, "Invalid JSON", 400)
			return
		}

		res, err := db.DB.Exec(`
			INSERT INTO user_templates (name, data_limit, expire_duration, username_prefix, username_suffix, status, data_limit_reset_strategy, extra_settings, is_disabled) 
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
		`, req.Name, req.DataLimit, req.ExpireDuration, req.UsernamePrefix, req.UsernameSuffix, req.Status, req.DataLimitResetStrategy, req.ExtraSettings, req.IsDisabled)

		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}

		tid, _ := res.LastInsertId()
		for _, gid := range req.GroupIDs {
			db.DB.Exec("INSERT INTO template_group_association (template_id, group_id) VALUES (?, ?)", tid, gid)
		}
		json.NewEncoder(w).Encode(map[string]interface{}{"success": true, "id": tid})

	case "PUT":
		var req struct {
			ID                     int    `json:"id"`
			Name                   string `json:"name"`
			DataLimit              int64  `json:"data_limit"`
			ExpireDuration         int64  `json:"expire_duration"`
			UsernamePrefix         string `json:"username_prefix"`
			UsernameSuffix         string `json:"username_suffix"`
			Status                 string `json:"status"`
			DataLimitResetStrategy string `json:"data_limit_reset_strategy"`
			ExtraSettings          string `json:"extra_settings"`
			IsDisabled             bool   `json:"is_disabled"`
			GroupIDs               []int  `json:"group_ids"`
		}
		json.NewDecoder(r.Body).Decode(&req)

		_, err := db.DB.Exec(`
			UPDATE user_templates SET name=?, data_limit=?, expire_duration=?, username_prefix=?, username_suffix=?, status=?, data_limit_reset_strategy=?, extra_settings=?, is_disabled=?
			WHERE id=?
		`, req.Name, req.DataLimit, req.ExpireDuration, req.UsernamePrefix, req.UsernameSuffix, req.Status, req.DataLimitResetStrategy, req.ExtraSettings, req.IsDisabled, req.ID)

		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}

		db.DB.Exec("DELETE FROM template_group_association WHERE template_id=?", req.ID)
		for _, gid := range req.GroupIDs {
			db.DB.Exec("INSERT INTO template_group_association (template_id, group_id) VALUES (?, ?)", req.ID, gid)
		}
		json.NewEncoder(w).Encode(map[string]interface{}{"success": true})

	case "DELETE":
		id := r.URL.Query().Get("id")
		db.DB.Exec("DELETE FROM template_group_association WHERE template_id=?", id)
		_, err := db.DB.Exec("DELETE FROM user_templates WHERE id=?", id)
		if err != nil {
			http.Error(w, "Delete Failed", 500)
			return
		}
		json.NewEncoder(w).Encode(map[string]interface{}{"success": true})
	}
}

func handleUserFromTemplate(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", 405)
		return
	}

	var req struct {
		TemplateID int    `json:"user_template_id"`
		Username   string `json:"username"`
		Note       string `json:"note"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid JSON", 400)
		return
	}

	// 1. Fetch Template
	var t struct {
		DataLimit      int64
		ExpireDuration int64
		Prefix         sql.NullString
		Suffix         sql.NullString
		Status         string
		ResetStrategy  string
		IsDisabled     bool
	}
	err := db.DB.QueryRow("SELECT data_limit, expire_duration, username_prefix, username_suffix, status, data_limit_reset_strategy, is_disabled FROM user_templates WHERE id=?", req.TemplateID).Scan(
		&t.DataLimit, &t.ExpireDuration, &t.Prefix, &t.Suffix, &t.Status, &t.ResetStrategy, &t.IsDisabled,
	)
	if err != nil {
		http.Error(w, "Template not found: "+err.Error(), 404)
		return
	}
	if t.IsDisabled {
		http.Error(w, "Template is disabled", 400)
		return
	}

	// 2. Construct User
	finalUsername := req.Username
	if t.Prefix.Valid {
		finalUsername = t.Prefix.String + finalUsername
	}
	if t.Suffix.Valid {
		finalUsername = finalUsername + t.Suffix.String
	}

	// Check existing username
	var exists int
	db.DB.QueryRow("SELECT COUNT(*) FROM users WHERE name=?", finalUsername).Scan(&exists)
	if exists > 0 {
		http.Error(w, "Username already exists", 409)
		return
	}

	newUUID := uuid.New().String()
	expiry := int64(0)
	if t.ExpireDuration > 0 {
		expiry = time.Now().Add(time.Duration(t.ExpireDuration) * time.Second).Unix()
	}

	// 3. Insert User
	_, err = db.DB.Exec("INSERT INTO users (uuid, name, limit_gb, expiry, status) VALUES (?, ?, ?, ?, ?)",
		newUUID, finalUsername, float64(t.DataLimit)/(1024*1024*1024), expiry, t.Status)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}

	// 4. Assign Groups (Now using UUID)
	rows, _ := db.DB.Query("SELECT group_id FROM template_group_association WHERE template_id=?", req.TemplateID)
	for rows.Next() {
		var gid int
		rows.Scan(&gid)
		db.DB.Exec("INSERT INTO user_groups (user_uuid, group_id) VALUES (?, ?)", newUUID, gid)
	}
	rows.Close()

	json.NewEncoder(w).Encode(map[string]interface{}{"success": true, "uuid": newUUID, "username": finalUsername})
}

func handleUsersBulkFromTemplate(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", 405)
		return
	}

	var req struct {
		TemplateID int    `json:"user_template_id"`
		Count      int    `json:"count"`
		Strategy   string `json:"strategy"` // "random" or "sequence"
		Username   string `json:"username"` // Base for sequence
		Note       string `json:"note"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid JSON", 400)
		return
	}

	if req.Count > 500 || req.Count < 1 {
		http.Error(w, "Count must be between 1 and 500", 400)
		return
	}

	// Fetch Template
	var t struct {
		DataLimit      int64
		ExpireDuration int64
		Prefix         sql.NullString
		Suffix         sql.NullString
		Status         string
		ResetStrategy  string
		IsDisabled     bool
	}
	err := db.DB.QueryRow("SELECT data_limit, expire_duration, username_prefix, username_suffix, status, data_limit_reset_strategy, is_disabled FROM user_templates WHERE id=?", req.TemplateID).Scan(
		&t.DataLimit, &t.ExpireDuration, &t.Prefix, &t.Suffix, &t.Status, &t.ResetStrategy, &t.IsDisabled,
	)
	if err != nil {
		http.Error(w, "Template not found", 404)
		return
	}

	var createdLinks []string
	createdCount := 0

	// Get Groups for Template
	var groupIDs []int
	gRows, _ := db.DB.Query("SELECT group_id FROM template_group_association WHERE template_id=?", req.TemplateID)
	for gRows.Next() {
		var gid int
		gRows.Scan(&gid)
		groupIDs = append(groupIDs, gid)
	}
	gRows.Close()

	for i := 1; i <= req.Count; i++ {
		// Generate Username
		var coreName string
		if req.Strategy == "random" {
			// Random 5 chars
			h := sha256.New()
			h.Write([]byte(fmt.Sprintf("%d-%d", time.Now().UnixNano(), i)))
			hash := fmt.Sprintf("%x", h.Sum(nil))
			coreName = hash[:5]
		} else {
			// Sequence
			coreName = fmt.Sprintf("%s%d", req.Username, i)
		}

		finalUsername := coreName
		if t.Prefix.Valid {
			finalUsername = t.Prefix.String + finalUsername
		}
		if t.Suffix.Valid {
			finalUsername = finalUsername + t.Suffix.String
		}

		// Check Existence
		var exists int
		db.DB.QueryRow("SELECT COUNT(*) FROM users WHERE name=?", finalUsername).Scan(&exists)
		if exists > 0 {
			continue // Skip duplicate
		}

		newUUID := uuid.New().String()
		expiry := int64(0)
		if t.ExpireDuration > 0 {
			expiry = time.Now().Add(time.Duration(t.ExpireDuration) * time.Second).Unix()
		}

		_, err = db.DB.Exec("INSERT INTO users (uuid, name, limit_gb, expiry, status) VALUES (?, ?, ?, ?, ?)",
			newUUID, finalUsername, float64(t.DataLimit)/(1024*1024*1024), expiry, t.Status)

		if err == nil {
			createdCount++
			// Assign Groups
			for _, gid := range groupIDs {
				db.DB.Exec("INSERT INTO user_groups (user_uuid, group_id) VALUES (?, ?)", newUUID, gid)
			}
			// Generate Link (Mock for now, would use real domain)
			link := fmt.Sprintf("https://t.me/PasarGuardBot?start=%s", finalUsername)
			createdLinks = append(createdLinks, link)
		}
	}

	json.NewEncoder(w).Encode(map[string]interface{}{
		"created":           createdCount,
		"subscription_urls": createdLinks,
	})
}
