package main

import (
	"sync"
	"testing"
)

func TestConcurrentJoinsNeverOverfill(t *testing.T) {
	g := &registry{rooms: map[string]*room{}, cfg: config{seats: 2}}
	first := g.create(&envelope{protocol: protocol, build: "b", settings: []byte("{}")}, &conn{sender: sender{write: func([]byte) {}, shut: func() {}}})
	code := first.seat.r.code
	var wg sync.WaitGroup
	var mu sync.Mutex
	ok := 0
	for range 20 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if g.join(&envelope{protocol: protocol, build: "b", match: code}, &conn{sender: sender{write: func([]byte) {}, shut: func() {}}}).seat != nil {
				mu.Lock()
				ok++
				mu.Unlock()
			}
		}()
	}
	wg.Wait()
	if ok != 1 {
		t.Fatalf("%d joiners got the second seat", ok)
	}
}
