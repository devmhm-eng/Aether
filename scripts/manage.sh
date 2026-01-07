#!/bin/bash

# Aether Server Management Script
# Usage: ./manage.sh [install|start|stop|restart|logs|uninstall]

BINARY_NAME="aether-server"
BINARY_SOURCE="./aether-server" # Assumes binary is in current dir
INSTALL_PATH="/usr/local/bin/$BINARY_NAME"
CONFIG_DIR="/etc/aether"
CONFIG_FILE="$CONFIG_DIR/config.json"
SERVICE_FILE="/etc/systemd/system/aether.service"
PORT=4242

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}Please run as root (sudo ./manage.sh ...)${NC}"
  exit 1
fi

generate_password() {
  openssl rand -hex 16
}

install() {
  echo -e "${GREEN}Installing Aether Server...${NC}"

  # 1. Find Binary
  if [ -f "./aether-server" ]; then
    BINARY_SOURCE="./aether-server"
  elif [ -f "../aether-server" ]; then
    BINARY_SOURCE="../aether-server"
  elif [ -f "../bin/server-linux-amd64" ]; then
    BINARY_SOURCE="../bin/server-linux-amd64"
  else
    echo -e "${RED}Error: Binary file not found.${NC}"
    echo "Searched locations:"
    echo "  - ./aether-server"
    echo "  - ../aether-server"
    echo "  - ../bin/server-linux-amd64"
    echo "Please upload the binary or move it next to this script."
    exit 1
  fi

  echo "Found binary at: $BINARY_SOURCE"

  # 2. Install Binary
  cp "$BINARY_SOURCE" "$INSTALL_PATH"
  chmod +x "$INSTALL_PATH"
  echo "Binary installed to $INSTALL_PATH"

  # 3. Create Config
  mkdir -p "$CONFIG_DIR"
  if [ ! -f "$CONFIG_FILE" ]; then
    PASSWORD=$(generate_password)
    cat <<EOF > "$CONFIG_FILE"
{
    "server_addr": "0.0.0.0:$PORT",
    "local_port": 1080,
    "password": "$PASSWORD"
}
EOF
    echo "Config generated at $CONFIG_FILE"
  else
    echo "Config already exists, skipping generation."
    PASSWORD=$(grep -oP '"password": "\K[^"]+' "$CONFIG_FILE")
  fi

  # 4. Create Systemd Service
  cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=Aether VPN Server
After=network.target

[Service]
ExecStart=$INSTALL_PATH
WorkingDirectory=$CONFIG_DIR
Restart=always
User=root
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
  echo "Systemd service created."

  # 5. Enable and Start
  systemctl daemon-reload
  systemctl enable aether
  systemctl start aether
  
  # 6. Firewall (UFW)
  if command -v ufw > /dev/null; then
    ufw allow $PORT/tcp
    ufw allow $PORT/udp
    echo "Firewall rules updated."
  fi

  # 7. Output Client Config
  PUBLIC_IP=$(curl -s ifconfig.me)
  echo ""
  echo -e "${GREEN}✅ Installation Complete!${NC}"
  echo -e "${YELLOW}=== CLIENT CONFIG (Copy to your Mac/PC) ===${NC}"
  echo "{"
  echo "    \"server_addr\": \"$PUBLIC_IP:$PORT\","
  echo "    \"local_port\": 1080,"
  echo "    \"password\": \"$PASSWORD\""
  echo "}"
  echo -e "${YELLOW}===========================================${NC}"
}

uninstall() {
  echo -e "${YELLOW}Uninstalling Aether...${NC}"
  systemctl stop aether
  systemctl disable aether
  rm -f "$SERVICE_FILE"
  rm -f "$INSTALL_PATH"
  rm -rf "$CONFIG_DIR"
  systemctl daemon-reload
  echo -e "${GREEN}Uninstalled.${NC}"
}

# Helper: Generate UUID (if uuidgen missing)
generate_uuid() {
  if command -v uuidgen >/dev/null; then
    uuidgen | tr '[:upper:]' '[:lower:]'
  else
    cat /proc/sys/kernel/random/uuid
  fi
}

