package main

import (
	"bytes"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/testutil"
	dto "github.com/prometheus/client_model/go"
)

// delta reads a metric now and returns a func that reports how much it moved since.
func delta(c prometheus.Collector) func() float64 {
	before := testutil.ToFloat64(c)
	return func() float64 { return testutil.ToFloat64(c) - before }
}

func durationSamples() uint64 {
	var m dto.Metric
	_ = mMatchDuration.Write(&m)
	return m.GetHistogram().GetSampleCount()
}

func TestJoinResultsAreCounted(t *testing.T) {
	g := newRegistry(config{seats: 2})
	results := []string{"ok", "build mismatch", "unknown match", "protocol mismatch", "match full"}
	deltas := map[string]func() float64{}
	for _, r := range results {
		deltas[r] = delta(mJoins.WithLabelValues(r))
	}
	a, _ := seated(t, g, "", nop)
	g.join(&envelope{protocol: protocol, build: "other", match: a.room.code}, &conn{sender: sender{write: nop, shut: func() {}}})
	g.join(&envelope{protocol: protocol, build: "b", match: "NOPE00"}, &conn{sender: sender{write: nop, shut: func() {}}})
	g.join(&envelope{protocol: protocol + 1, build: "b", match: ""}, &conn{sender: sender{write: nop, shut: func() {}}})
	seated(t, g, a.room.code, nop)
	g.join(&envelope{protocol: protocol, build: "b", match: a.room.code}, &conn{sender: sender{write: nop, shut: func() {}}})
	for _, r := range results {
		want := 1.0
		if r == "ok" {
			want = 2
		}
		if got := deltas[r](); got != want {
			t.Errorf("joins %q moved by %v, want %v", r, got, want)
		}
	}
}

func TestMatchLifecycleIsCounted(t *testing.T) {
	g := newRegistry(config{seats: 2})
	started, ended, created, seats := delta(mMatchesStarted), delta(mMatchesEnded), delta(mRoomsCreated), delta(mSeats)
	samples := durationSamples()
	a, _ := seated(t, g, "", nop)
	b, _ := seated(t, g, a.room.code, nop)
	if started() != 1 || created() != 1 || seats() != 2 {
		t.Fatalf("after start: started %v created %v seats %v", started(), created(), seats())
	}
	a.room.post(leaveMsg{a.seat})
	b.room.post(leaveMsg{b.seat})
	eventually(t, "room not removed", func() bool { return g.count() == 0 })
	if ended() != 1 || seats() != 0 || durationSamples() != samples+1 {
		t.Fatalf("after end: ended %v seats %v duration samples +%d", ended(), seats(), durationSamples()-samples)
	}
}

func TestLobbyThatNeverStartedIsNoMatch(t *testing.T) {
	g := newRegistry(config{seats: 2})
	ended, seats := delta(mMatchesEnded), delta(mSeats)
	samples := durationSamples()
	a, _ := seated(t, g, "", nop)
	a.room.post(leaveMsg{a.seat})
	eventually(t, "lobby not removed", func() bool { return g.count() == 0 })
	if ended() != 0 || seats() != 0 || durationSamples() != samples {
		t.Fatalf("lobby: ended %v seats %v duration samples +%d", ended(), seats(), durationSamples()-samples)
	}
}

func TestRoomCrashRestoresGauges(t *testing.T) {
	g := newRegistry(config{seats: 2})
	crashes, seats := delta(mRoomCrashes), delta(mSeats)
	boom := func(f []byte) {
		if bytes.Contains(f, []byte(`"tick"`)) {
			panic("boom")
		}
	}
	a, _ := seated(t, g, "", nop)
	seated(t, g, a.room.code, boom)
	a.room.post(tickMsg{a.seat, 1, inputDelay, []byte(`{"type":"tick"}`)})
	<-a.room.done
	if crashes() != 1 || seats() != 0 {
		t.Fatalf("crash: crashes %v seats %v", crashes(), seats())
	}
}

func TestFramesAndRejectsAreCounted(t *testing.T) {
	g := newRegistry(config{seats: 2})
	frames, frameBytes, rejected := delta(mFrames), delta(mFrameBytes), delta(mRejected)
	a, _ := seated(t, g, "", nop)
	seated(t, g, a.room.code, nop)
	frame := []byte(`{"type":"tick","seat":1,"tick":4}`)
	a.room.post(tickMsg{a.seat, 1, inputDelay, frame})
	eventually(t, "frame not counted", func() bool { return frames() == 1 })
	if frameBytes() != float64(len(frame)) {
		t.Fatalf("frame bytes %v, want %d", frameBytes(), len(frame))
	}
	a.room.post(tickMsg{a.seat, 1, inputDelay + 5, frame})
	eventually(t, "out-of-order tick not counted as rejected", func() bool { return rejected() == 1 })
}

func TestConnectionsAreCounted(t *testing.T) {
	opened, closed := delta(mConnOpened), delta(mConnClosed)
	srv := httptest.NewServer(newServer(&relay{reg: newRegistry(config{seats: 2}), silence: 5 * time.Second}).Handler)
	defer srv.Close()
	s, _ := dial(t, srv.URL)
	eventually(t, "open not counted", func() bool { return opened() == 1 })
	_ = s.WriteClose(1000, nil)
	eventually(t, "close not counted", func() bool { return closed() == 1 })
}

func freeAddr(t *testing.T) string {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	addr := ln.Addr().String()
	_ = ln.Close()
	return addr
}

func TestMetricsEndpoint(t *testing.T) {
	addr := freeAddr(t)
	go serveMetrics(addr)
	var body string
	eventually(t, "metrics endpoint not serving", func() bool {
		res, err := http.Get(fmt.Sprintf("http://%s/metrics", addr)) //nolint:noctx // test against a local server
		if err != nil {
			return false
		}
		defer res.Body.Close()
		b, _ := io.ReadAll(res.Body)
		body = string(b)
		return res.StatusCode == http.StatusOK
	})
	for _, name := range []string{"wargrid_relay_seats", "go_goroutines"} {
		if !strings.Contains(body, name) {
			t.Errorf("metrics body lacks %s", name)
		}
	}
}

func TestMetricsBindFailureKeepsRunning(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	done := make(chan struct{})
	go func() { serveMetrics(ln.Addr().String()); close(done) }()
	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("serveMetrics did not return on a taken port")
	}
}
