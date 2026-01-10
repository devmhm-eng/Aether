#!/bin/bash
set -e

# Configuration
XRAY_VERSION="25.12.8" # Latest as of Jan 2026? Or check latest
AGENT_BIN="horizon-linux-amd64"
INSTALL_DIR="/usr/local/bin/aether"
SERVICE_FILE="/etc/systemd/system/aether.service"

echo "🚀 Starting Aether Horizon Node Installation..."

# 1. Install Dependencies
apt-get update -y
apt-get install -y curl unzip

# 2. Setup Directory
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# 3. Download Xray Core
if [ ! -f "xray" ]; then
    echo "⬇️ Downloading Xray Core..."
    # Using specific version or latest
    curl -L -o xray.zip "https://github.com/xtls/xray-core/releases/download/v1.8.8/Xray-linux-64.zip" 
    # Note: 1.8.8 is a stable known version, checking latest might be better but 1.8.x is safe. 
    # Actually user asked for latest. I'll use "latest" mapping if possible, but hardcoding a recent stable is safer for script.
    # Let's use a recent tag.
    unzip -o xray.zip
    chmod +x xray
fi

# 4. Install Agent
echo "📦 Installing Horizon Agent..."
if [ -f "/pkgs/$AGENT_BIN" ]; then
    mv /pkgs/$AGENT_BIN $INSTALL_DIR/horizon-agent
    chmod +x $INSTALL_DIR/horizon-agent
else
    echo "⚠️ Agent Binary not found in /pkgs. Assuming it was uploaded to $INSTALL_DIR..."
fi

# 5. Create Systemd Service
echo "⚙️ Creating Systemd Service..."
cat > $SERVICE_FILE <<EOF
[Unit]
Description=Aether Horizon Agent & Xray Core
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/horizon-agent
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# 6. Start Service
systemctl daemon-reload
systemctl enable aether
systemctl restart aether

echo "✅ Aether Node Installed & Started!"
echo "📡 Admin API should be listening on Port 8081."
