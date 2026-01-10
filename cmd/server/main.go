package main

import (
	"encoding/json"
	"io"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"aether/pkg/config"
	"aether/pkg/xray"
)

func main() {
	log.SetFlags(log.LstdFlags | log.Lshortfile)
	log.Println("🚀 Horizon Agent (Xray Controller) Starting...")

	// 1. Load Configuration
	cfg, err := config.LoadConfig("config.json")
	if err != nil {
		log.Printf("⚠️ Config not found, using defaults: %v", err)
		cfg = &config.Config{
			AdminPort: "8081",
			MasterKey: "",
		}
	}

	// Environment Variable Overrides (Docker Support)
	if envKey := os.Getenv("MASTER_KEY"); envKey != "" {
		cfg.MasterKey = envKey
	}
	if envPort := os.Getenv("ADMIN_PORT"); envPort != "" {
		cfg.AdminPort = envPort
	}

	if cfg.AdminPort == "" {
		cfg.AdminPort = "8081"
	}
	// Warning if no key
	if cfg.MasterKey == "" {
		log.Println("⚠️  WARNING: NO MASTER KEY CONFIGURED. AGENT IS INSECURE.")
	} else {
		log.Println("🔒 Agent Security Enabled (Master Key Present)")
	}

	// 2. Initialize Xray Manager
	// Check for xray binary in standard locations
	xrayPath := "./xray-core"
	if _, err := os.Stat(xrayPath); os.IsNotExist(err) {
		if _, err := os.Stat("/usr/bin/xray"); err == nil {
			xrayPath = "/usr/bin/xray"
		}
	}
	log.Printf("Using Xray Core at: %s", xrayPath)
	xrayMgr := xray.InitManager(xrayPath)

	// 3. Start Xray Process
	if err := xrayMgr.Start(); err != nil {
		log.Printf("❌ Failed to start Xray Core: %v", err)
		// We don't exit, might be a config issue we can fix via API
	} else {
		log.Println("✅ Xray Core Started Successfully")
	}

	// 4. Setup Admin API

	// MIDDLEWARE: Auth Check
	authMiddleware := func(next http.HandlerFunc) http.HandlerFunc {
		return func(w http.ResponseWriter, r *http.Request) {
			// Skip auth for health check if desired, but for now secure everything except health
			if r.URL.Path == "/api/health" {
				next(w, r)
				return
			}

			// Check Header
			key := r.Header.Get("X-Master-Key")
			if key != cfg.MasterKey && cfg.MasterKey != "" {
				http.Error(w, "Unauthorized", http.StatusUnauthorized)
				return
			}
			next(w, r)
		}
	}

	// Health Check
	http.HandleFunc("/api/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Write([]byte("OK"))
	})

	// Full Config Update API
	http.HandleFunc("/api/config", authMiddleware(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodGet {
			// Return Current Config
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(xrayMgr.CurrentConfig)
			return
		}

		if r.Method == http.MethodPost {
			configBytes, err := io.ReadAll(r.Body)
			if err != nil {
				http.Error(w, "Failed to read body", http.StatusInternalServerError)
				return
			}

			if err := xrayMgr.UpdateConfig(configBytes); err != nil {
				http.Error(w, err.Error(), http.StatusBadRequest)
				return
			}

			if err := xrayMgr.Restart(); err != nil {
				http.Error(w, "Config updated but restart failed", http.StatusInternalServerError)
				return
			}
			w.Write([]byte("Config Updated & Xray Restarted"))
			return
		}

		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
	}))

	// Stats API (Mock for now to satisfy Panel Poller)
	http.HandleFunc("/admin/stats", authMiddleware(func(w http.ResponseWriter, r *http.Request) {
		// In a real implementation, we would query Xray's Stats API (gRPC or HTTP)
		// For now, return empty stats so the Panel sees us as "Online"
		// The Panel expects []config.User
		w.Write([]byte("[]"))
	}))

	// User Management (Dynamic Config Update)
	http.HandleFunc("/api/users", authMiddleware(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodPost {
			// Create User
			uuid := r.URL.Query().Get("uuid")
			email := r.URL.Query().Get("email")
			if uuid == "" {
				http.Error(w, "missing uuid", http.StatusBadRequest)
				return
			}
			if err := xrayMgr.AddUser(uuid, email); err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			// Restart Xray to apply config
			if err := xrayMgr.Restart(); err != nil {
				log.Printf("❌ Failed to restart Xray: %v", err)
				http.Error(w, "User added but Xray restart failed", http.StatusInternalServerError)
				return
			}
			w.Write([]byte("User Added"))

		} else if r.Method == http.MethodDelete {
			// Delete User
			uuid := r.URL.Query().Get("uuid")
			if uuid == "" {
				http.Error(w, "missing uuid", http.StatusBadRequest)
				return
			}
			if err := xrayMgr.RemoveUser(uuid); err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			// Restart Xray
			if err := xrayMgr.Restart(); err != nil {
				log.Printf("❌ Failed to restart Xray: %v", err)
				http.Error(w, "User removed but Xray restart failed", http.StatusInternalServerError)
				return
			}
			w.Write([]byte("User Removed"))

		} else {
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	}))

	go func() {
		addr := "0.0.0.0:" + cfg.AdminPort
		log.Printf("🛠️ Admin API Listening on %s", addr)
		if err := http.ListenAndServe(addr, nil); err != nil {
			log.Fatalf("❌ Admin Server Failed: %v", err)
		}
	}()

	// 5. Wait for Shutdown Signal
	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, syscall.SIGINT, syscall.SIGTERM)
	<-sigs

	log.Println("🛑 Shutting down...")
	xrayMgr.Stop()
}
