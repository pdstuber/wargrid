@warning_ignore_start("untyped_declaration")
extends RefCounted

const JoinLink = preload("res://scripts/join_link.gd")
const PlaytestSettings = preload("res://scripts/playtest/playtest_settings.gd")
const AudioSettings = preload("res://scripts/presentation/audio_settings.gd")

const BASE := "https://wargrid-web-test.fly.dev/"
const EXP_RELAY := "wss://x.example/ws"
var scratch: String = "user://test-join-link-%d.cfg" % OS.get_process_id()

func cases() -> Array[Callable]:
	return [test_query_parses_like_the_browser, test_code_accepts_only_relay_codes, test_relay_accepts_only_wss, test_code_from_pasted_text, test_link_carries_relay_only_when_not_default, test_prerelease_is_the_dev_suffix]

func test_query_parses_like_the_browser(runner) -> bool:
	runner.check(JoinLink.parse("").is_empty(), "JL1 empty search is {}")
	runner.check(JoinLink.parse("?").is_empty(), "JL1 lone ? is {}")
	var both: Dictionary = JoinLink.parse("?code=ABC234&relay=wss%3A%2F%2Fx.example%2Fws")
	runner.check(both.get("code") == "ABC234", "JL1 code, got %s" % [both])
	runner.check(both.get("relay") == EXP_RELAY, "JL1 relay is decoded, got %s" % [both])
	runner.check(JoinLink.parse("?code=AAA222&code=BBB333").get("code") == "AAA222", "JL1 first duplicate wins")
	var bare: Dictionary = JoinLink.parse("?x=1&code")
	runner.check(bare.get("code") == "" and bare.get("x") == "1", "JL1 key without = is empty, got %s" % [bare])
	runner.check(JoinLink.parse("?code=" + "A".repeat(3000)).is_empty(), "JL1 oversize query is {}")
	return true

func test_code_accepts_only_relay_codes(runner) -> bool:
	runner.check(JoinLink.code("ABC234") == "ABC234", "JL2 valid code")
	runner.check(JoinLink.code("abc234") == "ABC234", "JL2 lower case goes upper")
	for bad: String in ["ABC23", "ABC2345", "ABC0O1", "ABCI34", "<b>A</b>", "ABC 23"]:
		runner.check(JoinLink.code(bad) == "", "JL2 rejects '%s'" % bad)
	return true

func test_relay_accepts_only_wss(runner) -> bool:
	for good: String in [EXP_RELAY, "wss://wargrid-relay-exp.fly.dev/ws"]:
		runner.check(JoinLink.relay(good) == good, "JL3 accepts %s" % good)
	for bad: String in ["ws://x.example/ws", "https://x.example/ws", "javascript:alert(1)", "wss://", "wss:///ws", "wss://x.example/ws extra", "wss://" + "a".repeat(260)]:
		runner.check(JoinLink.relay(bad) == "", "JL3 rejects '%s'" % bad.left(40))
	return true

func test_code_from_pasted_text(runner) -> bool:
	var wanted := {
		" abc234\n": "ABC234",
		"https://wargrid-web-test.fly.dev/?code=QRS234": "QRS234",
		"join me: https://x.example/?code=QRS234&relay=wss%3A%2F%2Fy.example%2Fws thanks": "QRS234",
		"https://player.example/?code=ABC234": "ABC234",
		"my code is QRS234 ok": "QRS234",
		"hello": "",
		"ABC2345": "",
		"ABCI34": "",
	}
	for text: String in wanted:
		runner.check(JoinLink.code_from(text) == wanted[text], "JL4 '%s' -> '%s', got '%s'" % [text.left(40), wanted[text], JoinLink.code_from(text)])
	runner.check(JoinLink.code_from("x".repeat(2049 - 11) + "code=ABC234").is_empty(), "JL4 2049 characters are ignored")
	return true

func test_link_carries_relay_only_when_not_default(runner) -> bool:
	runner.check(JoinLink.link(BASE, "ABC234", JoinLink.DEFAULT_RELAY) == BASE + "?code=ABC234", "JL5 default relay is left out")
	var url: String = JoinLink.link(BASE, "ABC234", EXP_RELAY)
	runner.check(url == BASE + "?code=ABC234&relay=wss%3A%2F%2Fx.example%2Fws", "JL5 relay is encoded, got %s" % url)
	var back: Dictionary = JoinLink.parse(url.substr(url.find("?")))
	runner.check(back.get("code") == "ABC234" and back.get("relay") == EXP_RELAY, "JL5 round trip, got %s" % [back])
	return true

func test_prerelease_is_the_dev_suffix(runner) -> bool:
	runner.check(PlaytestSettings.prerelease("0.12.0-dev"), "JL6 -dev is prerelease")
	for release: String in ["0.12.0", "0.12.0-rc.1", ""]:
		runner.check(not PlaytestSettings.prerelease(release), "JL6 '%s' is not prerelease" % release)
	var saved: String = AudioSettings.path
	AudioSettings.path = scratch
	DirAccess.remove_absolute(scratch)
	for version: String in ["0.12.0-dev", "0.12.0"]:
		runner.check(PlaytestSettings.enabled(version) == PlaytestSettings.prerelease(version), "JL6 enabled follows prerelease for %s" % version)
	DirAccess.remove_absolute(scratch)
	AudioSettings.path = saved
	return true
