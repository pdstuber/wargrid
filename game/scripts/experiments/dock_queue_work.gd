extends RefCounted

# Dock model "queue": ticks spent working inside the dock (per box at a pile, per unload at a depot), excluding the moves in and out.
# Outside scripts/simulation so the faction-literal guard stays untouched by experiment data.
const QUEUE_WORK := {
	"frc_builder": {"source_box": 32, "depot": 35},
	"china_collector": {"source_box": 32, "depot": 29},
	"usa_collector": {"source_box": 43, "depot": 208},
}
