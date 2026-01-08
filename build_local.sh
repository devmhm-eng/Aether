#!/bin/bash
set -e

echo "🚀 Starting Local AAR Build Strategy..."

# 1. Setup paths
export WORK_DIR="../Aether_Local_Build"
export ORIGINAL_DIR=$(pwd)
export NDK_VERSION="25.1.8937393"
export ANDROID_HOME=$HOME/Library/Android/sdk
export ANDROID_NDK_HOME=$ANDROID_HOME/ndk/$NDK_VERSION

# Check NDK
if [ ! -d "$ANDROID_NDK_HOME" ]; then
    echo "❌ NDK $NDK_VERSION not found at $ANDROID_NDK_HOME"
    echo "Checking what is available..."
    ls $ANDROID_HOME/ndk/
    exit 1
fi

# 2. Prepare clean workspace
echo "🧹 Preparing clean workspace at $WORK_DIR..."
rm -rf $WORK_DIR
mkdir -p $WORK_DIR
cp -R . $WORK_DIR/

# 3. Strip incompatible dependencies
echo "✂️  Stripping incompatible server dependencies..."
cd $WORK_DIR
rm -rf cmd/server pkg/transport pkg/flux

# 4. Clean go.mod
echo "🧼 Cleaning module dependencies..."
# Drop WebRTC requirements
go mod edit -droprequire=github.com/pion/webrtc/v3
go mod tidy
go get golang.org/x/mobile/bind

# 5. Build with compatible API level
echo "🔨 Building AAR (forcing API 21 for NDK 25 compatibility)..."
export PATH=$PATH:$(go env GOPATH)/bin

mkdir -p sdk/flutter/aether_client/android/libs

# Using -androidapi 21 is key for NDK 25+ compatibility
gomobile bind -v \
    -o sdk/flutter/aether_client/android/libs/aether.aar \
    -target=android \
    -androidapi 21 \
    ./pkg/mobile

echo "✅ Build Success!"
echo "📦 AAR Location: $WORK_DIR/sdk/flutter/aether_client/android/libs/aether.aar"

# 6. Copy back
echo "🚚 Copying AAR to original project..."
cp sdk/flutter/aether_client/android/libs/aether.aar $ORIGINAL_DIR/sdk/flutter/aether_client/android/libs/

echo "🎉 Done! You can now run the app."
