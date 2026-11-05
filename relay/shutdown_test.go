package main

import (
	"bytes"
	"context"
	"sync/atomic"
	"testing"
	"time"
)

// loopConn behaves like a socket whose close comes back as OnClose: shut posts the seat's leave.
func loopConn(write func([]byte)) (*conn, *atomic.Bool) {
	c := &conn{}
	var shut atomic.Bool
	c.sender = sender{write: write, shut: func() {
		shut.Store(true)
		go c.room.post(leaveMsg{c.seat})
	}}
	return c, &shut
}

func seated(t *testing.T, g *registry, match string, write func([]byte)) (*conn, *atomic.Bool) {
	t.Helper()
	c, shut := loopConn(write)
	res := g.join(&envelope{protocol: protocol, build: "b", match: match}, c)
	if res.seat == nil {
		t.Fatalf("join %q: %s", match, res.reason)
	}
	c.seat, c.room = res.seat, res.seat.r
	return c, shut
}

func within(t *testing.T, d time.Duration) context.Context {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), d)
	t.Cleanup(cancel)
	return ctx
}

func eventually(t *testing.T, what string, ok func() bool) {
	t.Helper()
	for deadline := time.Now().Add(2 * time.Second); !ok(); time.Sleep(5 * time.Millisecond) {
		if time.Now().After(deadline) {
			t.Fatal(what)
		}
	}
}

func nop([]byte) {}

func TestDrainClosesLobbyKeepsMatch(t *testing.T) {
	g := newRegistry(config{seats: 2})
	_, lobbyShut := seated(t, g, "", nop)
	a, aShut := seated(t, g, "", nop)
	seated(t, g, a.room.code, nop)
	g.startDrain()
	eventually(t, "lobby not closed", lobbyShut.Load)
	eventually(t, "lobby room not removed", func() bool { return g.count() == 1 })
	time.Sleep(50 * time.Millisecond)
	if aShut.Load() || g.count() != 1 {
		t.Fatal("started match was closed by drain")
	}
}

func TestStopClosesStartedMatch(t *testing.T) {
	g := newRegistry(config{seats: 2})
	a, aShut := seated(t, g, "", nop)
	_, bShut := seated(t, g, a.room.code, nop)
	g.startDrain()
	if g.waitEmpty(within(t, 100*time.Millisecond)) {
		t.Fatal("match ended without stop")
	}
	g.stop()
	if !g.waitEmpty(within(t, 2*time.Second)) {
		t.Fatalf("%d rooms left after stop", g.count())
	}
	if !aShut.Load() || !bShut.Load() {
		t.Fatal("a seat was not closed")
	}
}

func TestRoomPanicEndsOnlyThatRoom(t *testing.T) {
	g := newRegistry(config{seats: 2})
	boom := func(f []byte) {
		if bytes.Contains(f, []byte(`"tick"`)) {
			panic("boom")
		}
	}
	a, aShut := seated(t, g, "", nop)
	_, bShut := seated(t, g, a.room.code, boom)
	other, _ := seated(t, g, "", nop)
	a.room.post(tickMsg{a.seat, 1, inputDelay, []byte(`{"type":"tick"}`)})
	select {
	case <-a.room.done:
	case <-time.After(2 * time.Second):
		t.Fatal("panicking room did not end")
	}
	if !aShut.Load() || !bShut.Load() {
		t.Fatal("seats of the crashed room were not closed")
	}
	for range 100 {
		a.room.post(leaveMsg{a.seat}) // must not block once the room is gone
	}
	if g.count() != 1 || g.rooms[other.room.code] == nil {
		t.Fatalf("want only the other room left, have %d", g.count())
	}
}
