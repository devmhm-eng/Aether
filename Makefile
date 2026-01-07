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

bpf:
	clang -O2 -target bpf -c bpf/filter.c -o bpf/filter.o
	@echo "🛡️ eBPF Object compiled."

clean:
	rm -rf bin/
	@echo "🧹 Cleaned."
