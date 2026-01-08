package main

import "C"
import (
	"aether/pkg/mobile"
)

//export Start
func Start(configJSON *C.char) *C.char {
	conf := C.GoString(configJSON)
	err := mobile.Start(conf)
	if err != nil {
		return C.CString(err.Error())
	}
	return nil
}

//export Stop
func Stop() {
	mobile.Stop()
}

//export GetStats
func GetStats() *C.char {
	stats := mobile.GetStats()
	return C.CString(stats)
}

//export SecureRequest
func SecureRequest(endpoint *C.char, payload *C.char) *C.char {
	ep := C.GoString(endpoint)
	pl := C.GoString(payload)
	resp := mobile.SecureRequest(ep, pl)
	return C.CString(resp)
}

func main() {}
