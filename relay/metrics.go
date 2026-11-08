package main

import (
	"log/slog"
	"net/http"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

const metricsPrefix = "wargrid_relay_"

var (
	mSeats          = promauto.NewGauge(prometheus.GaugeOpts{Name: metricsPrefix + "seats", Help: "Seats currently held in rooms."})
	mDraining       = promauto.NewGauge(prometheus.GaugeOpts{Name: metricsPrefix + "draining", Help: "1 while the relay drains before shutdown."})
	mConnOpened     = promauto.NewCounter(prometheus.CounterOpts{Name: metricsPrefix + "connections_opened_total", Help: "WebSocket connections opened."})
	mConnClosed     = promauto.NewCounter(prometheus.CounterOpts{Name: metricsPrefix + "connections_closed_total", Help: "WebSocket connections closed."})
	mJoins          = promauto.NewCounterVec(prometheus.CounterOpts{Name: metricsPrefix + "joins_total", Help: "Hello messages by result."}, []string{"result"})
	mRoomsCreated   = promauto.NewCounter(prometheus.CounterOpts{Name: metricsPrefix + "rooms_created_total", Help: "Rooms created."})
	mMatchesStarted = promauto.NewCounter(prometheus.CounterOpts{Name: metricsPrefix + "matches_started_total", Help: "Rooms whose seats all filled."})
	mMatchesEnded   = promauto.NewCounter(prometheus.CounterOpts{Name: metricsPrefix + "matches_ended_total", Help: "Started matches whose last seat left."})
	mRoomCrashes    = promauto.NewCounter(prometheus.CounterOpts{Name: metricsPrefix + "room_crashes_total", Help: "Rooms ended by a panic."})
	mFrames         = promauto.NewCounter(prometheus.CounterOpts{Name: metricsPrefix + "frames_total", Help: "Tick frames received and forwarded."})
	mFrameBytes     = promauto.NewCounter(prometheus.CounterOpts{Name: metricsPrefix + "frame_bytes_total", Help: "Bytes of forwarded tick frames, counted once per frame."})
	mRejected       = promauto.NewCounter(prometheus.CounterOpts{Name: metricsPrefix + "messages_rejected_total", Help: "Messages that got a connection rejected."})
	mMatchDuration  = promauto.NewHistogram(prometheus.HistogramOpts{Name: metricsPrefix + "match_duration_seconds", Help: "Time from match start to its last seat leaving.", Buckets: []float64{60, 120, 300, 600, 900, 1200, 1800, 2700, 3600}})
)

func registerRooms(reg *registry) {
	promauto.NewGaugeFunc(prometheus.GaugeOpts{Name: metricsPrefix + "rooms", Help: "Rooms open, lobbies included."}, func() float64 { return float64(reg.count()) })
}

// serveMetrics never stops the relay: games matter more than numbers.
func serveMetrics(addr string) {
	mux := http.NewServeMux()
	mux.Handle("GET /metrics", promhttp.Handler())
	srv := &http.Server{Addr: addr, Handler: mux, ReadHeaderTimeout: 10 * time.Second}
	if err := srv.ListenAndServe(); err != nil {
		slog.Warn("metrics server stopped", "addr", addr, "err", err)
	}
}
