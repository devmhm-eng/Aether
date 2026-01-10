package main

import (
	"crypto/rand"
	"encoding/base64"
	"fmt"

	"golang.org/x/crypto/curve25519"
)

func main() {
	var privateKey [32]byte
	_, err := rand.Read(privateKey[:])
	if err != nil {
		panic(err)
	}

	var publicKey [32]byte
	curve25519.ScalarBaseMult(&publicKey, &privateKey)

	encodedPrivate := base64.RawURLEncoding.EncodeToString(privateKey[:])
	encodedPublic := base64.RawURLEncoding.EncodeToString(publicKey[:])

	fmt.Printf("Private: %s\nPublic: %s\n", encodedPrivate, encodedPublic)
}
