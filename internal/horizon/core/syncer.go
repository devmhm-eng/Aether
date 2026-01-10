package core

import (
	"aether/internal/horizon/db"
	"aether/pkg/config"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"
)

func StartSyncer() {
	ticker := time.NewTicker(30 * time.Second) // Poll every 30s
	for range ticker.C {
		SyncAll()
	}
}

func SyncAll() {
	// 1. Get All Nodes
	rows, err := db.DB.Query("SELECT id, ip, admin_port, master_key FROM nodes WHERE status='active'")
	if err != nil {
		log.Println("Sync Error:", err)
		return
	}
	defer rows.Close()

	// Map to aggregate usage: UserUUID -> TotalBytes
	usageMap := make(map[string]int64)

	type NodeInfo struct {
		ID   int
		IP   string
		Port string
		Key  string
	}
	var nodes []NodeInfo

	for rows.Next() {
		var n NodeInfo
		rows.Scan(&n.ID, &n.IP, &n.Port, &n.Key)
		nodes = append(nodes, n)

		// 2. Poll Node
		stats, err := fetchStats(n.IP, n.Port, n.Key)
		if err != nil {
			log.Printf("❌ Node %s Unreachable: %v", n.IP, err)
			db.DB.Exec("UPDATE nodes SET status='offline' WHERE id=?", n.ID)
			continue
		}

		// Success -> Mark Active
		db.DB.Exec("UPDATE nodes SET status='active' WHERE id=?", n.ID)

		// 3. Aggregate
		for _, u := range stats {
			usageMap[u.UUID] += u.UsageBytes
		}
	}

	// 4. Update DB & Enforce Quotas
	for uuid, totalUsage := range usageMap {
		// Update DB
		_, err := db.DB.Exec("UPDATE users SET used_bytes = ? WHERE uuid = ?", totalUsage, uuid)
		if err != nil {
			continue
		}

		// Check Limit
		var limit float64
		err = db.DB.QueryRow("SELECT limit_gb FROM users WHERE uuid = ?", uuid).Scan(&limit)
		if err == nil && limit > 0 {
			limitBytes := int64(limit * 1024 * 1024 * 1024)
			if totalUsage > limitBytes {
				// 🚫 Disable User Logic (Implementation: Update all nodes to Limits=0 or Remove)
				// For now just log
				log.Printf("🚫 User %s EXCEEDED Quota (%.2fGB / %.2fGB)", uuid, float64(totalUsage)/1e9, limit)
			}
		}
	}
}

func fetchStats(ip, port, key string) ([]config.User, error) {
	client := http.Client{Timeout: 5 * time.Second}
	req, _ := http.NewRequest("GET", fmt.Sprintf("http://%s:%s/admin/stats", ip, port), nil)
	// SECURE: Use Master Key
	if key != "" {
		req.Header.Set("X-Master-Key", key)
	}

	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("status %d", resp.StatusCode)
	}

	var stats []config.User
	if err := json.NewDecoder(resp.Body).Decode(&stats); err != nil {
		return nil, err
	}
	return stats, nil
}
