package main

import (
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/lxzan/gws"
)

// stalled reads its first frame (the welcome) and then stops reading, so its TCP receive window fills up.
type stalled struct {
	welcome chan string
	block   chan struct{}
}

func (c *stalled) OnOpen(*gws.Conn)         {}
func (c *stalled) OnClose(*gws.Conn, error) {}
func (c *stalled) OnPing(*gws.Conn, []byte) {}
func (c *stalled) OnPong(*gws.Conn, []byte) {}
func (c *stalled) OnMessage(_ *gws.Conn, m *gws.Message) {
	select {
	case c.welcome <- m.Data.String():
	default:
	}
	<-c.block
}

func TestStalledPeerStillProducesLeft(t *testing.T) {
	h := &relay{reg: &registry{rooms: map[string]*room{}, cfg: config{seats: 2}}, silence: 500 * time.Millisecond}
	up := gws.NewUpgrader(h, &gws.ServerOption{ReadMaxPayloadSize: 1 << 20, CheckUtf8Enabled: true})
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if s, err := up.Upgrade(w, r); err == nil {
			go s.ReadLoop()
		}
	}))
	defer srv.Close()
	st := &stalled{welcome: make(chan string, 1), block: make(chan struct{})}
	defer close(st.block)
	a, _, err := gws.NewClient(st, &gws.ClientOption{Addr: "ws" + strings.TrimPrefix(srv.URL, "http") + "/ws"})
	if err != nil {
		t.Fatal(err)
	}
	go a.ReadLoop()
	say(t, a, `{"type":"hello","protocol":2,"build":"x","match":"","settings":{}}`)
	w := <-st.welcome
	b, bc := dial(t, srv.URL)
	say(t, b, `{"type":"hello","protocol":2,"build":"x","match":"`+w[strings.Index(w, `"match":"`)+9:len(w)-2]+`"}`)
	hear(t, bc)
	hear(t, bc)
	pad := strings.Repeat("x", 60000)
	for i := 4; i < 400; i++ {
		say(t, b, `{"type":"tick","seat":2,"tick":`+strconv.Itoa(i)+`,"commands":["`+pad+`"]}`)
	}
	deadline := time.After(4 * time.Second)
	for {
		select {
		case s := <-bc.ch:
			if strings.Contains(s, `"left"`) {
				return
			}
		case <-deadline:
			t.Fatal("no left within 4 s although seat 1 was silent past the 500 ms timeout")
		case <-time.After(200 * time.Millisecond):
			say(t, b, `{"type":"ping","t":1}`)
		}
	}
}
