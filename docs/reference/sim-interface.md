# Simulation interface

Status: describes the code at 874c6a3 (2026-11-10). Update in the same change as any public method. Paths relative to `game/scripts/simulation/`; `sim` is a `Simulation` (`simulation.gd`).

## Construct and set up (before tick 0)
- `Simulation.new(blocked_cells, size)`: empty world. `simulation.gd:52`
- `MapData.create(map, seats) -> Simulation`: map, players, start units and supply sources in one call; the normal entry. `map_data.gd:55`
- `Skirmish.create(with_match, second_controller, factions, map_path, starts) -> Simulation`: standard two-seat game on top of `MapData.create`. `skirmish.gd:47`
- `add_player(player, credits, controller, team) -> Dictionary`: register a seat. `simulation.gd:68`
- `spawn(owner, position, kind, occupied) -> int`: add a unit, -1 if blocked. `simulation.gd:78`
- `add_supply_source(origin, boxes, footprint, delete_when_empty) -> int`. `simulation.gd:826`
- `replace_blocked_cells(cells) -> Dictionary`: terrain edit (map editor, tests). `simulation.gd:652`
- `remove_object(id) -> Dictionary`: delete a unit or building. Outside callers are tests and `scripts/debug/combat_workload.gd`; not a command, so never use it in a networked match. `simulation.gd:744`
- `start_match(players) -> Dictionary` / `begin_setup(players)`: begin the match (`ongoing`, or `setup` until every seat has chosen a faction). Only `Skirmish.create` calls `begin_setup`; `setup_seat(player, faction)` (`simulation.gd:119`) is called from `MapData.create` and the `choose_faction` command, never from outside the folder. `simulation.gd:100, 103`

## Commands in
- `issue_command(command) -> {ok, error}`: queue a command for its `tick`. `simulation.gd:154`
- Common fields: `tick`, `player`, `sequence` (ints; sequence must increase per player), `type`. Payload fields per type (`_payload_fields`, `simulation.gd:168`):

| type | fields |
|---|---|
| move, attack_move | entity_ids, target |
| stop | entity_ids |
| gather | entity_ids, source_id |
| attack, enter | entity_ids, target_id |
| unload | target_id |
| build | builder_id, building_kind, origin |
| resume_build | builder_id, building_id |
| cancel_build | building_id |
| produce | building_id, unit_kind |
| cancel_production | building_id, production_id |
| set_rally | building_id, target |
| defence_attack | building_id, target_id |
| choose_faction | faction |

- After setup a command is the only way to change the game. Same-tick order is `tick`, `player`, `sequence` (`_command_before`, `simulation.gd:308`).

## Advance
- `step() -> void`: run one tick. `simulation.gd:502`
- `tick() -> int`: current tick. `simulation.gd:488`
- `match_over() -> bool`. `simulation.gd:151`
- Lockstep drives these through `advance(sim)` and `finish_tick(tick, state)`. `net/lockstep.gd:88, 111`

## State out
- `snapshot() -> Dictionary`: `simulation.gd:628`. Keys: `tick`, `next_entity_id`, `entities` (sorted by id), `pending_commands` (sorted), `last_sequences`, `map`, `path_queue`, `players`, `buildings`, `sources`, `terrain_cells`, `next_production_id`, `command_results`, `combat_events`, `match`, `rng`, and `crates` when any exist. Copies, except `entities[].route`, `map` and `terrain_cells`: those are shared read-only arrays (`simulation.gd:592-596`, `grid_navigation.gd:129-137`, `simulation.gd:723-733`), so duplicate them before mutating.
- `StateHash.digest(snapshot) -> String`: the only state fingerprint. `state_hash.gd:10`

## Events out
- `combat_events() -> Array[Dictionary]`, `command_results() -> Array[Dictionary]`: events of the last step. Live read-only views, cleared in place by the next step: copy to keep. Both also appear in the snapshot. `simulation.gd:492, 496`

## Read-only queries
- `map_data() -> Dictionary`. `simulation.gd:65`
- `preview_build(player, builder_id, kind, origin) -> Dictionary`: placement check for the HUD. `simulation.gd:739`
- `team_of(player) -> int`. `simulation.gd:75`
- `occupied_cells() -> Dictionary`: called only inside the folder (`containers.gd`, `production.gd`); `spawn` uses it. `simulation.gd:92`

## Not interface
- Every `_`-prefixed member. Known leaks: `scripts/debug/combat_workload.gd` and `movement_workload.gd` read and write sim privates (`_entities`, `_buildings`, `_pending`, `_next_entity_id`, `_replace_union`), and `scripts/net/headless_client.gd:171` writes `_sim._players`.
- Diagnostic counters, not interface (benchmarks and tests only): `combat_work`, `horde_checks`, `scan_chases`, `retaliations`, `navigation_builds`, `navigation_local_updates`, `allocation_calls`. `simulation.gd:470-499`
- `next_random()`: sim-internal RNG step (`simulation.gd:57`). Called by `combat.gd`, `salvage.gd`, `horde.gd` inside the folder; the one outside caller is `tests/test_combat.gd:1183`.

## Rule for tests (user, 2026-11-09)
New tests set up, command and check the game only through the sections above, plus static unit data from `definitions/`. Existing files that read `sim._x` are grandfathered in the allowlist of `tools/test_sim_boundary.py` and migrated only when touched for another reason. Why: a native or repacked core can then run the same tests.
