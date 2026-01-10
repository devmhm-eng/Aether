package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"time"

	"aether/internal/horizon/db"
)

// handleTestSecure is identical to handleSecure but without encryption (for testing/development)
func handleTestSecure(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "Method not allowed", 405)
		return
	}

	// 1. Read Plain JSON Body (no encryption)
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "Read error", 500)
		return
	}
	defer r.Body.Close()

	log.Printf("🔓 Test Secure (Unencrypted): %s", string(body))

	// 2. Process Request
	var req struct {
		Action     string `json:"action"`
		Payload    string `json:"payload"`
		HardwareID string `json:"hardware_id"`
		UserUUID   string `json:"user_uuid"`
		Label      string `json:"label"`
	}
	if err := json.Unmarshal(body, &req); err != nil {
		http.Error(w, "Invalid JSON", 400)
		return
	}

	var responseJSON map[string]interface{}

	switch req.Action {
	case "register_device":
		// Check User Limit
		var limit, count int
		err := db.DB.QueryRow("SELECT device_limit FROM users WHERE uuid=?", req.UserUUID).Scan(&limit)
		if err != nil {
			responseJSON = map[string]interface{}{"status": "error", "message": "User not found"}
			break
		}

		db.DB.QueryRow("SELECT COUNT(*) FROM user_devices WHERE user_uuid=?", req.UserUUID).Scan(&count)

		if count >= limit {
			// Check if this device is ALREADY registered to this user
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

		// Insert Device
		_, err = db.DB.Exec("INSERT OR IGNORE INTO devices (hardware_id, label) VALUES (?, ?)", req.HardwareID, req.Label)

		// Link User
		var devID int
		db.DB.QueryRow("SELECT id FROM devices WHERE hardware_id=?", req.HardwareID).Scan(&devID)
		_, err = db.DB.Exec("INSERT OR IGNORE INTO user_devices (user_uuid, device_id) VALUES (?, ?)", req.UserUUID, devID)

		responseJSON = map[string]interface{}{"status": "ok", "message": "Device Registered"}

	case "get_config":
		// Return full configuration
		var name string
		var limit float64
		err := db.DB.QueryRow("SELECT name, limit_gb FROM users WHERE uuid=?", req.UserUUID).Scan(&name, &limit)
		if err != nil {
			responseJSON = map[string]interface{}{"status": "error", "message": "User not found"}
			break
		}

		// Find Active Nodes
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
			nodeCfg := map[string]string{
				"type":   "vless",
				"server": ip,
				"port":   "443",
				"uuid":   req.UserUUID,
				"flow":   "xtls-rprx-vision",
			}
			nodes = append(nodes, nodeCfg)
		}

		responseJSON = map[string]interface{}{
			"status":           "ok",
			"user":             name,
			"configs":          nodes,
			"subscription_url": fmt.Sprintf("https://api.aether.com/sub/%s", req.UserUUID),
		}

	default:
		responseJSON = map[string]interface{}{
			"status":      "ok",
			"server_time": time.Now().String(),
			"reply":       "Test Secure Received: " + req.Action,
		}
	}

	// 3. Return Plain JSON Response (no encryption)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(responseJSON)
}
