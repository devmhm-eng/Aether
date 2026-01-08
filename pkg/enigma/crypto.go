package enigma

import (
	"crypto/rand"
	"encoding/base64"
	"errors"
	"io"

	"golang.org/x/crypto/chacha20poly1305"
)

// GenerateKey generates a random 32-byte key for ChaCha20-Poly1305.
func GenerateKey() ([]byte, error) {
	key := make([]byte, chacha20poly1305.KeySize)
	if _, err := rand.Read(key); err != nil {
		return nil, err
	}
	return key, nil
}

// Seal encrypts the plaintext using ChaCha20-Poly1305.
// It generates a random nonce and prepends it to the ciphertext.
// Returns Base64 encoded string: Base64(Nonce + Ciphertext)
func Seal(plaintext []byte, key []byte) (string, error) {
	aead, err := chacha20poly1305.NewX(key) // Use XChaCha20 implementation which has a 24-byte nonce
	if err != nil {
		return "", err
	}

	nonce := make([]byte, aead.NonceSize(), aead.NonceSize()+len(plaintext)+aead.Overhead())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return "", err
	}

	// Encrypt and append to nonce
	encrypted := aead.Seal(nonce, nonce, plaintext, nil)

	return base64.StdEncoding.EncodeToString(encrypted), nil
}

// Open decrypts the Base64 encoded message.
// Expects: Base64(Nonce + Ciphertext)
func Open(b64Ciphertext string, key []byte) ([]byte, error) {
	data, err := base64.StdEncoding.DecodeString(b64Ciphertext)
	if err != nil {
		return nil, err
	}

	aead, err := chacha20poly1305.NewX(key)
	if err != nil {
		return nil, err
	}

	if len(data) < aead.NonceSize() {
		return nil, errors.New("ciphertext too short")
	}

	// Split nonce and ciphertext
	nonce, ciphertext := data[:aead.NonceSize()], data[aead.NonceSize():]

	// Decrypt
	plaintext, err := aead.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return nil, err
	}

	return plaintext, nil
}
