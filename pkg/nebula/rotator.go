package nebula

import (
	"crypto/rand"
	"net"
)

// GetRandomIPv6 generates a random IP in the given subnet (e.g. 2001:db8::/64)
func GetRandomIPv6(cidr string) (net.IP, error) {
	_, network, err := net.ParseCIDR(cidr)
	if err != nil {
		return nil, err
	}

	// Start with the network address
	ip := make(net.IP, len(network.IP))
	copy(ip, network.IP)

	// Mask
	ones, bits := network.Mask.Size()

	// Fill the host part with random bytes
	// Only modifying bytes strictly covered by host bits would be complex if not byte-aligned,
	// but /64 is byte aligned (8 bytes network, 8 bytes host).
	// Assuming /64 for simplicity as requested.

	bytesToRandomize := (bits - ones) / 8
	if bytesToRandomize > 0 {
		randBytes := make([]byte, bytesToRandomize)
		rand.Read(randBytes)

		// Copy random bytes to the end of IP
		start := len(ip) - bytesToRandomize
		copy(ip[start:], randBytes)
	}

	return ip, nil
}

// Config for Nebula
type Config struct {
	Enabled    bool
	SubnetCIDR string
}
