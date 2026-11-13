@warning_ignore_start("untyped_declaration")
extends RefCounted

const Runner = preload("res://tests/run_tests.gd")

func cases() -> Array[Callable]:
	return [test_shards_cover_every_suite_once, test_no_shard_runs_everything, test_bad_shard_runs_nothing, test_only_filter, test_shards_by_cost]

func test_shards_cover_every_suite_once(runner) -> bool:
	var seen: Array[int] = []
	for i in range(4):
		seen.append_array(Runner.shard(34, PackedStringArray(["--shard=%d/4" % i])))
	seen.sort()
	runner.check(seen == Array(range(34), TYPE_INT, "", null), "R1 four shards run each of 34 cases exactly once")
	return true

func test_no_shard_runs_everything(runner) -> bool:
	runner.check(Runner.shard(5, PackedStringArray()) == [0, 1, 2, 3, 4], "R2 no shard arg runs every case")
	return true

func test_bad_shard_runs_nothing(runner) -> bool:
	runner.check(Runner.shard(5, PackedStringArray(["--shard=2/2"])).is_empty(), "R3 index past count runs nothing")
	runner.check(Runner.shard(5, PackedStringArray(["--shard=0/0"])).is_empty(), "R3 zero shards runs nothing")
	runner.check(Runner.shard(5, PackedStringArray(["--shard=x"])).is_empty(), "R3 malformed shard runs nothing")
	return true

func test_only_filter(runner) -> bool:
	runner.check(Runner.only_filter(PackedStringArray(["--shard=0/4", "--only=test_supply"])) == "test_supply", "R4 --only picks the filter text")
	runner.check(Runner.only_filter(PackedStringArray(["--shard=0/4"])).is_empty(), "R4 no --only means no filter")
	return true

func test_shards_by_cost(runner) -> bool:
	var costs := PackedFloat64Array([5.0, 1, 1, 1, 1, 1])
	runner.check(Runner.shard(6, PackedStringArray(["--shard=0/2"]), costs) == [0], "R5 the slow case gets a process to itself")
	runner.check(Runner.shard(6, PackedStringArray(["--shard=1/2"]), costs) == [1, 2, 3, 4, 5], "R5 the rest share the other process")
	var equal := PackedFloat64Array([1.0, 1, 1, 1, 1])
	runner.check(Runner.shard(5, PackedStringArray(["--shard=0/2"]), equal) == [0, 2, 4], "R5 equal costs keep the modulo deal, shard 0")
	runner.check(Runner.shard(5, PackedStringArray(["--shard=1/2"]), equal) == [1, 3], "R5 equal costs keep the modulo deal, shard 1")
	return true
