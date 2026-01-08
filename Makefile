BINARY_NAME=aether

all: server-linux client-mac client-win

server-linux:
	GOOS=linux GOARCH=amd64 go build -o bin/server-linux-amd64 cmd/server/main.go
	@echo "✅ Server (Linux) built."

client-mac:
	GOOS=darwin GOARCH=arm64 go build -o bin/client-mac-arm64 cmd/client/main.go
	@echo "✅ Client (macOS) built."

client-win:
	GOOS=windows GOARCH=amd64 go build -o bin/client-win-amd64.exe cmd/client/main.go
	@echo "✅ Client (Windows) built."

client-android:
	mkdir -p sdk/flutter/aether_client/android/libs
	gomobile bind -o sdk/flutter/aether_client/android/libs/aether.aar -target=android ./pkg/mobile
	@echo "✅ Client (Android Library) built."

bpf:
	clang -O2 -target bpf -c bpf/filter.c -o bpf/filter.o
	@echo "🛡️ eBPF Object compiled."
client-ios:
	gomobile bind -target=ios -o sdk/flutter/aether_client/ios/Aether.xcframework ./pkg/mobile
	@echo "✅ Client (iOS Framework) built."

client-desktop-mac:
	mkdir -p sdk/flutter/aether_client/macos/libs
	GOOS=darwin GOARCH=arm64 go build -buildmode=c-shared -o sdk/flutter/aether_client/macos/libs/libaether.dylib pkg/desktop/exports.go
	@echo "✅ Client (macOS Dylib) built."

client-desktop-win:
	mkdir -p sdk/flutter/aether_client/windows/libs
	GOOS=windows GOARCH=amd64 go build -buildmode=c-shared -o sdk/flutter/aether_client/windows/libs/aether.dll pkg/desktop/exports.go
	@echo "✅ Client (Windows DLL) built."

clean:
	rm -rf bin/
	@echo "🧹 Cleaned."
