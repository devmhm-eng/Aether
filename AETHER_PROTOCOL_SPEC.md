# Aether Protocol Specification (v1.0)
**Next-Generation Polymorphic VPN Protocol**

## 1. Executive Summary
Aether is a custom-designed VPN protocol engineered to bypass advanced Deep Packet Inspection (DPI) systems. Unlike traditional protocols (VLESS/VMess/Trojan) which rely on static signatures, Aether employs a **Polymorphic Architecture** comprising three distinct layers: **Flux** (Transport), **Mirage** (Obfuscation), and **Ghost** (Mimicry). This multi-layer approach ensures both high performance via QUIC/UDP and high availability via seamless TCP fallback.

---

## 2. Core Architecture

The protocol stack consists of three layers:

### Layer 1: Ghost (Mimicry & Handshake) 👻
**Purpose:** Defeat Active Probing & DPI Whitelisting.
*   **Mechanism:** Encapsulates every packet within a legitimate-looking HTTP/1.1 or HTTP/2 frame.
*   **Behavior:**
    *   **Fake Headers:** Generates dynamic HTTP verbs (`POST`, `GET`) and paths (`/stream/movie_720p.m4s`, `/assets/font.woff2`) to mimic video streaming or web browsing.
    *   **Active Defense:** If a probe sends non-compliant data (e.g., standard TCP handshake without valid Ghost headers), the server silently drops the connection or mimics a generic 404 error, preventing identification.
    *   **Zero-RTT:** Handshake is embedded in the first data payload, reducing latency.

### Layer 2: Mirage (Obfuscation & Padding) 🌫️
**Purpose:** Defeat Traffic Analysis (Entropy & Length probing).
*   **Mechanism:** Wraps the actual encrypted payload with dynamic, meaningless noise.
*   **Behavior:**
    *   **Dynamic Padding:** Adds random bytes (0-255 bytes) to every packet. This prevents side-channel attacks based on packet size (e.g., identifying a TLS handshake by its specific size).
    *   **Jitter:** Modifies packet timing and size to look like Variable Bitrate (VBR) video traffic rather than a constant VPN stream.
    *   **Codec:** `Seal()` and `Open()` functions ensure that the padding is stripped correctly at the destination without data corruption.

### Layer 3: Flux (Hybrid Transport Engine) ⚡
**Purpose:** Reliability & Performance.
*   **Mechanism:** A smart hybrid transport engine that utilizes both UDP and TCP.
*   **Behavior:**
    *   **Primary Channel (UDP/QUIC):** Uses a modified QUIC protocol for high-throughput, low-latency communication. Ideal for streaming and VoIP.
    *   **Secondary Channel (TCP/TLS):** If UDP is throttled or blocked by the ISP firewall, Flux **seamlessly** and instantly degrades to a standard TCP/TLS connection without dropping the session.
    *   **Multiplexing (Smux):** Implements `smux` (Simple Multiplexing) to tunnel thousands of concurrent TCP streams (e.g., loading a modern website) inside a single physical connection, eliminating Head-of-Line blocking.

---

## 3. Key Features

| Feature | Description | Benefit |
| :--- | :--- | :--- |
| **Hybrid Transport** | Auto-switching between UDP and TCP. | Works even in hostile networks that throttle UDP. |
| **Packet Morphing** | Packets look like HTTP video streams. | Bypasses "Protocol Whitelisting" firewalls. |
| **Anti-Probe** | Server rejects invalid connections silently. | Prevents censors from "scanning" for VPN servers. |
| **Multiplexing** | Single connection for all traffic. | extremely fast page loads; lower handshake overhead. |
| **Resilience** | Auto-reconnection logic with exponential backoff. | surviving network interruptions or server restarts. |
| **SOCKS5 Native** | Built-in SOCKS5 inbound listener (Port 1080). | Compatible with all browsers, messengers (Telegram), and OS proxies. |

---

## 4. Technical Workflow

1.  **Inbound:** Client receives traffic via SOCKS5 (Port 1080).
2.  **Muxing:** Data is encapsulated into a `smux` stream.
3.  **Mirage:** Stream data is encrypted and padded with random bytes.
4.  **Ghost:** Padded data is wrapped in a fake HTTP POST request header.
5.  **Flux:**
    *   Attempts to send via **UDP (QUIC)**.
    *   If blocked/failed, instantly sends via **TCP (TLS)**.
6.  **Server:**
    *   Receives packet.
    *   Validates Ghost Header (Anti-Probe).
    *   Removes Padding (Mirage).
    *   Demultiplexes stream.
    *   Forwards to target (Internet).

---

## 5. Deployment Status

*   **Server:** Linux (amd64) binary. Deploys via `manage.sh` script with systemd service and auto-config generation.
*   **Client:** macOS (arm64) & Windows (amd64) binaries. Portable, single-file executables.
*   **Configuration:** Simple `config.json` for distributing credentials.
