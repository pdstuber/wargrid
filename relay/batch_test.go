package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/lxzan/gws"
)

type cl struct{ ch chan string }

func (c *cl) OnOpen(*gws.Conn)                      {}
func (c *cl) OnClose(*gws.Conn, error)              {}
func (c *cl) OnPing(*gws.Conn, []byte)              {}
func (c *cl) OnPong(*gws.Conn, []byte)              {}
func (c *cl) OnMessage(_ *gws.Conn, m *gws.Message) { c.ch <- m.Data.String(); _ = m.Close() }

func dial(t *testing.T, base string) (*gws.Conn, *cl) {
	c := &cl{make(chan string, 50)}
	s, _, err := gws.NewClient(c, &gws.ClientOption{Addr: "ws" + strings.TrimPrefix(base, "http") + "/ws"})
	if err != nil {
		t.Fatal(err)
	}
	go s.ReadLoop()
	return s, c
}

func say(t *testing.T, s *gws.Conn, text string) {
	t.Helper()
	if err := s.WriteString(text); err != nil {
		t.Fatal(err)
	}
}

func hear(t *testing.T, c *cl) string {
	select {
	case s := <-c.ch:
		return s
	case <-time.After(2 * time.Second):
		t.Fatal("timeout")
		return ""
	}
}

func TestBatchJoinsTicks(t *testing.T) {
	h := &relay{reg: &registry{rooms: map[string]*room{}, cfg: config{seats: 2, batch: 200 * time.Millisecond}}, silence: 5 * time.Second}
	up := gws.NewUpgrader(h, &gws.ServerOption{ReadMaxPayloadSize: 1 << 20, CheckUtf8Enabled: true})
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if s, err := up.Upgrade(w, r); err == nil {
			go s.ReadLoop()
		}
	}))
	defer srv.Close()
	a, ac := dial(t, srv.URL)
	say(t, a, `{"type":"hello","protocol":2,"build":"x","match":"","settings":{}}`)
	w := hear(t, ac)
	b, bc := dial(t, srv.URL)
	say(t, b, `{"type":"hello","protocol":2,"build":"x","match":"`+w[strings.Index(w, `"match":"`)+9:len(w)-2]+`"}`)
	hear(t, bc)
	hear(t, bc)
	hear(t, ac)
	f1, f2 := `{"type":"tick","seat":1,"tick":4,"commands":[]}`, `{"type":"tick","seat":1,"tick":5,"commands":[]}`
	say(t, a, f1)
	say(t, a, f2)
	if s := hear(t, bc); s != f1+"\n"+f2 {
		t.Fatalf("got %q", s)
	}
}
