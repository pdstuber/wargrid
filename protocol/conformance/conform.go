package main

import (
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

const wait = 3 * time.Second

// silence is the relay's silence timeout (WARGRID_SILENCE_MS); set by -silence.
var silence = 10 * time.Second

type failure struct{ msg string }

func check(cond bool, format string, args ...any) {
	if !cond {
		panic(failure{fmt.Sprintf(format, args...)})
	}
}

func must[T any](v T, err error) T {
	check(err == nil, "unexpected error: %v", err)
	return v
}

func expect(cl *client, want string) {
	got, err := cl.hear(wait)
	check(err == nil, "want %q, got error %v", want, err)
	check(got == want, "want %q\n       got  %q", want, got)
}

// expectClosed: the server must close the socket without sending anything else first.
func expectClosed(cl *client) {
	got, err := cl.hear(wait)
	check(err == errClosed, "want close, got %q err %v", got, err)
}

func startMsg(seats int) string {
	ids := make([]string, seats)
	for i := range ids {
		ids[i] = fmt.Sprint(i + 1)
	}
	return fmt.Sprintf(`{"type":"start","seats":[%s],"delay":4}`, strings.Join(ids, ","))
}

// room joins `seats` clients and checks welcome/start bytes; returns clients indexed by seat-1.
func room(url string, seats int, build string) ([]*client, string) {
	first := must(dial(url))
	check(first.say(hello("", build, 1)) == nil, "send")
	w := must(first.hear(wait))
	code := codeOf(w)
	check(code != "" && w == fmt.Sprintf(`{"type":"welcome","seat":1,"match":"%s"}`, code), "bad welcome %q", w)
	cls := []*client{first}
	for s := 2; s <= seats; s++ {
		cl := must(dial(url))
		check(cl.say(hello(code, build, 1)) == nil, "send")
		expect(cl, fmt.Sprintf(`{"type":"welcome","seat":%d,"match":"%s"}`, s, code))
		cls = append(cls, cl)
	}
	for _, cl := range cls {
		expect(cl, startMsg(seats))
	}
	return cls, code
}

func closeAll(cls []*client) {
	for _, c := range cls {
		c.close()
	}
}

const errInvalid = `{"type":"error","reason":"invalid message"}`

func left(seat, after int) string {
	return fmt.Sprintf(`{"type":"left","seat":%d,"after_tick":%d}`, seat, after)
}

// rejectAfterJoin: seat 1 sends text after start, expects error, close, and seat 2 sees left after `after`.
func rejectAfterJoin(url string, text string, after int, before ...string) {
	cls, _ := room(url, 2, "abc")
	defer closeAll(cls)
	for _, b := range before {
		check(cls[0].say(b) == nil, "send")
		expect(cls[1], b)
	}
	check(cls[0].say(text) == nil, "send")
	expect(cls[0], errInvalid)
	expectClosed(cls[0])
	expect(cls[1], left(1, after))
}

type tcase struct {
	name string
	run  func(url string)
}

func defaultCases() []tcase {
	return []tcase{
		{"health", func(url string) {
			h := strings.Replace(strings.Replace(url, "ws://", "http://", 1), "wss://", "https://", 1)
			resp := must(http.Get(strings.TrimSuffix(h, "/ws") + "/health"))
			body := must(io.ReadAll(resp.Body))
			check(resp.StatusCode == 200 && string(body) == "ok", "health %d %q", resp.StatusCode, body)
		}},
		{"create_join_start", func(url string) { cls, _ := room(url, 2, "abc"); closeAll(cls) }},
		{"forwards_byte_for_byte", func(url string) {
			cls, _ := room(url, 2, "abc")
			defer closeAll(cls)
			frame := `{"type":"tick","seat":1,"tick":4,"commands":[{"target":[14.1,0.30000000000000004]}],"hash":{"tick":30,"value":"3a0ad3856b168044"}}`
			cls[0].say(frame)
			cls[0].say(tick(1, 5, ""))
			expect(cls[1], frame)
			expect(cls[1], tick(1, 5, ""))
			cls[1].say(tick(2, 4, `{"x":"ü€"}`))
			expect(cls[0], tick(2, 4, `{"x":"ü€"}`))
		}},
		{"spaced_json_forwarded_verbatim", func(url string) {
			cls, _ := room(url, 2, "abc")
			defer closeAll(cls)
			frame := "{ \"commands\" : [ ] , \"tick\" : 4.0, \"seat\":1, \"type\":\"tick\" }"
			cls[0].say(frame)
			expect(cls[1], frame)
		}},
		{"wrong_seat", func(url string) { rejectAfterJoin(url, tick(2, 4, ""), 3) }},
		{"non_contiguous_tick", func(url string) { rejectAfterJoin(url, tick(1, 6, ""), 4, tick(1, 4, "")) }},
		{"first_tick_before_delay", func(url string) { rejectAfterJoin(url, tick(1, 3, ""), 3) }},
		{"fractional_tick", func(url string) { rejectAfterJoin(url, `{"type":"tick","seat":1,"tick":4.5,"commands":[]}`, 3) }},
		{"string_tick", func(url string) { rejectAfterJoin(url, `{"type":"tick","seat":1,"tick":"4","commands":[]}`, 3) }},
		{"commands_not_array", func(url string) { rejectAfterJoin(url, `{"type":"tick","seat":1,"tick":4,"commands":{}}`, 3) }},
		{"bad_hash_value", func(url string) {
			rejectAfterJoin(url, `{"type":"tick","seat":1,"tick":4,"commands":[],"hash":{"tick":30,"value":"3A0AD3856B168044"}}`, 3)
		}},
		{"hash_not_object", func(url string) { rejectAfterJoin(url, `{"type":"tick","seat":1,"tick":4,"commands":[],"hash":5}`, 3) }},
		{"not_object", func(url string) { rejectAfterJoin(url, `[1,2]`, 3) }},
		{"not_json", func(url string) { rejectAfterJoin(url, `{"type":`, 3) }},
		{"unknown_type", func(url string) { rejectAfterJoin(url, `{"type":"cheat"}`, 3) }},
		{"server_type_from_client", func(url string) { rejectAfterJoin(url, left(1, 3), 3) }},
		{"hello_after_join", func(url string) { rejectAfterJoin(url, hello("", "abc", 1), 3) }},
		{"huge_int_tick", func(url string) { rejectAfterJoin(url, `{"type":"tick","seat":1,"tick":4294967300,"commands":[]}`, 3) }},
		{"ping_before_hello", func(url string) {
			cl := must(dial(url))
			defer cl.close()
			cl.say(`{"type":"ping","t":1}`)
			expect(cl, errInvalid)
			expectClosed(cl)
		}},
		{"tick_before_start", func(url string) {
			cl := must(dial(url))
			defer cl.close()
			cl.say(hello("", "abc", 1))
			must(cl.hear(wait))
			cl.say(tick(1, 4, ""))
			expect(cl, errInvalid)
			expectClosed(cl)
		}},
		{"protocol_and_build_mismatch", func(url string) {
			p := must(dial(url))
			defer p.close()
			p.say(hello("", "abc", 2))
			expect(p, `{"type":"error","reason":"protocol mismatch"}`)
			expectClosed(p)
			a := must(dial(url))
			defer a.close()
			a.say(hello("", "abc", 1))
			code := codeOf(must(a.hear(wait)))
			b := must(dial(url))
			defer b.close()
			b.say(hello(code, "other", 1))
			expect(b, `{"type":"error","reason":"build mismatch"}`)
			expectClosed(b)
			c := must(dial(url))
			defer c.close()
			c.say(hello(code, "abc", 1))
			expect(c, fmt.Sprintf(`{"type":"welcome","seat":2,"match":"%s"}`, code))
		}},
		{"unknown_match", func(url string) {
			cl := must(dial(url))
			defer cl.close()
			cl.say(hello("ZZZZZZ", "abc", 1))
			expect(cl, `{"type":"error","reason":"unknown match"}`)
			expectClosed(cl)
		}},
		{"match_full", func(url string) {
			cls, code := room(url, 2, "abc")
			defer closeAll(cls)
			third := must(dial(url))
			defer third.close()
			third.say(hello(code, "abc", 1))
			expect(third, `{"type":"error","reason":"match full"}`)
			expectClosed(third)
			cls[0].say(tick(1, 4, ""))
			expect(cls[1], tick(1, 4, ""))
		}},
		{"frame_cap_boundary", func(url string) {
			overhead := len(tick(1, 4, `""`))
			exact := tick(1, 4, `"`+strings.Repeat("x", 65536-overhead)+`"`)
			check(len(exact) == 65536, "len %d", len(exact))
			over := tick(1, 5, `"`+strings.Repeat("x", 65537-overhead)+`"`)
			rejectAfterJoin(url, over, 4, exact)
		}},
		{"multibyte_counts_bytes", func(url string) {
			overhead := len(tick(1, 4, `""`))
			// 65535-overhead ASCII + one 2-byte char = 65537 bytes but fewer runes
			over := tick(1, 4, `"`+strings.Repeat("x", 65535-overhead)+"ü"+`"`)
			check(len(over) == 65537, "len %d", len(over))
			rejectAfterJoin(url, over, 3)
		}},
		{"close_announces_left_with_last_tick", func(url string) {
			cls, _ := room(url, 2, "abc")
			defer closeAll(cls)
			cls[1].say(tick(2, 4, ""))
			cls[1].say(tick(2, 5, ""))
			expect(cls[0], tick(2, 4, ""))
			expect(cls[0], tick(2, 5, ""))
			cls[1].close()
			expect(cls[0], left(2, 5))
			cls[0].say(`{"type":"ping","t":1}`)
			expect(cls[0], `{"type":"pong","t":1}`)
			cls[0].say(tick(1, 4, ""))
			cls[0].say(`{"type":"ping","t":2}`)
			expect(cls[0], `{"type":"pong","t":2}`)
		}},
		{"binary_frame_ends_connection", func(url string) {
			cls, _ := room(url, 2, "abc")
			defer closeAll(cls)
			cls[0].sayBinary([]byte(tick(1, 4, "")))
			expectClosed(cls[0])
			expect(cls[1], left(1, 3))
		}},
		{"ping_pong", func(url string) {
			cl := must(dial(url))
			defer cl.close()
			cl.say(hello("", "abc", 1))
			must(cl.hear(wait))
			cl.say(`{"type":"ping","t":123}`)
			expect(cl, `{"type":"pong","t":123}`)
			cl.say(`{"type":"ping","t":1730000000123}`)
			expect(cl, `{"type":"pong","t":1730000000123}`)
			cl.say(`{"type":"ping","t":"x"}`)
			expect(cl, errInvalid)
		}},
		{"room_code_freed_after_empty", func(url string) {
			cls, code := room(url, 2, "abc")
			closeAll(cls)
			time.Sleep(300 * time.Millisecond)
			cl := must(dial(url))
			defer cl.close()
			cl.say(hello(code, "abc", 1))
			expect(cl, `{"type":"error","reason":"unknown match"}`)
		}},
		{"started_room_stays_full_after_leave", func(url string) {
			cls, code := room(url, 2, "abc")
			defer closeAll(cls)
			cls[1].close()
			expect(cls[0], left(2, 3))
			cl := must(dial(url))
			defer cl.close()
			cl.say(hello(code, "abc", 1))
			expect(cl, `{"type":"error","reason":"match full"}`)
		}},
	}
}

func silenceCases() []tcase {
	return []tcase{{"silence_announces_left", func(url string) {
		cls, _ := room(url, 2, "abc")
		defer closeAll(cls)
		// seat 2 keeps pinging past the server's silence timeout; seat 1 stays silent
		for i := 0; time.Duration(i)*100*time.Millisecond < silence+500*time.Millisecond; i++ {
			cls[1].say(fmt.Sprintf(`{"type":"ping","t":%d}`, i))
			time.Sleep(100 * time.Millisecond)
		}
		var got []string
		for {
			s, err := cls[1].hear(200 * time.Millisecond)
			if err != nil {
				break
			}
			got = append(got, s)
		}
		found := false
		for _, s := range got {
			found = found || s == left(1, 3)
		}
		check(found, "no left in %v", got)
		expectClosed(cls[0])
	}}}
}

func delayCases() []tcase {
	return []tcase{{"test_delay_keeps_order_and_holds_left", func(url string) {
		cls, _ := room(url, 2, "abc")
		defer closeAll(cls)
		start := time.Now()
		cls[0].say(tick(1, 4, ""))
		cls[0].say(tick(1, 5, ""))
		expect(cls[1], tick(1, 4, ""))
		check(time.Since(start) >= 240*time.Millisecond, "tick arrived after %v", time.Since(start))
		cls[0].say(tick(1, 6, ""))
		time.Sleep(20 * time.Millisecond)
		cls[0].close()
		expect(cls[1], tick(1, 5, ""))
		expect(cls[1], tick(1, 6, ""))
		expect(cls[1], left(1, 6))
	}}, {"pong_not_delayed", func(url string) {
		cls, _ := room(url, 2, "abc")
		defer closeAll(cls)
		start := time.Now()
		cls[0].say(`{"type":"ping","t":7}`)
		expect(cls[0], `{"type":"pong","t":7}`)
		check(time.Since(start) < 200*time.Millisecond, "pong took %v", time.Since(start))
	}}}
}

func runConform(url, profile string) int {
	cases := map[string][]tcase{"default": defaultCases(), "silence": silenceCases(), "delay": delayCases()}[profile]
	if len(cases) == 0 {
		fmt.Println("unknown profile", profile)
		return 2
	}
	failed := 0
	for _, c := range cases {
		err := func() (err error) {
			defer func() {
				if r := recover(); r != nil {
					if f, ok := r.(failure); ok {
						err = fmt.Errorf("%s", f.msg)
					} else {
						err = fmt.Errorf("panic: %v", r)
					}
				}
			}()
			c.run(url)
			return nil
		}()
		if err != nil {
			failed++
			fmt.Printf("FAIL %s: %v\n", c.name, err)
		} else {
			fmt.Printf("ok   %s\n", c.name)
		}
	}
	fmt.Printf("CONFORM %s: %d cases, %d failed\n", profile, len(cases), failed)
	if failed > 0 {
		return 1
	}
	return 0
}
