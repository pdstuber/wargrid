package main

import (
	"context"
	"crypto/rand"
	"encoding/binary"
	"fmt"
	"log/slog"
	"maps"
	"runtime/debug"
	"slices"
	"strings"
	"sync"
	"time"
)

const (
	codeAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	protocol     = 2
	inputDelay   = 4
)

type config struct {
	seats     int
	testDelay time.Duration
	batch     time.Duration
}

type seat struct {
	n        int
	c        *conn
	r        *room
	lastTick int
	frames   int
	bytes    int
	dead     bool // rejected: ignore further input, still counts until the socket closes
}

type joinReq struct {
	hello *envelope
	c     *conn
	reply chan joinResult
}

type joinResult struct {
	seat   *seat
	reason string
}

type tickMsg struct {
	s    *seat
	seat int
	tick int
	data []byte // one copy, shared read-only by every recipient
}

type leaveMsg struct{ s *seat }

// room owns all its state in run(); connections talk to it only through channels.
type room struct {
	code     string
	cfg      config
	reg      *registry
	build    string
	joins    chan joinReq // unbuffered: a send succeeds only while run() is alive
	events   chan any
	done     chan struct{}
	seats    map[int]*seat
	started  bool
	settings []byte
	stats    map[int]string
}

func (r *room) run() {
	defer close(r.done)
	defer r.recoverCrash()
	drain, quit := r.reg.draining, r.reg.quit
	var flush <-chan time.Time
	if r.cfg.batch > 0 {
		t := time.NewTicker(r.cfg.batch)
		defer t.Stop()
		flush = t.C
	}
	for {
		select {
		case <-flush:
			for _, s := range r.seats {
				s.c.flushNow()
			}
		case <-drain:
			drain = nil
			if !r.started { // no new connections arrive while draining, so the lobby can never fill
				r.closeAll()
			}
		case <-quit:
			quit = nil
			r.closeAll()
		case j := <-r.joins:
			j.reply <- r.join(j)
		case ev := <-r.events:
			switch ev := ev.(type) {
			case tickMsg:
				r.forward(ev)
			case leaveMsg:
				if r.leave(ev.s) {
					return
				}
			}
		}
	}
}

// post never blocks on a room whose goroutine has ended.
func (r *room) post(ev any) {
	select {
	case r.events <- ev:
	case <-r.done:
	}
}

// closeAll ends every seat's socket; each close comes back as a leave.
func (r *room) closeAll() {
	for _, s := range r.seats {
		s.c.close()
	}
}

// recoverCrash ends only this room when its goroutine panics.
func (r *room) recoverCrash() {
	p := recover()
	if p == nil {
		return
	}
	slog.Error("room crashed", "code", r.code, "panic", p, "stack", string(debug.Stack()))
	r.reg.remove(r.code, r)
	r.closeAll()
}

func (r *room) join(j joinReq) joinResult {
	h := j.hello
	if r.build != h.build {
		return joinResult{reason: "build mismatch"}
	}
	if r.started || len(r.seats) >= r.cfg.seats {
		return joinResult{reason: "match full"}
	}
	return joinResult{seat: r.admit(j.c)}
}

func (r *room) admit(c *conn) *seat {
	n := 1
	for r.seats[n] != nil {
		n++
	}
	s := &seat{n: n, c: c, r: r}
	r.seats[n] = s
	slog.Info("seat joined", "code", r.code, "seat", n)
	c.send([]byte(fmt.Sprintf(`{"type":"welcome","seat":%d,"match":%q}`, n, r.code)), 0)
	if len(r.seats) == r.cfg.seats {
		r.started = true
		list := make([]string, r.cfg.seats)
		for i := range list {
			list[i] = fmt.Sprint(i + 1)
		}
		slog.Info("match start", "code", r.code, "seats", r.cfg.seats)
		start := []byte(fmt.Sprintf(`{"type":"start","seats":[%s],"delay":%d,"seed":%d,"settings":%s}`, strings.Join(list, ","), inputDelay, randomSeed(), r.settings))
		for _, s := range r.seats {
			s.c.send(start, 0)
		}
	}
	return s
}

