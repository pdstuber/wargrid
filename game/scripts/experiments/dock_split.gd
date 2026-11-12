extends RefCounted

# Dock model "split": a stand keeps its length, but only box ticks per load and work ticks per unload hold the lock; the lead ticks before them do not.
# Outside scripts/simulation so the faction-literal guard stays untouched by experiment data.
const SPLIT := {
	"frc_builder": {"source": {"lead": 40, "box": 22}, "depot": {"lead": 6, "work": 39}},
	"china_collector": {"source": {"lead": 5, "box": 37}, "depot": {"lead": 0, "work": 37}},
	"usa_collector": {"source": {"lead": 45, "box": 38}, "depot": {"lead": 60, "work": 153}},
}
