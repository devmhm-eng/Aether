#!/bin/bash
echo "🚀 Starting Aether Client..."
echo "🌍 Connecting to VPS..."

# Build if missing
if [ ! -f "bin/client-mac" ]; then
    echo "🔨 Building Client..."
    go build -o bin/client-mac cmd/client/main.go
fi

# Run
./bin/client-mac
