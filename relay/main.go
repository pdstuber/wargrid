// Command relay forwards lockstep tick frames between the seats of a Wargrid match.
package main

import (
	"bytes"
	"context"
	"errors"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/lxzan/gws"
)

const (
	closeGrace = 200 * time.Millisecond
	stopGrace  = time.Second // close handshakes after a forced stop
	// Far above legitimate traffic; a peer reading slower than the room sends is cut off before memory runs out.
	maxQueuedBytes = 1 << 20
	jobOverhead    = 256 // charged per job so empty pings count too
)

type conn struct {
	sender
	rejected atomic.Bool
	queued   atomic.Int64 // bytes waiting in gws's unbounded write queue
	room     *room        // set by the reader goroutine after a successful hello
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
	v, ok := os.LookupEnv(name)
	if !ok {
		return def
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		slog.Error("invalid config", "var", name, "value", v)
		os.Exit(2)
	}
	return n
}

func getConn(s *gws.Conn) *conn { v, _ := s.Session().Load("c"); return v.(*conn) }

// writeLater runs w in the connection's ordered write queue. The deadline makes a write to a peer that stopped
// reading fail and close the socket; otherwise it holds gws's write lock forever and OnClose (and `left`) never runs.
func (h *relay) writeLater(s *gws.Conn, n int, w func() error) {
	q := &getConn(s).queued
	cost := int64(n + jobOverhead)
	if v := q.Add(cost); v > maxQueuedBytes {
		if v-cost <= maxQueuedBytes {
			slog.Warn("write queue full, closing")
		}
		// Close the socket directly: a queued close would wait behind the backlog.
		_ = s.NetConn().Close()
		return
	}
	s.Async(func() {
		defer q.Add(-cost)
		_ = s.SetWriteDeadline(time.Now().Add(h.silence))
		_ = w()
	})
}

func (h *relay) OnOpen(s *gws.Conn) {
	s.Session().Store("c", &conn{sender: sender{
		write: func(f []byte) { h.writeLater(s, len(f), func() error { return s.WriteMessage(gws.OpcodeText, f) }) },
		shut:  func() { h.writeLater(s, 0, func() error { return s.WriteClose(1000, nil) }) },
	}})
	_ = s.SetReadDeadline(time.Now().Add(h.silence))
	slog.Info("connection opened")
}

func (h *relay) OnClose(s *gws.Conn, err error) {
	slog.Info("connection closed", "err", err)
	if c := getConn(s); c.seat != nil {
		c.room.post(leaveMsg{c.seat})
	}
}

func (h *relay) OnPing(s *gws.Conn, p []byte) {
	p = bytes.Clone(p)
	h.writeLater(s, len(p), func() error { return s.WritePong(p) })
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
			slog.Info("join rejected", "reason", res.reason)
			c.reject(res.reason)
			return
		}
		c.seat = res.seat
		c.room = res.seat.r
	case "tick":
		c.room.post(tickMsg{c.seat, e.seat, e.tick, bytes.Clone(msg.Bytes())})
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
	silence := time.Duration(envInt("WARGRID_SILENCE_MS", 10000)) * time.Millisecond
	drain := time.Duration(envInt("WARGRID_DRAIN_MS", 3500)) * time.Millisecond
	addr := ":" + os.Getenv("PORT")
	if addr == ":" {
		addr = ":8080"
	}
	reg := newRegistry(cfg)
	ln, err := net.Listen("tcp", addr)
	if err != nil {
		slog.Error("listen failed", "err", err)
		os.Exit(1)
	}
	slog.Info("relay started", "addr", addr, "seats", cfg.seats, "silence", silence, "batch", cfg.batch, "drain", drain)
	if err := serve(ln, newServer(&relay{reg: reg, silence: silence}), reg, drain); err != nil {
		slog.Error("serve failed", "err", err)
		os.Exit(1)
	}
}

func serve(ln net.Listener, srv *http.Server, reg *registry, drain time.Duration) error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	errc := make(chan error, 1)
	go func() { errc <- srv.Serve(ln) }()
	select {
	case err := <-errc:
		return err
	case <-ctx.Done():
	}
	stop() // a second signal exits immediately
	shutdown(srv, reg, drain)
	return nil
}

func newServer(h *relay) *http.Server {
	up := gws.NewUpgrader(h, &gws.ServerOption{ReadMaxPayloadSize: 1 << 20, CheckUtf8Enabled: true, Recovery: gws.Recovery})
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write([]byte("ok")) })
	mux.HandleFunc("GET /ws", func(w http.ResponseWriter, r *http.Request) {
		if s, err := up.Upgrade(w, r); err == nil {
			go s.ReadLoop()
		}
	})
	return &http.Server{Handler: mux, ReadHeaderTimeout: 10 * time.Second, IdleTimeout: 60 * time.Second}
}

// shutdown stops accepting connections, lets started matches run until drain passes, then closes the rest.
// http.Server.Shutdown does not wait for WebSockets (hijacked), so rooms are tracked by the registry.
func shutdown(srv *http.Server, reg *registry, drain time.Duration) {
	slog.Info("draining", "rooms", reg.count(), "timeout", drain)
	ctx, cancel := context.WithTimeout(context.Background(), drain)
	defer cancel()
	reg.startDrain()
	if err := srv.Shutdown(ctx); err != nil && !errors.Is(err, context.DeadlineExceeded) {
		slog.Warn("http shutdown", "err", err)
	}
	_ = srv.Close() // HTTP requests still open at the deadline
	forced := 0
	if !reg.waitEmpty(ctx) {
		forced = reg.count()
		reg.stop()
		grace, cancelGrace := context.WithTimeout(context.Background(), stopGrace)
		defer cancelGrace()
		reg.waitEmpty(grace)
	}
	slog.Info("stopped", "forced", forced, "remaining", reg.count())
}
