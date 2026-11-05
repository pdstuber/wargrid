package main

import (
	"bytes"
	"sync"
	"time"
)

type queued struct {
	frame []byte
	due   time.Time
}

// sender keeps per-socket frame order under the test-delay rule. With no delay configured it is
// a plain gws.WriteAsync; the pending list and timer only exist while delayed frames are in flight.
type sender struct {
	write   func([]byte) // gws.WriteAsync in production
	shut    func()       // ordered after queued writes
	mu      sync.Mutex
	pending []queued
	lastDue time.Time
	timer   *time.Timer
	closing bool
	batch   [][]byte // WARGRID_BATCH_MS mode: ticks waiting for the next flush
}

func (s *sender) send(frame []byte, delay time.Duration) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.flushBatch()
	now := time.Now()
	due := now.Add(delay)
	if due.Before(s.lastDue) {
		due = s.lastDue
	}
	s.lastDue = due
	if len(s.pending) == 0 && !due.After(now) {
		s.write(frame)
		return
	}
	s.pending = append(s.pending, queued{frame, due})
	if len(s.pending) == 1 {
		s.arm(due.Sub(now))
	}
}

func (s *sender) addBatch(frame []byte) {
	s.mu.Lock()
	s.batch = append(s.batch, frame)
	s.mu.Unlock()
}

func (s *sender) flushNow() {
	s.mu.Lock()
	s.flushBatch()
	s.mu.Unlock()
}

// flushBatch writes pending ticks as one newline-joined message; caller holds mu.
func (s *sender) flushBatch() {
	switch len(s.batch) {
	case 0:
		return
	case 1:
		s.write(s.batch[0])
	default:
		s.write(bytes.Join(s.batch, []byte("\n")))
	}
	s.batch = nil
}

// close ends the connection after everything already queued has been written.
func (s *sender) close() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.flushBatch()
	s.closing = true
	if len(s.pending) == 0 {
		s.shut()
	}
}

func (s *sender) arm(d time.Duration) {
	if s.timer == nil {
		s.timer = time.AfterFunc(d, s.flush)
	} else {
		s.timer.Reset(d)
	}
}

func (s *sender) flush() {
	s.mu.Lock()
	defer s.mu.Unlock()
	now := time.Now()
	for len(s.pending) > 0 && !s.pending[0].due.After(now) {
		s.write(s.pending[0].frame)
		s.pending = s.pending[1:]
	}
	if len(s.pending) > 0 {
		s.arm(s.pending[0].due.Sub(now))
	} else if s.closing {
		s.shut()
	}
}
