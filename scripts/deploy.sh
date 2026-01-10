#!/bin/bash
set -e

# Configuration
VPS_IP="46.224.207.62"
USER="root"
SSH_TARGET="$USER@$VPS_IP"
REMOTE_DIR="/opt/horizon"

echo "🚀 Deploying Aether Node (Docker) to $VPS_IP..."

# 1. Clean previous build context
echo "📦 Packaging Source..."
COPYFILE_DISABLE=1 tar --exclude='node_modules' --exclude='.git' --exclude='dist' --exclude='.next' --exclude='horizon_deploy.tar.gz' -czf horizon_deploy.tar.gz .

# 2. Upload
echo "📤 Uploading Source..."
ssh $SSH_TARGET "mkdir -p $REMOTE_DIR"
scp horizon_deploy.tar.gz $SSH_TARGET:$REMOTE_DIR/

# 3. Build & Run Remotely
echo "🐳 Building & Running on Server..."
ssh $SSH_TARGET "cd $REMOTE_DIR && \
    tar -xzf horizon_deploy.tar.gz && \
    echo 'Building Agent...' && \
    docker build -t horizon-agent -f cmd/server/Dockerfile . && \
    echo 'Stopping old container...' && \
    docker rm -f horizon-agent || true && \
    echo 'Starting new container...' && \
    docker run -d --name horizon-agent --network host --restart always \
      -e ADMIN_PORT=8081 \
      -e MASTER_KEY=161DD7C1-967D-46FD-89BD-C43B77361EC5 \
      horizon-agent"

# Cleanup
rm horizon_deploy.tar.gz
echo "✅ Docker Deployment Complete!"
