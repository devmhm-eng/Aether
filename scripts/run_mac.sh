#!/bin/bash
# Run Aether Locally on Mac (Dev Mode)

echo "🍏 Building Aether for macOS..."
go build -o bin/server-mac cmd/server/main.go
go build -o bin/client-mac cmd/client/main.go

echo "🚀 Starting Server (Port 4242)..."
./bin/server-mac > server.log 2>&1 &
SERVER_PID=$!

echo "🚀 Starting Client (Port 1080)..."
./bin/client-mac > client.log 2>&1 &
CLIENT_PID=$!

echo "✅ Running! (Server PID: $SERVER_PID, Client PID: $CLIENT_PID)"
echo "Logs are streaming to server.log and client.log"
echo "Press Ctrl+C to stop."

trap "kill $SERVER_PID $CLIENT_PID; exit" SIGINT

tail -f server.log client.log
