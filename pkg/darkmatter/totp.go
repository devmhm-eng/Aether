package darkmatter

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/binary"
	"time"
)

// Config
const (
	RotationInterval = 60 // Seconds
	PortRangeStart   = 2000
	PortRangeEnd     = 65000
)

// GetActivePort calculates the port for a given time
func GetActivePort(secret string, t time.Time) int {
	// TOTP Time Step
	counter := t.Unix() / RotationInterval

	// HMAC-SHA256
	key := []byte(secret)
	buf := make([]byte, 8)
	binary.BigEndian.PutUint64(buf, uint64(counter))

	mac := hmac.New(sha256.New, key)
	mac.Write(buf)
	sum := mac.Sum(nil)

	// Dynamic Truncation (RFC 4226 style, or simple modulo)
	// Taking last 2 bytes for simplicity and mapping to range
	offset := sum[len(sum)-1] & 0x0f
	binCode := binary.BigEndian.Uint32(sum[offset : offset+4])

	rangeSize := PortRangeEnd - PortRangeStart
	port := int(binCode)%rangeSize + PortRangeStart

	return port
}
