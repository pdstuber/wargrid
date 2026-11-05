package main

import (
	"encoding/json"
	"os"
	"path/filepath"
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
	}
	for in, want := range cases {
		if (parseEnvelope([]byte(in)) != nil) != want {
			t.Errorf("%s: want valid=%v", in, want)
		}
	}
	if e := parseEnvelope([]byte(`{"type":"ping","t":9007199254740993}`)); e.t != "9007199254740993" {
		t.Errorf("echo %q", e.t)
	}
}
