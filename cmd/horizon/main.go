package main

import (
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
	http.HandleFunc("/api/users", handleUsers)
	http.HandleFunc("/api/stats", handleStats)
	http.HandleFunc("/api/user/config", handleUserConfig)
	http.HandleFunc("/api/user/renew", handleUserRenew)

	// New Multi-Tenant APIs
	http.HandleFunc("/api/configs", handleConfigs)
	http.HandleFunc("/api/groups", handleGroups)
	http.HandleFunc("/api/groups/configs", handleGroupConfigs)
	http.HandleFunc("/api/users/assign-group", handleUserGroup)

	// 🛡️ Project Enigma
	http.HandleFunc("/api/v1/secure", handleSecure)
	http.HandleFunc("/api/v1/test-secure", handleTestSecure) // Unencrypted for development
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

	log.Println("✅ Schema Check Complete.")
}

// ========== EXISTING HANDLERS ==========

func handleNodes(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		rows, _ := db.DB.Query("SELECT id, name, ip, status FROM nodes")
		defer rows.Close()
		var list []map[string]interface{}
		for rows.Next() {
			var id int
			var name, ip, status string
			rows.Scan(&id, &name, &ip, &status)
			list = append(list, map[string]interface{}{
				"id": id, "name": name, "ip": ip, "status": status,
			})
		}
		json.NewEncoder(w).Encode(list)
	case "POST":
		var n struct {
			Name string `json:"name"`
			IP   string `json:"ip"`
			Key  string `json:"key"`
		}
		json.NewDecoder(r.Body).Decode(&n)
		_, err := db.DB.Exec("INSERT INTO nodes (name, ip, admin_port, master_key, status) VALUES (?, ?, '8081', ?, 'active')",
			n.Name, n.IP, n.Key)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	case "PUT":
		var n struct {
			ID   int    `json:"id"`
			Name string `json:"name"`
			IP   string `json:"ip"`
		}
		json.NewDecoder(r.Body).Decode(&n)
		_, err := db.DB.Exec("UPDATE nodes SET name=?, ip=? WHERE id=?", n.Name, n.IP, n.ID)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	case "DELETE":
		idStr := r.URL.Query().Get("id")
		_, err := db.DB.Exec("DELETE FROM nodes WHERE id=?", idStr)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	}
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
		rows, _ := db.DB.Query(`
			SELECT c.id, c.name, c.protocol, c.port, c.status, n.name as node_name
			FROM core_configs c
			LEFT JOIN nodes n ON c.node_id = n.id
		`)
		defer rows.Close()
		var list []map[string]interface{}
		for rows.Next() {
			var id int
			var name, protocol, port, status, nodeName string
			rows.Scan(&id, &name, &protocol, &port, &status, &nodeName)
			list = append(list, map[string]interface{}{
				"id": id, "name": name, "protocol": protocol, "port": port,
				"status": status, "node_name": nodeName,
			})
		}
		json.NewEncoder(w).Encode(list)
	case "POST":
		var c struct {
			Name     string `json:"name"`
			NodeID   int    `json:"node_id"`
			Protocol string `json:"protocol"`
			Port     string `json:"port"`
			Settings string `json:"settings"`
		}
		json.NewDecoder(r.Body).Decode(&c)
		_, err := db.DB.Exec("INSERT INTO core_configs (name, node_id, protocol, port, settings) VALUES (?, ?, ?, ?, ?)",
			c.Name, c.NodeID, c.Protocol, c.Port, c.Settings)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	case "PUT":
		var c struct {
			ID       int    `json:"id"`
			Name     string `json:"name"`
			Protocol string `json:"protocol"`
			Port     string `json:"port"`
		}
		json.NewDecoder(r.Body).Decode(&c)
		_, err := db.DB.Exec("UPDATE core_configs SET name=?, protocol=?, port=? WHERE id=?",
			c.Name, c.Protocol, c.Port, c.ID)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	case "DELETE":
		id := r.URL.Query().Get("id")
		_, err := db.DB.Exec("DELETE FROM core_configs WHERE id=?", id)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	}
}

func handleGroups(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "GET":
		rows, _ := db.DB.Query("SELECT id, name, description FROM groups")
		defer rows.Close()
		var list []map[string]interface{}
		for rows.Next() {
			var id int
			var name, description string
			rows.Scan(&id, &name, &description)

			// Get configs for this group
			configsRows, _ := db.DB.Query(`
				SELECT c.id, c.name 
				FROM core_configs c
				JOIN group_configs gc ON c.id = gc.config_id
				WHERE gc.group_id = ?
			`, id)
			defer configsRows.Close()
			var configs []map[string]interface{}
			for configsRows.Next() {
				var cid int
				var cname string
				configsRows.Scan(&cid, &cname)
				configs = append(configs, map[string]interface{}{"id": cid, "name": cname})
			}

			list = append(list, map[string]interface{}{
				"id": id, "name": name, "description": description, "configs": configs,
			})
		}
		json.NewEncoder(w).Encode(list)
	case "POST":
		var g struct {
			Name        string `json:"name"`
			Description string `json:"description"`
		}
		json.NewDecoder(r.Body).Decode(&g)
		_, err := db.DB.Exec("INSERT INTO groups (name, description) VALUES (?, ?)", g.Name, g.Description)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	case "PUT":
		var g struct {
			ID          int    `json:"id"`
			Name        string `json:"name"`
			Description string `json:"description"`
		}
		json.NewDecoder(r.Body).Decode(&g)
		_, err := db.DB.Exec("UPDATE groups SET name=?, description=? WHERE id=?", g.Name, g.Description, g.ID)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	case "DELETE":
		id := r.URL.Query().Get("id")
		// Clean up references
		db.DB.Exec("DELETE FROM user_groups WHERE group_id=?", id)
		db.DB.Exec("DELETE FROM group_configs WHERE group_id=?", id)
		// Delete group
		_, err := db.DB.Exec("DELETE FROM groups WHERE id=?", id)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	}
}

func handleGroupConfigs(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case "POST":
		var gc struct {
			GroupID  int `json:"group_id"`
			ConfigID int `json:"config_id"`
		}
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
		var ug struct {
			UserUUID string `json:"user_uuid"`
			GroupID  int    `json:"group_id"`
		}
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
			// Check if this device is ALREADY registered to this user (re-install scenario)
			var existing int
			check := db.DB.QueryRow(`
				SELECT 1 FROM user_devices ud 
				JOIN devices d ON ud.device_id = d.id 
				WHERE ud.user_uuid=? AND d.hardware_id=?`, req.UserUUID, req.HardwareID).Scan(&existing)

			if check != nil {
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
		rows, err := db.DB.Query("SELECT ip_address, admin_port FROM nodes WHERE status='active'")
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
			rows, err = db.DB.Query(`
				SELECT d.id, d.hardware_id, d.label, d.status, d.last_seen, u.uuid, u.name 
				FROM devices d 
				JOIN user_devices ud ON d.id = ud.device_id 
				JOIN users u ON ud.user_uuid = u.uuid
				WHERE u.uuid = ?`, userUUID)
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
