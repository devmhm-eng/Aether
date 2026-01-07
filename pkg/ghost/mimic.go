package ghost

import (
	"bytes"
	"fmt"
	"math/rand"
)

// List of fake paths to mislead firewalls
var videoPaths = []string{
	"/stream/movie_720p.m4s",
	"/api/v2/hls/segment_01.ts",
	"/uploads/images/banner_ads.jpg",
	"/assets/fonts/roboto-bold.woff2",
}

// generateFakeHeader creates a dynamic fake HTTP header
func generateFakeHeader(payloadLen int) []byte {
	// Select a random path
	path := videoPaths[rand.Intn(len(videoPaths))]

	// Create standard HTTP header
	// Note: Content-Length matches the Mirage data length
	header := fmt.Sprintf(
		"POST %s HTTP/1.1\r\n"+
			"Host: cdn.cloudflare.net\r\n"+
			"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)\r\n"+
			"Content-Type: application/octet-stream\r\n"+
			"Content-Length: %d\r\n"+
			"\r\n", // Empty line separating header from body
		path,
		payloadLen,
	)
	return []byte(header)
}

// WrapRequest wraps the payload with an HTTP header
func WrapRequest(payload []byte) []byte {
	header := generateFakeHeader(len(payload))

	var buf bytes.Buffer
	buf.Write(header)
	buf.Write(payload) // Mirage data (with noise) goes here

	return buf.Bytes()
}

// UnwrapRequest strips the header and returns real data
func UnwrapRequest(data []byte) ([]byte, error) {
	// Find end of HTTP header (\r\n\r\n)
	separator := []byte("\r\n\r\n")
	index := bytes.Index(data, separator)

	if index == -1 {
		// If header not found, data might be corrupted or it's an attack
		return nil, fmt.Errorf("invalid ghost header")
	}

	// Return everything after the header (Body)
	// Header length + 4 bytes separator
	return data[index+4:], nil
}
