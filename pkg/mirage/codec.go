package mirage

import (
	"bytes"
	"crypto/rand"
	"crypto/sha256"
	"encoding/binary"
	"errors"
	"math/big"

	"golang.org/x/crypto/chacha20poly1305"
)

const (
	MaxPadding = 256
	HeaderSize = 4 // TotalLen(2) + PayloadLen(2)
	AuthIDSize = 16
)

// Seal encrypts data using the UUID as key.
// Format: [AuthID(16)] [Nonce(12)] [Encrypted(Header+Payload+Padding)]
func Seal(payload []byte, uuid string) ([]byte, error) {
	// 1. Prepare Key (SHA256 of UUID -> 32 bytes for ChaCha20)
	key := sha256.Sum256([]byte(uuid))
	aead, err := chacha20poly1305.New(key[:])
	if err != nil {
		return nil, err
	}

	// 2. Prepare AuthID (First 16 bytes of HasdH(UUID))
	// This allows server to find which key to use.
	// In production, maybe salt this? For now, simple static hash for stable ID.
	authID := key[:AuthIDSize]

	// 3. Prepare Payload + Padding
	padding := generatePadding()
	payloadLen := uint16(len(payload))
	totalLen := uint16(HeaderSize) + payloadLen + uint16(len(padding))

	plaintext := new(bytes.Buffer)
	binary.Write(plaintext, binary.BigEndian, totalLen)
	binary.Write(plaintext, binary.BigEndian, payloadLen)
	plaintext.Write(payload)
	plaintext.Write(padding)

	// 4. Encrypt
	nonce := make([]byte, aead.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		return nil, err
	}

	ciphertext := aead.Seal(nil, nonce, plaintext.Bytes(), nil)

	// 5. Pack
	// [AuthID] [Nonce] [Ciphertext]
	final := new(bytes.Buffer)
	final.Write(authID)
	final.Write(nonce)
	final.Write(ciphertext)

	return final.Bytes(), nil
}

// KeyStore interface for looking up keys
type KeyStore interface {
	GetUUID(authID []byte) (string, bool)
}

// Open decrypts data.
// It reads AuthID, finds UUID, and decrypts.
func Open(data []byte, store KeyStore) ([]byte, error) {
	if len(data) < AuthIDSize+12 { // Min size
		return nil, errors.New("packet too short")
	}

	// 1. Read AuthID
	authID := data[:AuthIDSize]
	uuid, ok := store.GetUUID(authID)
	if !ok {
		return nil, errors.New("invalid user (auth failed)")
	}

	// 2. Init Cipher
	key := sha256.Sum256([]byte(uuid))
	aead, err := chacha20poly1305.New(key[:])
	if err != nil {
		return nil, err
	}

	// 3. Decrypt
	nonce := data[AuthIDSize : AuthIDSize+aead.NonceSize()]
	ciphertext := data[AuthIDSize+aead.NonceSize():]

	plaintext, err := aead.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return nil, errors.New("decryption failed")
	}

	// 4. Decode Header/Padding (Same as old Open)
	reader := bytes.NewReader(plaintext)
	var totalLen uint16
	var payloadLen uint16
	binary.Read(reader, binary.BigEndian, &totalLen)
	binary.Read(reader, binary.BigEndian, &payloadLen)

	start := HeaderSize
	end := HeaderSize + int(payloadLen)
	if end > len(plaintext) {
		return nil, errors.New("corrupted inner packet")
	}

	return plaintext[start:end], nil
}

func generatePadding() []byte {
	n, _ := rand.Int(rand.Reader, big.NewInt(MaxPadding))
	padding := make([]byte, n.Int64())
	rand.Read(padding)
	return padding
}
