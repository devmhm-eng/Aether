#!/bin/bash
# Aether Server Installation Script (Linux)
# Supported: Ubuntu 20.04/22.04, Debian 11/12

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}>>> Aether Server Installer <<<${NC}"

# 1. System Update & Dependencies
echo -e "${GREEN}[1/5] Installing Dependencies...${NC}"
apt-get update -y
apt-get install -y build-essential clang llvm libbpf-dev git chrony curl make

# 2. Install Go (if missing)
if ! command -v go &> /dev/null; then
    echo "Installing Go..."
    
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        GO_ARCH="amd64"
    elif [ "$ARCH" = "aarch64" ]; then
        GO_ARCH="arm64"
    else
        echo "Unsupported Arch: $ARCH"
        exit 1
    fi
    
    GO_PKG="go1.22.0.linux-${GO_ARCH}.tar.gz"
    
    wget "https://go.dev/dl/${GO_PKG}"
    rm -rf /usr/local/go && tar -C /usr/local -xzf "$GO_PKG"
    export PATH=$PATH:/usr/local/go/bin
    echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
    rm "$GO_PKG"
fi

# 3. Setup Time Sync (Critical for TOTP)
echo -e "${GREEN}[2/5] Syncing Time...${NC}"
systemctl enable --now chrony
chronyc makestep 1 3 || true

# 4. Build Server & eBPF
echo -e "${GREEN}[3/5] Building Aether Core...${NC}"
/usr/local/go/bin/go mod tidy
# Build native binary (supports both AMD64 and ARM64 automatically)
go build -o aether-server cmd/server/main.go
# make server-linux (Skipped to avoid arch mismatch)
make bpf

# 5. Route Setup (Nebula IPv6)
echo -e "${GREEN}[4/5] Configuring Network (Nebula)...${NC}"
# Enable IPv6 Forwarding if needed (optional)
# sysctl -w net.ipv6.conf.all.forwarding=1
# Add Local Route for AnyIP
ip route add local 2001:db8:1234::/64 dev lo || echo "Route already exists or failed."

# 6. Install Service
echo -e "${GREEN}[5/5] Installing Service...${NC}"
chmod +x scripts/manage.sh
./scripts/manage.sh install

echo -e "${BLUE}>>> Installation Complete! <<<${NC}"
echo "Run './scripts/manage.sh logs' to monitor."
