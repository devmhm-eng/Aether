#!/bin/bash
# Aether Server Debugger

echo "🔍 Checking Port 4242..."
netstat -tulpn | grep 4242

echo ""
echo "🔥 Checking UFW Status..."
ufw status verbose

echo ""
echo "🧱 Checking IPTables (Input Chain)..."
iptables -L INPUT -n --line-numbers | head -n 20

echo ""
echo "🌍 Checking Public IP Reachability..."
curl -4 ifconfig.me
