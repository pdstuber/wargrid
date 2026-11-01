# Movement — M1 prototype

**Reference status: `UNVERIFIED_REFERENCE`.** Rules below are adopted Wargrid prototype choices from [M1 plan](../superpowers/plans/2026-11-01-m1-vehicle.md), not Zero Hour measurements. No EA source, retail data or assets used for this implementation.

World uses square unit cells; projection is presentation only. Static four-way A* on a bounded grid supplies cell centers and exact final target. Retargets first return toward current cell center so paths cannot cut blocked corners. Final replacement order gets one tick budget; accepted unreachable targets become persistently blocked and can recover on a later order. Invalid targets preserve active orders and sequence state. Snapshots include independent map, route and status data.

See plan for exact dimensions, projection, speed, tick phases and tolerance. [Verification](m1-verification.md) records internal correctness separately from reference fidelity.

Point-sized units have no footprint clearance, unit collision, dynamic blockers or group destination allocation. Four-way zigzags are provisional. Drawing shows current tick without interpolation; fractional zoom is not a promise of finished pixel alignment. These limits fit one vehicle; revisit for M2 and observed playtest needs.

No original-game speed, route shape, clearance, acceleration, turn rate or blocked-order behavior has been measured. No original bug is claimed fixed. Future observations need game version/mod/config provenance and matched route/arrival scenarios before enabling parity assertions.

Pending visible questions: motion smoothness at current tick rate, zigzag feel, selection/target legibility, camera/input alignment at each zoom and after resize. Headless checks do not answer these questions.
