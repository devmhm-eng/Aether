package db

import (
	"database/sql"
	"log"

	_ "github.com/mattn/go-sqlite3"
)

var DB *sql.DB

func Init(path string) {
	var err error
	DB, err = sql.Open("sqlite3", path)
	if err != nil {
		log.Fatal("❌ Failed to open database:", err)
	}

	// Enable WAL Mode for better concurrency
	if _, err := DB.Exec("PRAGMA journal_mode=WAL"); err != nil {
		log.Printf("⚠️ Failed to enable WAL mode: %v", err)
	}

	// Enable Foreign Keys
	if _, err := DB.Exec("PRAGMA foreign_keys = ON"); err != nil {
		log.Printf("⚠️ Failed to enable foreign keys: %v", err)
	}

	createTables()
}

func createTables() {
	query := `
	CREATE TABLE IF NOT EXISTS nodes (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		name TEXT,
		ip TEXT,
		admin_port TEXT,
		master_key TEXT,
		status TEXT DEFAULT 'offline',
		last_check INTEGER DEFAULT 0
	);

	CREATE TABLE IF NOT EXISTS users (
		uuid TEXT PRIMARY KEY,
		name TEXT,
		limit_gb REAL,
		device_limit INTEGER DEFAULT 3,
		used_bytes INTEGER DEFAULT 0,
		expiry INTEGER DEFAULT 0,
		status TEXT DEFAULT 'active'
	);

	CREATE TABLE IF NOT EXISTS devices (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		hardware_id TEXT UNIQUE NOT NULL,
		label TEXT,
		status TEXT DEFAULT 'active',
		last_seen DATETIME DEFAULT CURRENT_TIMESTAMP
	);

	CREATE TABLE IF NOT EXISTS user_devices (
		user_uuid TEXT NOT NULL,
		device_id INTEGER NOT NULL,
		FOREIGN KEY (user_uuid) REFERENCES users(uuid) ON DELETE CASCADE,
		FOREIGN KEY (device_id) REFERENCES devices(id) ON DELETE CASCADE,
		UNIQUE(user_uuid, device_id)
	);

	CREATE TABLE IF NOT EXISTS core_configs (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		name TEXT NOT NULL,
		node_id INTEGER,
		protocol TEXT,
		port TEXT,
		settings TEXT,
		status TEXT DEFAULT 'active',
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
		FOREIGN KEY (node_id) REFERENCES nodes(id)
	);

	CREATE TABLE IF NOT EXISTS groups (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		name TEXT NOT NULL UNIQUE,
		description TEXT,
		max_traffic_gb REAL DEFAULT 0,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP
	);

	CREATE TABLE IF NOT EXISTS group_configs (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		group_id INTEGER NOT NULL,
		config_id INTEGER NOT NULL,
		FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
		FOREIGN KEY (config_id) REFERENCES core_configs(id) ON DELETE CASCADE,
		UNIQUE(group_id, config_id)
	);

	CREATE TABLE IF NOT EXISTS user_groups (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_uuid TEXT NOT NULL,
		group_id INTEGER NOT NULL,
		FOREIGN KEY (user_uuid) REFERENCES users(uuid) ON DELETE CASCADE,
		FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE,
		UNIQUE(user_uuid, group_id)
	);

	CREATE TABLE IF NOT EXISTS group_inbounds (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		group_id INTEGER NOT NULL,
		inbound_tag TEXT NOT NULL,
		FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE
	);

	CREATE TABLE IF NOT EXISTS user_config_usage (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		user_uuid TEXT NOT NULL,
		config_id INTEGER NOT NULL,
		used_bytes BIGINT DEFAULT 0,
		last_sync DATETIME,
		FOREIGN KEY (user_uuid) REFERENCES users(uuid) ON DELETE CASCADE,
		FOREIGN KEY (config_id) REFERENCES core_configs(id) ON DELETE CASCADE,
		UNIQUE(user_uuid, config_id)
	);
	`
	_, err := DB.Exec(query)
	if err != nil {
		log.Fatal("DB Init Error:", err)
	}
}
