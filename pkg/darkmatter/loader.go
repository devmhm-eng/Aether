package darkmatter

import (
	"log"
	// mock import for macOS
	// "github.com/cilium/ebpf"
	// "github.com/cilium/ebpf/link"
)

// Loader handles eBPF program loading
// NOTE: This file is a skeleton. Real implementation requires Linux and 'cilium/ebpf'.
type Loader struct {
	// Objs *bpfObjects
	// Link link.Link
}

func NewLoader() *Loader {
	return &Loader{}
}

func (l *Loader) Attach(interfaceName string) error {
	log.Println("🛡️ Dark Matter: XDP Attach requested for", interfaceName)
	log.Println("⚠️ Skipped: eBPF requires Linux Kernel.")
	return nil
}

func (l *Loader) Close() {
	// Close Link
}
