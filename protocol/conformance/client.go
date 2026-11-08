package main

import (
	"context"
	"errors"
	"fmt"
	"regexp"
	"time"

	"github.com/coder/websocket"
)

type client struct {
	c    *websocket.Conn
	in   chan string
	done chan error
}

func dial(url string) (*client, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	c, _, err := websocket.Dial(ctx, url, nil)
	if err != nil {
		return nil, err
	}
	c.SetReadLimit(4 << 20)
	cl := &client{c: c, in: make(chan string, 4096), done: make(chan error, 1)}
	go func() {
		for {
			_, b, err := c.Read(context.Background())
			if err != nil {
				close(cl.in)
				cl.done <- err
				return
			}
			cl.in <- string(b)
		}
	}()
	return cl, nil
}

func (cl *client) say(s string) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	return cl.c.Write(ctx, websocket.MessageText, []byte(s))
}

var errClosed = errors.New("closed")

func (cl *client) hear(timeout time.Duration) (string, error) {
	select {
	case s, ok := <-cl.in:
		if !ok {
			return "", errClosed
		}
		return s, nil
	case <-time.After(timeout):
		return "", fmt.Errorf("timeout after %v", timeout)
	}
}

func (cl *client) sayBinary(b []byte) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	return cl.c.Write(ctx, websocket.MessageBinary, b)
}

func (cl *client) close() { _ = cl.c.Close(websocket.StatusNormalClosure, "") }

var codeRe = regexp.MustCompile(`"match":"([A-Z0-9]{6})"`)

func codeOf(welcome string) string {
	m := codeRe.FindStringSubmatch(welcome)
	if m == nil {
		return ""
	}
	return m[1]
}

func hello(match, build string, protocol int) string {
	if match == "" {
		return helloSettings(match, build, protocol, "{}")
	}
	return fmt.Sprintf(`{"type":"hello","protocol":%d,"build":"%s","match":"%s"}`, protocol, build, match)
}

func helloSettings(match, build string, protocol int, settings string) string {
	return fmt.Sprintf(`{"type":"hello","protocol":%d,"build":"%s","match":"%s","settings":%s}`, protocol, build, match, settings)
}

func tick(seat, t int, pad string) string {
	return fmt.Sprintf(`{"type":"tick","seat":%d,"tick":%d,"commands":[%s]}`, seat, t, pad)
}
