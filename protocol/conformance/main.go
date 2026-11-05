// Command conformance runs the black-box relay protocol suite against a running relay.
// Profiles need the server started with matching settings: default (none), silence (any silence
// timeout, passed as -silence), delay (WARGRID_TEST_DELAY_MS=250).
package main

import (
	"flag"
	"os"
)

func main() {
	url := flag.String("url", "ws://127.0.0.1:8080/ws", "relay websocket url")
	profile := flag.String("profile", "default", "default|silence|delay")
	flag.DurationVar(&silence, "silence", silence, "server silence timeout (silence profile)")
	flag.Parse()
	os.Exit(runConform(*url, *profile))
}
