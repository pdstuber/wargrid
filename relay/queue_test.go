package main

import (
	"net"
	"net/http/httptest"
	"runtime"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"

	"github.com/lxzan/gws"
)

// slowReader keeps reading, but slower than its peer sends, so no single write ever hits the deadline.
// At ~120 KB/s a close queued behind a 1 MiB backlog would land after the 3 s wait, so only a direct close passes.
type slowReader struct{ welcome chan string }

func (c *slowReader) OnOpen(*gws.Conn)         {}
func (c *slowReader) OnClose(*gws.Conn, error) {}
func (c *slowReader) OnPing(*gws.Conn, []byte) {}
func (c *slowReader) OnPong(*gws.Conn, []byte) {}
func (c *slowReader) OnMessage(_ *gws.Conn, m *gws.Message) {
	select {
	case c.welcome <- m.Data.String():
	default:
	}
	_ = m.Close()
	time.Sleep(500 * time.Millisecond)
}

func TestSlowReaderBacklogIsCapped(t *testing.T) {
	h := &relay{reg: &registry{rooms: map[string]*room{}, cfg: config{seats: 2}}, silence: time.Minute}
	srv := httptest.NewServer(newServer(h).Handler)
	defer srv.Close()
	sr := &slowReader{welcome: make(chan string, 1)}
	a, _, err := gws.NewClient(sr, &gws.ClientOption{Addr: "ws" + strings.TrimPrefix(srv.URL, "http") + "/ws", NewDialer: smallWindow})
	if err != nil {
		t.Fatal(err)
	}
	go a.ReadLoop()
	say(t, a, `{"type":"hello","protocol":2,"build":"x","match":"","settings":{}}`)
	w := <-sr.welcome
	b, bc := dial(t, srv.URL)
	say(t, b, `{"type":"hello","protocol":2,"build":"x","match":"`+w[strings.Index(w, `"match":"`)+9:len(w)-2]+`"}`)
	hear(t, bc)
	hear(t, bc)
	pad := strings.Repeat("x", 60000)
	for i := 4; i < 2004; i++ {
		say(t, b, `{"type":"tick","seat":2,"tick":`+strconv.Itoa(i)+`,"commands":["`+pad+`"]}`)
	}
	runtime.GC()
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	if m.HeapAlloc > 32<<20 {
		t.Fatalf("heap %d MB after 120 MB sent to a slow reader; the write queue is not capped", m.HeapAlloc>>20)
	}
	select {
	case s := <-bc.ch:
		if !strings.Contains(s, `"left"`) {
			t.Fatalf("want left, got %.80s", s)
		}
	case <-time.After(3 * time.Second):
		t.Fatal("no left within 3 s; the slow reader was not cut off")
	}
}

// smallWindow pins the receive buffer so kernel autotuning cannot absorb the relay's backlog.
func smallWindow() (gws.Dialer, error) {
	return &net.Dialer{Control: func(_, _ string, c syscall.RawConn) error {
		return c.Control(func(fd uintptr) { _ = syscall.SetsockoptInt(int(fd), syscall.SOL_SOCKET, syscall.SO_RCVBUF, 32<<10) })
	}}, nil
}
