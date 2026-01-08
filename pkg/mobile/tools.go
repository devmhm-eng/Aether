//go:build tools
// +build tools

// This file ensures gomobile can build without WebRTC dependencies
package mobile

import (
	_ "github.com/xtaci/smux"
	_ "golang.org/x/crypto/chacha20poly1305"
	_ "golang.org/x/mobile/bind"
)