add_user() {
  LIMIT_GB=${2:-0} # Default 0 (Unlimited)

  if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: Config file not found at $CONFIG_FILE${NC}"
    exit 1
  fi

  NEW_UUID=$(generate_uuid)
  
  # Use jq to append to users array
  if command -v jq >/dev/null; then
    # Create temp file
    tmp=$(mktemp)
    jq --arg uuid "$NEW_UUID" --argjson limit "$LIMIT_GB" \
       '.users += [{"uuid": $uuid, "limit_gb": $limit, "usage_bytes": 0}]' \
       "$CONFIG_FILE" > "$tmp" && mv "$tmp" "$CONFIG_FILE"
    
    echo -e "${GREEN}✅ User Added!${NC}"
    echo "UUID: $NEW_UUID"
    echo "Limit: ${LIMIT_GB} GB"
    
    # Reload server to pick up changes
    systemctl restart aether
    echo "Server restarted."
  else
    echo -e "${RED}Error: 'jq' is required to manage JSON configs.${NC}"
    echo "Run: apt-get install jq"
  fi
}

case "$1" in
  install)
    install
    ;;
  start)
    systemctl start aether
    echo "Service started."
    ;;
  stop)
    systemctl stop aether
    echo "Service stopped."
    ;;
  restart)
    systemctl restart aether
    echo "Service restarted."
    ;;
  logs)
    journalctl -u aether -f
    ;;
# Edit User Limit
edit_user() {
  UUID=$2
  LIMIT_GB=${3:-0}

  if [ -z "$UUID" ]; then
    echo -e "${RED}Usage: ./manage.sh edit-user <uuid> <new_limit_gb>${NC}"
    exit 1
  fi

  if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: Config file not found.${NC}"
    exit 1
  fi

  if command -v jq >/dev/null; then
    tmp=$(mktemp)
    # Update limit for specific UUID
    jq --arg uuid "$UUID" --argjson limit "$LIMIT_GB" \
       '(.users[] | select(.uuid == $uuid).limit_gb) = $limit' \
       "$CONFIG_FILE" > "$tmp" && mv "$tmp" "$CONFIG_FILE"
    
    echo -e "${GREEN}✅ User Updated!${NC}"
    echo "UUID: $UUID"
    echo "New Limit: ${LIMIT_GB} GB"
    
    systemctl restart aether
    echo "Server restarted."
  else
    echo -e "${RED}Error: 'jq' required.${NC}"
  fi
}

# Show Users and Usage
show_users() {
  if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: Config file not found.${NC}"
    exit 1
  fi

  echo -e "${YELLOW}=== Aether Users ===${NC}"
  # Print Header
  printf "%-40s %-15s %-15s %-10s\n" "UUID" "LIMIT (GB)" "USED (GB)" "STATUS"
  echo "--------------------------------------------------------------------------------"
  
  # Parse JSON and format output
  # Usage is in Bytes, divide by 1073741824 for GB
  jq -r '.users[] | "\(.uuid) \(.limit_gb) \(.usage_bytes)"' "$CONFIG_FILE" | while read -r uuid limit usage; do
    
    # Calculate Usage in GB (Bash doesn't do float math easily, using awk)
    USED_GB=$(awk "BEGIN {printf \"%.2f\", $usage/1073741824}")
    
    # Status
    STATUS="${GREEN}Active${NC}"
    if (( $(echo "$limit > 0" | bc -l) )); then
      # Check if usage > limit
      IS_OVER=$(awk "BEGIN {if ($USED_GB > $limit) print 1; else print 0}")
      if [ "$IS_OVER" -eq 1 ]; then
        STATUS="${RED}OVER${NC}"
      fi
    else
      limit="∞"
    fi

    printf "%-40s %-15s %-15s %-10b\n" "$uuid" "$limit" "$USED_GB" "$STATUS"
  done
  echo "--------------------------------------------------------------------------------"
}

case "$1" in
  install)
    install
    ;;
  start)
    systemctl start aether
    echo "Service started."
    ;;
  stop)
    systemctl stop aether
    echo "Service stopped."
    ;;
  restart)
    systemctl restart aether
    echo "Service restarted."
    ;;
  logs)
    journalctl -u aether -f
    ;;
  add-user)
    add_user "$@"
    ;;
  edit-user)
    edit_user "$@"
    ;;
  show-users)
    show_users
    ;;
  uninstall)
    uninstall
    ;;
  *)
    echo "Usage: $0 {install|start|stop|restart|logs|add-user <limit>|edit-user <uuid> <limit>|show-users|uninstall}"
    exit 1
esac
