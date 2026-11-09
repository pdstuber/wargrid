package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestVectors(t *testing.T) {
	files, _ := filepath.Glob("../protocol/vectors/*.json")
	if len(files) == 0 {
		t.Fatal("no vectors")
	}
	for _, f := range files {
		raw, _ := os.ReadFile(f)
		var v struct {
			Text    string
			Valid   *bool
			Message struct{ Type string }
		}
		if err := json.Unmarshal(raw, &v); err != nil {
			t.Fatal(err)
		}
		e := parseEnvelope([]byte(v.Text))
		clientType := map[string]bool{"hello": true, "tick": true, "ping": true}[v.Message.Type]
		want := v.Valid == nil && clientType
		if (e != nil) != want {
			t.Errorf("%s: parsed=%v want=%v", filepath.Base(f), e != nil, want)
		}
	}
}

func TestParseRules(t *testing.T) {
	cases := map[string]bool{
		`{"type":"ping","t":9007199254740993}`:                                                         true,
		`{"type":"ping","t":"1"}`:                                                                      false,
		`{"type":"tick","seat":1,"tick":4.0,"commands":[]}`:                                            true,
		`{"type":"tick","seat":1,"tick":4,"commands":{}}`:                                              false,
		`{"type":"tick","seat":1,"tick":2147483648,"commands":[]}`:                                     false,
		`{"type":"tick","seat":1,"tick":4,"commands":[],"hash":{"tick":1,"value":"3a0ad3856b168044"}}`: true,
		`{"type":"tick","seat":1,"tick":4,"commands":[],"hash":{"tick":1,"value":"XX"}}`:               false,
		`{"type":"hello","protocol":1,"build":"a","match":""} x`:                                       false,
		`{"type":"welcome","seat":1,"match":"ABC234"}`:                                                 false,
		`{"type":"hello","protocol":2,"build":"a","match":"","settings":{ "map" : "x" }}`:              true,
		`{"type":"hello","protocol":2,"build":"a","match":"ABC234"}`:                                   true,
	}
	for in, want := range cases {
		if (parseEnvelope([]byte(in)) != nil) != want {
			t.Errorf("%s: want valid=%v", in, want)
		}
	}
	bad := []string{`"x"`, `[1]`, `null`, `{"k":"` + strings.Repeat("x", 4090) + `"}`}
	for _, p := range []string{"2", "3"} {
		for _, b := range bad {
			e := parseEnvelope([]byte(`{"type":"hello","protocol":` + p + `,"build":"a","match":"","settings":` + b + `}`))
			if e == nil || !e.badSettings {
				t.Errorf("protocol %s settings %.20s: want badSettings, got %v", p, b, e)
			}
		}
	}
	if e := parseEnvelope([]byte(`{"type":"hello","protocol":2,"build":"a","match":"","settings":{}}`)); e == nil || e.badSettings {
		t.Errorf("good settings flagged: %v", e)
	}
	if e := parseEnvelope([]byte(`{"type":"hello","protocol":2,"build":"a","match":"","settings":{ "map" : "x" }}`)); e == nil || string(e.settings) != `{ "map" : "x" }` {
		t.Errorf("settings bytes %v", e)
	}
	if e := parseEnvelope([]byte(`{"type":"ping","t":9007199254740993}`)); e.t != "9007199254740993" {
		t.Errorf("echo %q", e.t)
	}
}

func TestJoinProtocolBeatsSettings(t *testing.T) {
	g := &registry{rooms: map[string]*room{}, cfg: config{seats: 2}}
	conn := func() *conn { return &conn{sender: sender{write: func([]byte) {}, shut: func() {}}} }
	cases := []struct {
		name   string
		e      envelope
		reason string
	}{
		{"protocol 3 bad settings", envelope{protocol: 3, badSettings: true}, "protocol mismatch"},
		{"protocol 3 missing settings", envelope{protocol: 3}, "protocol mismatch"},
		{"protocol 2 bad settings", envelope{protocol: protocol, badSettings: true}, "invalid message"},
		{"protocol 2 bad settings joiner", envelope{protocol: protocol, badSettings: true, match: "ABC234"}, "invalid message"},
		{"protocol 2 missing settings", envelope{protocol: protocol}, "missing settings"},
	}
	for _, c := range cases {
		if got := g.join(&c.e, conn()).reason; got != c.reason {
			t.Errorf("%s: reason %q want %q", c.name, got, c.reason)
		}
	}
}