func (r *room) forward(t tickMsg) {
	s := t.s
	if s.dead {
		return
	}
	if !r.started || t.seat != s.n || t.tick != max(s.lastTick, inputDelay-1)+1 {
		s.dead = true
		s.c.reject("invalid message")
		return
	}
	s.lastTick, s.frames, s.bytes = t.tick, s.frames+1, s.bytes+len(t.data)
	for _, o := range r.seats {
		if o != s {
			if r.cfg.batch > 0 {
				o.c.addBatch(t.data)
			} else {
				o.c.send(t.data, r.cfg.testDelay)
			}
		}
	}
}

// leave reports whether the room is now empty and has been removed.
func (r *room) leave(s *seat) bool {
	delete(r.seats, s.n)
	left := []byte(fmt.Sprintf(`{"type":"left","seat":%d,"after_tick":%d}`, s.n, max(s.lastTick, inputDelay-1)))
	for _, o := range r.seats {
		o.c.send(left, 0)
	}
	r.stats[s.n] = fmt.Sprintf("%df/%dB", s.frames, s.bytes)
	if len(r.seats) > 0 {
		return false
	}
	r.reg.remove(r.code, r)
	args := []any{"code", r.code}
	for _, n := range slices.Sorted(maps.Keys(r.stats)) {
		args = append(args, fmt.Sprintf("seat%d", n), r.stats[n])
	}
	slog.Info("MATCH END", args...)
	return true
}

// registry is only touched on create, lookup and removal, never per frame.
type registry struct {
	mu       sync.Mutex
	rooms    map[string]*room
	cfg      config
	draining chan struct{} // closed on shutdown signal
	quit     chan struct{} // closed when the drain deadline passes
}

func newRegistry(cfg config) *registry {
	return &registry{rooms: map[string]*room{}, cfg: cfg, draining: make(chan struct{}), quit: make(chan struct{})}
}

func (g *registry) startDrain() { close(g.draining) }
func (g *registry) stop()       { close(g.quit) }

func (g *registry) count() int {
	g.mu.Lock()
	defer g.mu.Unlock()
	return len(g.rooms)
}

// waitEmpty reports whether every room ended before ctx was done.
func (g *registry) waitEmpty(ctx context.Context) bool {
	t := time.NewTicker(50 * time.Millisecond)
	defer t.Stop()
	for g.count() > 0 {
		select {
		case <-ctx.Done():
			return false
		case <-t.C:
		}
	}
	return true
}

func (g *registry) remove(code string, r *room) {
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.rooms[code] == r {
		delete(g.rooms, code)
	}
}

func (g *registry) join(h *envelope, c *conn) joinResult {
	if h.protocol != protocol {
		return joinResult{reason: "protocol mismatch"}
	}
	if h.badSettings {
		return joinResult{reason: "invalid message"}
	}
	if h.match == "" {
		if h.settings == nil {
			return joinResult{reason: "missing settings"}
		}
		return g.create(h, c)
	}
	g.mu.Lock()
	r := g.rooms[h.match]
	g.mu.Unlock()
	if r == nil {
		return joinResult{reason: "unknown match"}
	}
	req := joinReq{h, c, make(chan joinResult, 1)}
	select {
	case r.joins <- req:
		select {
		case res := <-req.reply:
			return res
		case <-r.done: // crashed mid-join
			return joinResult{reason: "unknown match"}
		}
	case <-r.done:
		return joinResult{reason: "unknown match"}
	}
}

func (g *registry) create(h *envelope, c *conn) joinResult {
	g.mu.Lock()
	code := randomCode()
	for g.rooms[code] != nil {
		code = randomCode()
	}
	r := &room{
		code: code, cfg: g.cfg, reg: g, build: h.build, settings: h.settings,
		joins: make(chan joinReq), events: make(chan any, 64), done: make(chan struct{}),
		seats: map[int]*seat{}, stats: map[int]string{},
	}
	g.rooms[code] = r
	g.mu.Unlock()
	slog.Info("room created", "code", code, "build", h.build)
	s := r.admit(c) // before run() starts: nobody else knows the code yet
	go r.run()
	return joinResult{seat: s}
}

func randomSeed() int {
	var b [4]byte
	rand.Read(b[:])
	return int(binary.BigEndian.Uint32(b[:]) & 0x7fffffff)
}

func randomCode() string {
	b := make([]byte, 6)
	rand.Read(b)
	for i := range b {
		b[i] = codeAlphabet[int(b[i])%len(codeAlphabet)] // 256 % 32 == 0: unbiased
	}
	return string(b)
}
