package mobile

import (
	"fmt"
	"log"
	"runtime/debug"
	"strings"
	"sync"

	"github.com/xjasonlyu/tun2socks/v2/engine"

	// Xray Imports
	"github.com/xtls/xray-core/core"
	"github.com/xtls/xray-core/infra/conf/serial"
	_ "github.com/xtls/xray-core/main/distro/all"
)

// AetherCore manages the VPN Lifecycle (Xray + Tun2Socks)
type AetherCore struct {
	mu           sync.Mutex
	xrayInstance *core.Instance
	tunKey       *engine.Key
	stopCh       chan struct{}
}

// Global instance to simplify gomobile binding (Stateful)
var instance *AetherCore

func init() {
	instance = &AetherCore{}
	// Force FreeOSMemory to lower initial footprint
	debug.FreeOSMemory()
}

// StartVPN initializes Xray and Tun2Socks
// fd: The file descriptor of the Android TUN interface
// configJSON: The full Xray configuration JSON
// assetDir: Directory to write logs/assets if needed
func StartVPN(fd int, configJSON string, assetDir string) error {
	instance.mu.Lock()
	defer instance.mu.Unlock()

	if instance.xrayInstance != nil {
		return fmt.Errorf("instance already running")
	}

	log.Println("🚀 AetherCore: Starting...")

	// 1. Parse & Start Xray Instance
	// LoadJSONConfig returns *core.Config directly in newer Xray versions
	coreConfig, err := serial.LoadJSONConfig(strings.NewReader(configJSON))
	if err != nil {
		return fmt.Errorf("failed to parse xray config: %v", err)
	}

	inst, err := core.New(coreConfig)
	if err != nil {
		return fmt.Errorf("failed to create xray instance: %v", err)
	}

	if err := inst.Start(); err != nil {
		return fmt.Errorf("failed to start xray: %v", err)
	}

	instance.xrayInstance = inst
	log.Println("✅ Xray Core Started")

	// 2. Start Tun2Socks
	key := new(engine.Key)
	key.Mark = 0
	key.MTU = 1500
	key.Device = fmt.Sprintf("fd://%d", fd)
	key.Proxy = "socks5://127.0.0.1:10808"
	key.RestAPI = ""
	key.LogLevel = "error"
	key.UDPTimeout = 0

	// Start Tun2Socks
	engine.Insert(key)
	engine.Start() // Void return
	instance.tunKey = key

	log.Println("✅ Tun2Socks Started")
	return nil
}

// StopVPN stops all services
func StopVPN() {
	instance.mu.Lock()
	defer instance.mu.Unlock()

	if instance.tunKey != nil {
		engine.Stop()
		instance.tunKey = nil
		log.Println("🛑 Tun2Socks Stopped")
	}

	if instance.xrayInstance != nil {
		instance.xrayInstance.Close()
		instance.xrayInstance = nil
		log.Println("🛑 Xray Core Stopped")
	}
}

// WriteConfig is a helper to verify JSON config parsing
func ValidateConfig(jsonConf string) error {
	_, err := serial.LoadJSONConfig(strings.NewReader(jsonConf))
	return err
}
