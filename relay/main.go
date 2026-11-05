// Command relay forwards lockstep tick frames between the seats of a Wargrid match.
package main

import (
	"bytes"
	"log"
	"net/http"
	"os"
	"strconv"
	"sync/atomic"
	"time"

	"github.com/lxzan/gws"
)

const closeGrace = 200 * time.Millisecond

type conn struct {
	sender
	rejected atomic.Bool
	room     *room // set by the reader goroutine after a successful hello
	seat     *seat
}

func (c *conn) reject(reason string) {
	if c.rejected.Swap(true) {
		return
	}
	c.send([]byte(`{"type":"error","reason":"`+reason+`"}`), 0)
	// Godot drops frames still queued when it sees the close, so the error must land first.
	time.AfterFunc(closeGrace, c.close)
}

type relay struct {
	reg     *registry
	silence time.Duration
}

func envInt(name string, def int) int {
	if v, err := strconv.Atoi(os.Getenv(name)); err == nil {
		return v
	}
	return def
}

func getConn(s *gws.Conn) *conn { v, _ := s.Session().Load("c"); return v.(*conn) }

// writeLater runs w in the connection's ordered write queue. The deadline makes a write to a peer that stopped
// reading fail and close the socket; otherwise it holds gws's write lock forever and OnClose (and `left`) never runs.
func (h *relay) writeLater(s *gws.Conn, w func() error) {
	s.Async(func() {
		_ = s.SetWriteDeadline(time.Now().Add(h.silence))
		_ = w()
	})
}

func (h *relay) OnOpen(s *gws.Conn) {
	s.Session().Store("c", &conn{sender: sender{
		write: func(f []byte) { h.writeLater(s, func() error { return s.WriteMessage(gws.OpcodeText, f) }) },
		shut:  func() { h.writeLater(s, func() error { return s.WriteClose(1000, nil) }) },
	}})
	_ = s.SetReadDeadline(time.Now().Add(h.silence))
}

func (h *relay) OnClose(s *gws.Conn, _ error) {
	if c := getConn(s); c.seat != nil {
		c.room.events <- leaveMsg{c.seat}
	}
}

func (h *relay) OnPing(s *gws.Conn, p []byte) {
	p = bytes.Clone(p)
	h.writeLater(s, func() error { return s.WritePong(p) })
}
func (h *relay) OnPong(*gws.Conn, []byte) {}

func (h *relay) OnMessage(s *gws.Conn, msg *gws.Message) {
	defer msg.Close()
	c := getConn(s)
	if c.rejected.Load() {
		return
	}
	_ = s.SetReadDeadline(time.Now().Add(h.silence))
	if msg.Opcode != gws.OpcodeText {
		c.rejected.Store(true)
		c.close()
		return
	}
	e := parseEnvelope(msg.Bytes())
	if e == nil || (c.seat == nil) != (e.typ == "hello") {
		c.reject("invalid message")
		return
	}
	switch e.typ {
	case "hello":
		res := h.reg.join(e, c)
		if res.seat == nil {
			c.reject(res.reason)
			return
		}
		c.seat = res.seat
		c.room = res.seat.r
	case "tick":
		c.room.events <- tickMsg{c.seat, e.seat, e.tick, bytes.Clone(msg.Bytes())}
	case "ping":
		c.send([]byte(`{"type":"pong","t":`+e.t+`}`), 0)
	}
}

func main() {
	cfg := config{
		seats:     max(1, envInt("WARGRID_SEATS", 2)),
		testDelay: time.Duration(envInt("WARGRID_TEST_DELAY_MS", 0)) * time.Millisecond,
		batch:     time.Duration(envInt("WARGRID_BATCH_MS", 0)) * time.Millisecond,
	}
	h := &relay{
		reg:     &registry{rooms: map[string]*room{}, cfg: cfg},
		silence: time.Duration(envInt("WARGRID_SILENCE_MS", 10000)) * time.Millisecond,
	}
	up := gws.NewUpgrader(h, &gws.ServerOption{ReadMaxPayloadSize: 1 << 20, CheckUtf8Enabled: true})
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write([]byte("ok")) })
	mux.HandleFunc("GET /ws", func(w http.ResponseWriter, r *http.Request) {
		if s, err := up.Upgrade(w, r); err == nil {
			go s.ReadLoop()
		}
	})
	addr := ":" + os.Getenv("PORT")
	if addr == ":" {
		addr = ":8080"
	}
	srv := &http.Server{Addr: addr, Handler: mux, ReadHeaderTimeout: 10 * time.Second, IdleTimeout: 60 * time.Second}
	log.Fatal(srv.ListenAndServe())
}
