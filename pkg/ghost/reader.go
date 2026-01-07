package ghost

import (
	"bufio"
	"fmt"
	"io"
	"net/textproto"
	"strconv"
)

// Reader is a request-based reader that extracts Ghost packets from a stream.
type Reader struct {
	br *bufio.Reader
}

func NewReader(r io.Reader) *Reader {
	return &Reader{
		br: bufio.NewReader(r), // 4KB buffer default
	}
}

// ReadPacket reads one full Ghost encapsulated message.
// It returns the payload (Mirage frame) or an error.
func (r *Reader) ReadPacket() ([]byte, error) {
	// 1. Read HTTP Header until \r\n\r\n
	// using ReadMIMEHeader mechanism or simple search

	// We use textproto.Reader because it handles the header parsing conveniently
	tp := textproto.NewReader(r.br)

	// Read Request Line (POST /... HTTP/1.1)
	_, err := tp.ReadLine()
	if err != nil {
		return nil, err
	}

	// Read Headers
	mimeHeader, err := tp.ReadMIMEHeader()
	if err != nil {
		return nil, err
	}

	// Extract Content-Length
	clStr := mimeHeader.Get("Content-Length")
	if clStr == "" {
		return nil, fmt.Errorf("missing content-length")
	}

	length, err := strconv.Atoi(clStr)
	if err != nil {
		return nil, fmt.Errorf("invalid content-length")
	}

	// Read Body (Mirage Frame)
	// We must read exactly 'length' bytes
	body := make([]byte, length)
	if _, err := io.ReadFull(r.br, body); err != nil {
		return nil, err
	}

	return body, nil
}

// ReadRawPacket reads a Length-Prefixed packet (No HTTP Header).
// Format: [Length (2 bytes)] [Body]
func (r *Reader) ReadRawPacket() ([]byte, error) {
	header := make([]byte, 2)
	if _, err := io.ReadFull(r.br, header); err != nil {
		return nil, err
	}
	length := int(header[0])<<8 | int(header[1])

	body := make([]byte, length)
	if _, err := io.ReadFull(r.br, body); err != nil {
		return nil, err
	}
	return body, nil
}

// Helper to peek if there is data easily (optional, for debugging)
func (r *Reader) Buffered() int {
	return r.br.Buffered()
}
