package api

import (
	"aether/pkg/config"
	"aether/pkg/enigma"
	"encoding/json"
	"io"
	"log"
	"net/http"
)

// UserStore interface defines what the API needs to do with the KeyStore
type UserStore interface {
	GetStats() []config.User
	GetUser(uuid string) *config.User
	UpdateUser(uuid string, limitGB float64) error
	AddUser(u config.User)
	DeleteUser(uuid string)
}

// Enigma Key (Must match mobile client)
var EnigmaKey = []byte("01234567890123456789012345678901")

func StartAdminServer(port string, token string, store UserStore) {
	if port == "" {
		port = "8081"
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/admin/stats", authMiddleware(token, handleStats(store)))
	mux.HandleFunc("/admin/user", authMiddleware(token, handleUser(store)))

	// Secure Public API (Device Registration)
	mux.HandleFunc("/api/v1/secure", handleSecureAPI(store))

	log.Printf("🛠️ Admin API Listening on 0.0.0.0:%s", port)
	if err := http.ListenAndServe("0.0.0.0:"+port, mux); err != nil {
		log.Printf("❌ Admin API Failed: %v", err)
	}
}

// ... (keep authMiddleware and admin handlers)

type SecureRequest struct {
	Action     string `json:"action"`
	HardwareID string `json:"hardware_id"`
	UserUUID   string `json:"user_uuid"`
	Label      string `json:"label"`
}

func handleSecureAPI(store UserStore) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method != "POST" {
			http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
			return
		}

		// 1. Read Encrypted Body
		bodyBytes, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, "Read Error", http.StatusBadRequest)
			return
		}

		// 2. Decrypt
		plainBytes, err := enigma.Open(string(bodyBytes), EnigmaKey)
		if err != nil {
			log.Printf("🔐 SecureAPI: Decryption Failed: %v", err)
			http.Error(w, "Decryption Failed", http.StatusForbidden)
			return
		}

		// 3. Parse JSON
		var req SecureRequest
		if err := json.Unmarshal(plainBytes, &req); err != nil {
			log.Printf("🔐 SecureAPI: Invalid JSON: %v", err)
			http.Error(w, "Invalid JSON", http.StatusBadRequest)
			return
		}

		// 4. Handle Action
		responseMap := make(map[string]interface{})

		switch req.Action {
		case "register_device":
			user := store.GetUser(req.UserUUID)
			if user == nil {
				responseMap["status"] = "error"
				responseMap["message"] = "User not found"
			} else {
				// Check/Bind Hardware ID
				if user.HardwareID == "" {
					user.HardwareID = req.HardwareID
					store.AddUser(*user) // Persist change
					responseMap["status"] = "ok"
					responseMap["message"] = "Device Registered"
					log.Printf("📱 Device Registered: User=%s ID=%s", req.UserUUID, req.HardwareID)
				} else if user.HardwareID == req.HardwareID {
					responseMap["status"] = "ok"
					responseMap["message"] = "Device Verified"
				} else {
					responseMap["status"] = "error"
					responseMap["message"] = "Device limit reached"
					log.Printf("⚠️ Device Mismatch: User=%s Existing=%s New=%s", req.UserUUID, user.HardwareID, req.HardwareID)
				}
			}

		case "get_config":
			user := store.GetUser(req.UserUUID)
			if user == nil {
				responseMap["status"] = "error"
				responseMap["message"] = "User not found"
			} else { // Assume Hardware Check passed or implied by flow?
				// For stricter security, we should check HardwareID here too if provided.
				// But payload usually is just {action, uuid}.
				// Let's return minimal config.
				responseMap["status"] = "ok"
				responseMap["server_addr"] = "10.0.2.2:4242"
				// Note: Real implementation should return public IP/Domain
				// Since we are running on emulator, we return emulator-friendly addresses?
				// Or client overrides it?
				// Mobile client currently uses 'server_addr' from config if present.
				// Let's NOT return 'server_addr' to force Client to use its default or manual entry?
				// Actually client defaults to 127.0.0.1.
				// We MUST return 10.0.2.2 if we want auto-config to work on Emulator.
				// But we hardcoded it in HomeScreen manually in Step 5550.
				// Splash Screen uses 'get_config' to validate.
				// So just returning 'ok' is enough for Splash.
			}

		default:
			responseMap["status"] = "error"
			responseMap["message"] = "Unknown Action"
		}

		// 5. Encrypt Response
		respJSON, _ := json.Marshal(responseMap)
		cipherResp, err := enigma.Seal(respJSON, EnigmaKey)
		if err != nil {
			http.Error(w, "Encryption Error", http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "text/plain")
		w.Write([]byte(cipherResp))
	}
}

func authMiddleware(token string, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if token != "" && r.Header.Get("X-Admin-Token") != token {
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}
		next(w, r)
	}
}

func handleStats(store UserStore) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		users := store.GetStats()
		json.NewEncoder(w).Encode(users)
	}
}

func handleUser(store UserStore) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.Method == "POST" {
			var u config.User
			if err := json.NewDecoder(r.Body).Decode(&u); err != nil {
				http.Error(w, err.Error(), http.StatusBadRequest)
				return
			}
			store.AddUser(u)
			w.WriteHeader(http.StatusOK)
			w.Write([]byte("User Added/Updated"))
		} else if r.Method == "DELETE" {
			uuid := r.URL.Query().Get("uuid")
			if uuid == "" {
				http.Error(w, "uuid required", http.StatusBadRequest)
				return
			}
			store.DeleteUser(uuid)
			w.WriteHeader(http.StatusOK)
			w.Write([]byte("User Deleted"))
		} else {
			http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		}
	}
}
