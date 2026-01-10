package main

import (
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"aether/internal/horizon/db"
)

// XrayInbound represents the partial structure of an inbound config we care about
type XrayInbound struct {
	Tag            string `json:"tag"`
	Port           int    `json:"port"`
	Protocol       string `json:"protocol"`
	StreamSettings struct {
		Network     string `json:"network"`
		Security    string `json:"security"`
		TlsSettings struct {
			ServerName string `json:"serverName"`
		} `json:"tlsSettings"`
		RealitySettings struct {
			ServerName string   `json:"serverName"`
			PublicKey  string   `json:"publicKey"`
			ShortIds   []string `json:"shortIds"`
		} `json:"realitySettings"`
		WsSettings struct {
			Path    string            `json:"path"`
			Headers map[string]string `json:"headers"`
		} `json:"wsSettings"`
		TcpSettings struct {
			Header struct {
				Type string `json:"type"`
			} `json:"header"`
		} `json:"tcpSettings"`
		GrpcSettings struct {
			ServiceName string `json:"serviceName"`
		} `json:"grpcSettings"`
	} `json:"streamSettings"`
}

func handleSubscription(w http.ResponseWriter, r *http.Request) {
	uuid := r.URL.Query().Get("uuid")
	if uuid == "" {
		// Try path param if query is empty (simple manual check, real router would handle this)
		parts := strings.Split(r.URL.Path, "/")
		if len(parts) > 0 {
			uuid = parts[len(parts)-1]
		}
	}

	if uuid == "" {
		http.Error(w, "UUID Required", 400)
		return
	}

	// 1. Validate User & Fetch Access Info
	var u struct {
		Name   string
		Status string
		Expiry int64
	}
	err := db.DB.QueryRow("SELECT name, status, expiry FROM users WHERE uuid=?", uuid).Scan(&u.Name, &u.Status, &u.Expiry)
	if err == sql.ErrNoRows {
		http.Error(w, "User not found", 404)
		return
	}
	if u.Status != "active" {
		http.Error(w, "User is not active", 403)
		return
	}
	if u.Expiry > 0 && u.Expiry < time.Now().Unix() {
		http.Error(w, "User expired", 403)
		return
	}

	// 2. Get Allowed Inbound Tags via Groups
	rows, err := db.DB.Query(`
		SELECT DISTINCT gi.inbound_tag 
		FROM user_groups ug
		JOIN group_inbounds gi ON ug.group_id = gi.group_id
		WHERE ug.user_uuid = ?
	`, uuid)
	if err != nil {
		log.Println("Sub Error (Tags):", err)
		http.Error(w, "Internal Error", 500)
		return
	}
	defer rows.Close()

	allowedTags := make(map[string]bool)
	for rows.Next() {
		var tag string
		rows.Scan(&tag)
		allowedTags[tag] = true
	}
	rows.Close()

	// 3. Fetch Active Nodes
	nodeRows, err := db.DB.Query("SELECT id, name, ip FROM nodes WHERE status='active'")
	if err != nil {
		log.Println("Sub Error (Nodes):", err)
		http.Error(w, "Internal Error", 500)
		return
	}
	defer nodeRows.Close()

	var links []string

	// Pre-fetch configs to avoid N+1 query spam inside node loop
	// Map: NodeID -> []RawInbounds
	nodeConfigs := make(map[int][]string)

	ncRows, err := db.DB.Query(`
		SELECT nc.node_id, ct.raw_inbounds 
		FROM node_configs nc
		JOIN core_configs ct ON nc.config_id = ct.id
	`)
	if err != nil {
		log.Println("Sub Error (NodeConfigs):", err)
		http.Error(w, "Internal Error", 500)
		return
	}

	for ncRows.Next() {
		var nid int
		var raw string
		if err := ncRows.Scan(&nid, &raw); err == nil {
			nodeConfigs[nid] = append(nodeConfigs[nid], raw)
		}
	}
	ncRows.Close()

	for nodeRows.Next() {
		var nid int
		var nName, nIP string
		nodeRows.Scan(&nid, &nName, &nIP)

		configs, ok := nodeConfigs[nid]
		if !ok {
			continue
		}

		for _, rawJSON := range configs {
			var inbounds []XrayInbound
			if err := json.Unmarshal([]byte(rawJSON), &inbounds); err != nil {
				continue // Skip bad JSON
			}

			for _, in := range inbounds {
				if allowedTags[in.Tag] {
					link := generateLink(uuid, u.Name, nIP, nName, in)
					if link != "" {
						links = append(links, link)
					}
				}
			}
		}
	}

	// 4. Return Response
	responseBody := strings.Join(links, "\n")
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Header().Set("Subscription-Userinfo", fmt.Sprintf("upload=0; download=0; total=%d; expire=%d", 0, u.Expiry)) // TODO: Real stats

	// Base64 encode for v2ray subscription standard
	encoded := base64.StdEncoding.EncodeToString([]byte(responseBody))
	w.Write([]byte(encoded))
}

