package honeypot

import (
	"embed"
	"io"
	"log"
	"net"
	"net/http"
	"time"
)

//go:embed www/*
var content embed.FS

// StartServer starts the internal honeypot server on localhost
func StartServer(port string) {
	// Serve files from the embedded 'www' folder
	// We need to strip the prefix so it serves from root

	// We need to handle the "www" subfolder in embed
	// http.FS(content) has "www" at root.
	// We want requests to / to map to www/index.html

	mux := http.NewServeMux()
	// mux.Handle("/", http.StripPrefix("/", http.FileServer(http.FS(content))))

	// Actually, careful with StripPrefix and FS.
	// Best way: use http.FS but sub-tree.
	// But embed doesn't support sub-tree easily without fs.Sub
	// Let's do a simpler handler.

	mux.Handle("/static/", http.FileServer(http.FS(content)))
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		// Default Landing Page
		data, _ := content.ReadFile("www/index.html")
		w.Header().Set("Content-Type", "text/html")
		w.Header().Set("Server", "Apache/2.4.41 (Ubuntu)") // Fake Header
		w.WriteHeader(http.StatusOK)
		w.Write(data)
	})

	log.Printf("🍯 Honeypot Server running on localhost:%s", port)
	go http.ListenAndServe("127.0.0.1:"+port, mux)
}

// ProxyToHoneypot tunnels the external connection to the internal honeypot
func ProxyToHoneypot(conn net.Conn, targetPort string) {
	defer conn.Close()

	targetAddr := "127.0.0.1:" + targetPort
	dest, err := net.DialTimeout("tcp", targetAddr, 5*time.Second)
	if err != nil {
		log.Println("🍯 Honeypot Dial Error:", err)
		return
	}
	defer dest.Close()

	// Bidirectional Copy
	go io.Copy(dest, conn)
	io.Copy(conn, dest)
}
