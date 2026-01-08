package device

import (
	"crypto/rand"
	"encoding/hex"
	"os"
	"path/filepath"
)

// GetHardwareID returns a persistent unique identifier for this installation.
// It stores the ID in the given storagePath.
func GetHardwareID(storagePath string) (string, error) {
	idFile := filepath.Join(storagePath, "aether_device_id")

	// 1. Try to read existing ID
	if data, err := os.ReadFile(idFile); err == nil {
		return string(data), nil
	}

	// 2. Generate new ID if not exists
	newID := generateRandomID()

	// 3. Save it
	if err := os.WriteFile(idFile, []byte(newID), 0644); err != nil {
		return "", err
	}

	return newID, nil
}

func generateRandomID() string {
	b := make([]byte, 16)
	rand.Read(b)
	return hex.EncodeToString(b)
}