func generateLink(uuid, username, nodeIP, nodeName string, in XrayInbound) string {
	ps := fmt.Sprintf("%s-%s-%s", "Horizon", nodeName, in.Tag)

	switch in.Protocol {
	case "vless":
		// vless://uuid@ip:port?params#name
		params := []string{
			"type=" + in.StreamSettings.Network,
			"security=" + in.StreamSettings.Security,
		}

		if in.StreamSettings.Security == "reality" {
			params = append(params, "pbk="+in.StreamSettings.RealitySettings.PublicKey)
			params = append(params, "sni="+in.StreamSettings.RealitySettings.ServerName)
			params = append(params, "fp=chrome")
			// Side ID / ShortIds?
			if len(in.StreamSettings.RealitySettings.ShortIds) > 0 {
				params = append(params, "sid="+in.StreamSettings.RealitySettings.ShortIds[0])
			}
			params = append(params, "flow=xtls-rprx-vision") // Default assumes vision for reality usually
		} else if in.StreamSettings.Security == "tls" {
			params = append(params, "sni="+in.StreamSettings.TlsSettings.ServerName)
		}

		if in.StreamSettings.Network == "ws" {
			params = append(params, "path="+in.StreamSettings.WsSettings.Path)
			if host, ok := in.StreamSettings.WsSettings.Headers["Host"]; ok {
				params = append(params, "host="+host)
			}
		} else if in.StreamSettings.Network == "grpc" {
			params = append(params, "serviceName="+in.StreamSettings.GrpcSettings.ServiceName)
			params = append(params, "mode=gun")
		} else if in.StreamSettings.Network == "tcp" {
			if in.StreamSettings.TcpSettings.Header.Type == "http" {
				params = append(params, "headerType=http")
			}
		}

		return fmt.Sprintf("vless://%s@%s:%d?%s#%s", uuid, nodeIP, in.Port, strings.Join(params, "&"), ps)

	case "vmess":
		// VMess JSON -> Base64
		v := map[string]string{
			"v":    "2",
			"ps":   ps,
			"add":  nodeIP,
			"port": fmt.Sprintf("%d", in.Port),
			"id":   uuid,
			"aid":  "0",
			"scy":  "auto",
			"net":  in.StreamSettings.Network,
			"type": "none",
			"tls":  in.StreamSettings.Security,
		}

		if in.StreamSettings.Network == "ws" {
			v["path"] = in.StreamSettings.WsSettings.Path
			if host, ok := in.StreamSettings.WsSettings.Headers["Host"]; ok {
				v["host"] = host
			}
		} else if in.StreamSettings.Network == "grpc" {
			v["path"] = in.StreamSettings.GrpcSettings.ServiceName
			v["type"] = "gun" // specific map for vmess grpc?
		}

		if in.StreamSettings.Security == "tls" {
			v["sni"] = in.StreamSettings.TlsSettings.ServerName
		}

		jsonBytes, _ := json.Marshal(v)
		return "vmess://" + base64.StdEncoding.EncodeToString(jsonBytes)

	case "trojan":
		// trojan://password@ip:port?security=tls&sni=...#name
		params := []string{
			"type=" + in.StreamSettings.Network,
			"security=" + in.StreamSettings.Security,
		}
		if in.StreamSettings.Security == "tls" {
			params = append(params, "sni="+in.StreamSettings.TlsSettings.ServerName)
		}
		return fmt.Sprintf("trojan://%s@%s:%d?%s#%s", uuid, nodeIP, in.Port, strings.Join(params, "&"), ps)
	}

	return ""
}
