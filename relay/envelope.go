package main

import (
	"bytes"
	"encoding/json"
	"io"
	"math"
	"regexp"
)

const (
	maxMessageBytes  = 65536
	maxSettingsBytes = 4096
)

var hashRe = regexp.MustCompile(`^[0-9a-f]{16}$`)

type envelope struct {
	typ      string
	seat     int
	tick     int
	protocol int
	build    string
	match    string
	t        string // raw JSON number token, echoed byte-exact
	settings []byte // raw JSON object of a hello, nil when absent
}

func asInt(v any) (int, bool) {
	n, ok := v.(json.Number)
	if !ok {
		return 0, false
	}
	f, err := n.Float64()
	if err != nil || math.IsInf(f, 0) || f != math.Floor(f) || math.Abs(f) > math.MaxInt32 {
		return 0, false
	}
	return int(f), true
}

func asString(v any) (string, bool) { s, ok := v.(string); return s, ok }

func validHash(o map[string]any) bool {
	h, present := o["hash"]
	if !present {
		return true
	}
	m, ok := h.(map[string]any)
	if !ok {
		return false
	}
	_, tickOK := asInt(m["tick"])
	v, strOK := asString(m["value"])
	return tickOK && strOK && hashRe.MatchString(v)
}

// rawSettings returns the exact bytes of the top-level "settings" value (nil when absent) and whether it is a valid one.
func rawSettings(text []byte) ([]byte, bool) {
	var raw map[string]json.RawMessage
	if json.Unmarshal(text, &raw) != nil {
		return nil, false
	}
	v, present := raw["settings"]
	if !present {
		return nil, true
	}
	var obj map[string]json.RawMessage
	return v, len(v) <= maxSettingsBytes && json.Unmarshal(v, &obj) == nil && obj != nil
}

// parseEnvelope returns nil for anything a client may not send.
func parseEnvelope(text []byte) *envelope {
	if len(text) > maxMessageBytes {
		return nil
	}
	dec := json.NewDecoder(bytes.NewReader(text))
	dec.UseNumber()
	var o map[string]any
	if dec.Decode(&o) != nil || o == nil || dec.Decode(new(json.RawMessage)) != io.EOF {
		return nil
	}
	typ, _ := asString(o["type"])
	switch typ {
	case "hello":
		p, ok1 := asInt(o["protocol"])
		b, ok2 := asString(o["build"])
		m, ok3 := asString(o["match"])
		settings, ok4 := rawSettings(text)
		if ok1 && ok2 && ok3 && ok4 {
			return &envelope{typ: typ, protocol: p, build: b, match: m, settings: settings}
		}
	case "tick":
		s, ok1 := asInt(o["seat"])
		t, ok2 := asInt(o["tick"])
		_, ok3 := o["commands"].([]any)
		if ok1 && ok2 && ok3 && validHash(o) {
			return &envelope{typ: typ, seat: s, tick: t}
		}
	case "ping":
		if n, ok := o["t"].(json.Number); ok {
			if _, err := n.Float64(); err == nil {
				return &envelope{typ: typ, t: n.String()}
			}
		}
	}
	return nil
}
