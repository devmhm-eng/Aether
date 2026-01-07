package transport

import (
	"io"
	"log"

	"github.com/pion/webrtc/v3"
)

// WebRTCManager handles PeerConnections
type WebRTCManager struct {
	Engine *webrtc.MediaEngine
	API    *webrtc.API
	Config webrtc.Configuration

	// Callback when a DataChannel is open and ready for Smux
	OnStream func(io.ReadWriteCloser)
}

func NewWebRTCManager() *WebRTCManager {
	// Register Default Codecs (even if we don't use video, for mimicry)
	m := &webrtc.MediaEngine{}
	if err := m.RegisterDefaultCodecs(); err != nil {
		log.Println("WebRTC Codec Error:", err)
	}

	api := webrtc.NewAPI(webrtc.WithMediaEngine(m))

	config := webrtc.Configuration{
		ICEServers: []webrtc.ICEServer{
			{URLs: []string{"stun:stun.l.google.com:19302"}},
		},
	}

	return &WebRTCManager{
		Engine: m,
		API:    api,
		Config: config,
	}
}

// AcceptOffer creates a PeerConnection, accepts the Offer, and returns an Answer.
// It also binds the DataChannel handler.
func (m *WebRTCManager) AcceptOffer(offerSDP string) (string, error) {
	pc, err := m.API.NewPeerConnection(m.Config)
	if err != nil {
		return "", err
	}

	// Handle Data Channel
	pc.OnDataChannel(func(d *webrtc.DataChannel) {
		d.OnOpen(func() {
			rwc := NewDataChannelRWC(d)
			if m.OnStream != nil {
				m.OnStream(rwc)
			}
		})
	})

	// Set Remote Description
	offer := webrtc.SessionDescription{Type: webrtc.SDPTypeOffer, SDP: offerSDP}
	if err := pc.SetRemoteDescription(offer); err != nil {
		pc.Close()
		return "", err
	}

	// Create Answer
	answer, err := pc.CreateAnswer(nil)
	if err != nil {
		pc.Close()
		return "", err
	}

	gatherComplete := webrtc.GatheringCompletePromise(pc)

	if err := pc.SetLocalDescription(answer); err != nil {
		pc.Close()
		return "", err
	}

	<-gatherComplete

	return pc.LocalDescription().SDP, nil
}

// DataChannelRWC wraps a Pion DataChannel as io.ReadWriteCloser
type DataChannelRWC struct {
	d *webrtc.DataChannel
	r *io.PipeReader
	w *io.PipeWriter
}

func NewDataChannelRWC(d *webrtc.DataChannel) *DataChannelRWC {
	pr, pw := io.Pipe()
	rwc := &DataChannelRWC{d: d, r: pr, w: pw}

	d.OnMessage(func(msg webrtc.DataChannelMessage) {
		pw.Write(msg.Data)
	})

	d.OnClose(func() {
		pw.Close()
	})

	return rwc
}

func (c *DataChannelRWC) Read(p []byte) (int, error) { return c.r.Read(p) }
func (c *DataChannelRWC) Write(p []byte) (int, error) {
	err := c.d.Send(p)
	if err != nil {
		return 0, err
	}
	return len(p), nil
}
func (c *DataChannelRWC) Close() error { return c.d.Close() }

// -------------------------------------------------------------
// WebRTC Client
// -------------------------------------------------------------

type WebRTCClient struct {
	Engine *webrtc.MediaEngine
	API    *webrtc.API
	Config webrtc.Configuration
	PC     *webrtc.PeerConnection
	Data   *webrtc.DataChannel
}

func NewWebRTCClient() *WebRTCClient {
	m := &webrtc.MediaEngine{}
	m.RegisterDefaultCodecs()
	api := webrtc.NewAPI(webrtc.WithMediaEngine(m))
	config := webrtc.Configuration{
		ICEServers: []webrtc.ICEServer{{URLs: []string{"stun:stun.l.google.com:19302"}}},
	}
	return &WebRTCClient{Engine: m, API: api, Config: config}
}

// Dial initiates the PeerConnection and returns the Offer SDP
func (c *WebRTCClient) CreateOffer() (string, error) {
	pc, err := c.API.NewPeerConnection(c.Config)
	if err != nil {
		return "", err
	}
	c.PC = pc

	// Create Data Channel
	dc, err := pc.CreateDataChannel("vpn", nil)
	if err != nil {
		pc.Close()
		return "", err
	}
	c.Data = dc

	offer, err := pc.CreateOffer(nil)
	if err != nil {
		pc.Close()
		return "", err
	}

	// Gather Candidates
	gatherComplete := webrtc.GatheringCompletePromise(pc)
	if err := pc.SetLocalDescription(offer); err != nil {
		pc.Close()
		return "", err
	}
	<-gatherComplete

	return pc.LocalDescription().SDP, nil
}

// SetAnswer sets the remote description and waits for DataChannel open
func (c *WebRTCClient) SetAnswer(answerSDP string) (io.ReadWriteCloser, error) {
	answer := webrtc.SessionDescription{Type: webrtc.SDPTypeAnswer, SDP: answerSDP}
	if err := c.PC.SetRemoteDescription(answer); err != nil {
		c.PC.Close()
		return nil, err
	}

	// Wait for DataChannel Open
	// We need a channel to signal completion.
	ready := make(chan io.ReadWriteCloser, 1)

	c.Data.OnOpen(func() {
		// Wrap
		rwc := NewDataChannelRWC(c.Data)
		ready <- rwc
	})

	// TODO: Timeout?
	return <-ready, nil
}
