package main

import "log"

// validateUserProtocol checks if a user is allowed to use a specific protocol
// Returns true if allowed, false otherwise
func validateUserProtocol(uuid, protocol string) bool {
	// If Horizon is not enabled, allow all (backward compatibility)
	if horizonLoader == nil {
		return true
	}

	// Check with Horizon database
	allowed := horizonLoader.IsProtocolAllowed(uuid, protocol)

	if !allowed {
		log.Printf("🚫 User %s attempted to use protocol %s but is not authorized", uuid, protocol)
	}

	return allowed
}

// getProtocolName attempts to identify which protocol is being used
// This is a simple detection based on current implementation
func getProtocolName(connectionType string) string {
	switch connectionType {
	case "flux":
		return "flux"
	case "websocket":
		return "websocket"
	case "grpc":
		return "grpc"
	case "http":
		return "http"
	default:
		return "flux" // Default to flux for backward compatibility
	}
}
