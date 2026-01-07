package siren

import (
	"bytes"
	"encoding/binary"
	"errors"
	"math/rand"
	"time"
)

const (
	RTPHeaderSize = 12
	PayloadType   = 111 // Dynamic Payload Type (Common for Opus Audio)
)

func init() {
	rand.Seed(time.Now().UnixNano())
}

// RTPContext maintains state (Sequence Number, etc.)
type RTPContext struct {
	Sequence  uint16
	Timestamp uint32
	SSRC      uint32
}

func NewContext() *RTPContext {
	return &RTPContext{
		Sequence:  uint16(rand.Intn(65535)),
		Timestamp: rand.Uint32(),
		SSRC:      rand.Uint32(),
	}
}

// Wrap converts data to RTP packet
func (ctx *RTPContext) Wrap(payload []byte) []byte {
	buf := new(bytes.Buffer)

	// Byte 0: Version (2) + Padding (0) + Extension (0) + CSRC Count (0) -> 0x80
	buf.WriteByte(0x80)

	// Byte 1: Marker (0) + Payload Type (111) -> 0x6F
	buf.WriteByte(byte(PayloadType))

	// Bytes 2-3: Sequence Number
	ctx.Sequence++
	binary.Write(buf, binary.BigEndian, ctx.Sequence)

	// Bytes 4-7: Timestamp (20ms step: 48000Hz * 0.02s = 960 samples)
	ctx.Timestamp += 960
	binary.Write(buf, binary.BigEndian, ctx.Timestamp)

	// Bytes 8-11: SSRC
	binary.Write(buf, binary.BigEndian, ctx.SSRC)

	// Payload
	buf.Write(payload)

	return buf.Bytes()
}

// Unwrap extracts payload from RTP packet
func Unwrap(packet []byte) ([]byte, error) {
	if len(packet) < RTPHeaderSize {
		return nil, errors.New("packet too short")
	}

	// Check Version (0x80)
	if packet[0]&0xC0 != 0x80 {
		return nil, errors.New("invalid RTP version")
	}

	// Payload starts at offset 12
	return packet[RTPHeaderSize:], nil
}
