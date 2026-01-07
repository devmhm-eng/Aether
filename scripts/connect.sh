#!/bin/bash
# Connect Aether Client to Remote Server

echo "🍏 Starting Aether Client (Direct Run)..."
# rm -f bin/client_mac
# go build -o bin/client_mac cmd/client/main.go
# ./bin/client_mac

echo "Proxy listening on: 127.0.0.1:1080 (SOCKS5)"
echo "Logs will appear below. Press Ctrl+C to stop."
echo "---------------------------------------------"

go run cmd/client/main.go
