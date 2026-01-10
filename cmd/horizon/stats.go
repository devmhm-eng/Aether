package main

import (
	"encoding/json"
	"net/http"

	"aether/internal/horizon/db"
)

type DashboardStats struct {
	TotalUsers     int   `json:"total_users"`
	ActiveUsers    int   `json:"active_users"`
	TotalBandwidth int64 `json:"total_bandwidth"`
	TotalNodes     int   `json:"total_nodes"`
	ActiveNodes    int   `json:"active_nodes"`
}

func handleAdminStats(w http.ResponseWriter, r *http.Request) {
	stats := DashboardStats{}

	// 1. Users Stats
	db.DB.QueryRow("SELECT COUNT(*) FROM users").Scan(&stats.TotalUsers)
	db.DB.QueryRow("SELECT COUNT(*) FROM users WHERE status='active'").Scan(&stats.ActiveUsers)

	// 2. Bandwidth Stats
	var totalBytes interface{} // Handle NULL if no users
	db.DB.QueryRow("SELECT SUM(used_bytes) FROM users").Scan(&totalBytes)
	if totalBytes != nil {
		stats.TotalBandwidth = totalBytes.(int64)
	}

	// 3. Node Stats
	db.DB.QueryRow("SELECT COUNT(*) FROM nodes").Scan(&stats.TotalNodes)
	db.DB.QueryRow("SELECT COUNT(*) FROM nodes WHERE status='active'").Scan(&stats.ActiveNodes)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(stats)
}
