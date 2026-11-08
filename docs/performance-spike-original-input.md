> Provenance (user, 2026-11-08): written by another AI without knowledge of this codebase, supplied as an outside perspective. Advisory, not a spec. The refined handoff is `docs/performance-spike-prompt.txt`.

# Wargrid Performance Investigation & Benchmark Recovery

## Context

We have been ignoring failures in our Wargrid performance benchmark gates for some time, particularly the **open, dense, and 3v3 benchmarks**.

I want to address this technical debt and establish a reliable performance baseline again.

The goal is to either:

1. Improve performance sufficiently to pass the existing benchmark gates.
2. Adjust benchmark thresholds where profiling and realistic performance expectations demonstrate that the existing limits are unreasonable.

**Do not simply relax thresholds to make the tests pass.** Any adjustments must be supported by measurements and a clear explanation.

## Objectives

### 1. Establish the Current Baseline

- Identify all relevant performance benchmarks and their configured pass/fail thresholds.
- Run the benchmarks and document the current results.
- Determine how far each benchmark is from passing.
- Investigate when and why performance may have regressed, where feasible.
- Profile the relevant workloads to identify the primary CPU, memory, and simulation bottlenecks.
- Distinguish between average performance, worst-case performance, and performance variability.

Use representative workloads and repeat measurements to avoid drawing conclusions from noisy results.

### 2. Evaluate GDScript Static Typing

Investigate whether converting dynamically typed GDScript to statically typed GDScript could meaningfully improve performance.

Specifically:

- Identify performance-critical code paths that currently use dynamic typing.
- Measure the performance difference between dynamic and static typing in representative workloads.
- Evaluate whether converting the entire codebase would be beneficial, or whether selective conversion of hot paths is sufficient.
- Consider maintainability, development complexity, and potential limitations.

Do not perform a wholesale migration without evidence that it provides worthwhile benefits.

### 3. Evaluate C++ via GDExtension

Investigate whether moving selected performance-critical systems from GDScript to C++ using Godot's GDExtension API would provide meaningful speedups.

Consider potential candidates such as:

- Unit simulation and movement.
- Pathfinding and navigation.
- Spatial queries and collision-related calculations.
- AI decision-making.
- Other CPU-intensive systems identified through profiling.

Evaluate:

- Expected and measured performance improvements.
- Data transfer and GDScript-to-C++ invocation overhead.
- Integration and build complexity.
- Cross-platform implications.
- Maintainability and additional development costs.

Where practical, implement a small, representative proof of concept and benchmark it against the existing GDScript implementation.

Favor targeted native implementations over a wholesale rewrite unless the evidence strongly supports a broader migration.

### 4. Investigate Multithreading

Determine whether we could make better use of modern multicore CPUs.

Analyze which parts of our simulation could safely execute concurrently, including:

- AI calculations.
- Pathfinding and navigation.
- Independent unit or group updates.
- Spatial calculations.
- Other independent or parallelizable workloads.

Consider Godot's thread-safety constraints, synchronization overhead, shared mutable state, and potential effects on simulation determinism.

Evaluate approaches such as worker threads, task-based parallelism, and batching.

The objective is to achieve measurable improvements without introducing race conditions, unpredictable simulation behavior, or excessive architectural complexity.

### 5. Identify Additional Optimization Opportunities

Do not limit the investigation to the technologies mentioned above.

Look for other meaningful optimizations that could help us pass the open, dense, and 3v3 benchmarks, such as:

- Improving algorithmic complexity.
- Reducing unnecessary per-frame processing.
- Eliminating redundant calculations.
- Improving data structures and memory access patterns.
- Reducing allocations and garbage collection overhead.
- Optimizing spatial partitioning and queries.
- Improving update scheduling, batching, and simulation frequency.
- Reducing expensive engine API calls.
- Optimizing AI and pathfinding workloads.

Prioritize optimizations based on measured bottlenecks rather than assumptions.

Pay particular attention to scaling behavior as the number of units, players, and active interactions increases.

## Implementation Strategy

Use an evidence-driven, iterative approach:

1. Establish a reproducible baseline.
2. Identify the largest bottlenecks through profiling.
3. Rank possible improvements by expected impact, implementation effort, complexity, and risk.
4. Implement and benchmark promising optimizations incrementally.
5. Validate that improvements in one benchmark do not cause regressions in others.
6. Repeat until the benchmark gates pass or remaining improvements are no longer cost-effective.

Preserve existing gameplay behavior, correctness, and simulation determinism.

Avoid broad architectural rewrites unless profiling demonstrates that smaller optimizations are insufficient.

## Benchmark Gate Policy

The benchmark gates should remain meaningful indicators of performance quality.

- Prefer performance improvements over threshold adjustments.
- If thresholds are unrealistic, propose revised values supported by measurements.
- Never silently relax or disable a gate.
- Document the rationale for any threshold changes.
- Keep the benchmarks reproducible and representative of real gameplay.
- Avoid changes that optimize benchmark-specific behavior at the expense of actual gameplay.

## Expected Deliverables

Provide:

1. **Baseline report:** Current benchmark results, thresholds, and failure margins.
2. **Bottleneck analysis:** Measured root causes of poor performance.
3. **Technology evaluation:** Findings on static GDScript typing, C++ GDExtension, and multithreading.
4. **Optimization recommendations:** Prioritized by expected benefit, effort, complexity, and risk.
5. **Implemented improvements:** Where feasible, with before/after benchmark results.
6. **Benchmark gate recommendations:** Whether to retain or adjust each threshold, with justification.
7. **Remaining work:** A concrete, prioritized plan for improvements that could not be completed.

## Guiding Principles

- **Measure first, optimize second.**
- Prefer simple, targeted improvements over speculative complexity.
- Optimize for realistic gameplay workloads, not merely benchmark scores.
- Preserve correctness and determinism.
- Treat maintainability as an important constraint.
- Be skeptical of assumptions, including the assumption that C++ or multithreading will automatically improve performance.
- Make the benchmark gates trustworthy again.

**Success means understanding our performance limitations, achieving meaningful improvements, and restoring a benchmark suite whose pass/fail results we can confidently rely on.**