package api

import (
	"encoding/json"
	"log"
	"net/http"

	"aether/pkg/config"
)

// UserStore interface defines what the API needs to do with the KeyStore
type UserStore interface {
	GetStats() []config.User
	UpdateUser(uuid string, limitGB float64) error
	AddUser(u config.User)
	DeleteUser(uuid string)
}

func StartAdminServer(port string, token string, store UserStore) {
	if port == "" {
		port = "8081"
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/admin/stats", authMiddleware(token, handleStats(store)))
	mux.HandleFunc("/admin/user", authMiddleware(token, handleUser(store)))

	log.Printf("🛠️ Admin API Listening on 0.0.0.0:%s", port)
	if err := http.ListenAndServe("0.0.0.0:"+port, mux); err != nil {
		log.Printf("❌ Admin API Failed: %v", err)
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
