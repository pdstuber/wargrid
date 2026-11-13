# P2 addendum: F5 join link, relay override and paste shim

**Status:** addendum to the [P2 plan](2026-11-13-p2-you-clicked-we-heard.md); replaces its Task 10 ("F5 outcome") with Tasks 10a-10d. Scope decided by the user (2026-11-13); this document awaits the user's approval.

> **For agentic workers:** same run rules as the P2 plan (coordinator, one fresh Sonnet subagent per task, no per-task reviewers; the Opus review in P2 Task 12 covers these tasks). Every task subagent reads the P2 plan's "Global Constraints" and "Review Focus" and this file's "Constraints" and "Review Focus". Resume record: [P2 verification](../../reference/p2-verification.md).

**Goal:** on the web, a joiner never has to paste: the host's Copy button copies a join link and the launcher pre-fills the join field from `?code=`. Cmd/Ctrl+V works in every text field (Firefox, Chrome). The relay URL field and the Advanced fold exist only in prerelease builds, which also accept `?relay=wss://…` to meet on an experimental relay.

**Cause (evidence: research note `f5-clipboard-research.md`, private, read against Godot `4.7.2-stable`):** Godot's web input cancels every keydown (`platform/web/js/libs/library_godot_input.js:501-513`), so the browser never fires `paste`; `LineEdit.paste_text()` then reads the cached clipboard (`platform/web/display_server_web.cpp:1036-1038`), which an async `readText()` fills only afterwards. Upstream issue #119747 and PR #105845 are open. The Copy button (`DisplayServer.clipboard_set` inside the `pressed` handler) runs inside the mouseup handler and is expected to work (not yet checked in a browser).

## Constraints

- All P2 Global Constraints hold: presentation/launcher only, `git diff main -- game/scripts/simulation game/scripts/net` empty, gates before each GREEN (`sh tools/run_tests.sh`, `sh tools/run_lint.sh`, `sh tools/run_warnings.sh`, `sh tools/check_public.sh`), Bash `timeout: 600000`, logs `~/projects/wargrid-p2-work/t10<x>-<step>.log`, judged by exit code and `TESTS PASSED`.
- **Prerelease rule:** `PlaytestSettings.prerelease(version)` = `version.ends_with("-dev")`, the version default of `PlaytestSettings.enabled` without the stored override. It lives in `game/scripts/playtest/playtest_settings.gd` (already the build-identity place: `build_id`); `enabled()` calls it.
- **JavaScriptBridge only on web:** every `JavaScriptBridge` call in new code sits behind `OS.has_feature("web")` (as `bench_runner.gd` does), so desktop and headless never touch it.
- **Release builds:** `Advanced` and `RelayUrl` stay in the tree (the `_set_busy` path list is unchanged) but are never visible; `RelayUrl.text` is always `JoinLink.DEFAULT_RELAY`; `?relay=` is ignored. Create reads `RelayUrl.text` as today.
- **Never auto-connect:** neither `?code=` nor `?relay=` starts a connection; the player still picks a faction and presses Join or Create.
- **Codes:** exactly 6 characters of the relay alphabet `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (`relay/room.go` `codeAlphabet`), case-insensitive in, upper-case out. **Relay override:** starts with `wss://`, has a host, at most 256 characters, no whitespace. Page query and pasted text over 2048 characters are ignored.
- Not done (user, 2026-11-13): Safari/iOS fallbacks (a Paste button with `readText()` inside the click, or `window.prompt()`). Trigger: a Safari or iOS player reports the join field cannot take a paste, or check C fails in Safari. Also not done: an engine patch (PR #105845) in custom web templates.
- Don't touch: `game/scripts/net/`, `game/scripts/simulation/`, `relay/`, `web/`, `tools/deploy_web.sh`, the release workflow.

## Review Focus (adds to the P2 list)

6. **A release build can never be sent to a foreign relay by a crafted link:** `?relay=` is ignored and the fold hidden when not prerelease; the shim cannot insert into the hidden field. Tests: N21, N22 (release half), PS4.
7. **Malformed or oversize `?code=`:** 5 or 7 characters, characters outside the alphabet, markup, a 3000-character query: the join field stays empty, nothing throws. Test: JL2, N22.
8. **A pasted link with the code in the middle of other text** (a chat message, a link carrying `&relay=`, a hostname that looks like a code): the join field gets the `code=` value. Test: JL4, PS1.
9. **Double install of the shim** (back to the menu twice): Godot side guarded by the root node name, JS side by `window.wargridPasteInstalled`; one paste inserts once. Manual check M6.
10. **A launcher freed while the JS callback is alive:** the shim is a child of the root window, not of the launcher, so the online scene's `queue_free()` of the launcher leaves it valid; `_exit_tree` clears `window.wargridPaste`, after which the keydown listener stops intercepting. Test PS3 (no focus owner); manual check M7.

## Tasks

| Task | What | Model |
|---|---|---|
| 10a | Pure rules: `JoinLink` and `PlaytestSettings.prerelease` | Sonnet |
| 10b | Launcher: prerelease-only fold, `?code=`/`?relay=`, Copy link | Sonnet |
| 10c | Paste shim (starts only after the user's check C in Firefox) | Sonnet |
| 10d | F5 outcome, docs and verification rows | Sonnet |

---

### Task 10a: Pure rules

```text
Task: pure query parser, code and relay validation, code extraction, link builder, prerelease helper.
Owns: game/scripts/join_link.gd (new), game/scripts/playtest/playtest_settings.gd, game/tests/test_join_link.gd (new), game/tests/run_tests.gd
Invariant: PlaytestSettings.enabled behaves as on main (test_playtest unchanged and green).
Boundary: empty, "?"-only, duplicate keys, percent-encoding, oversize, lower case, look-alike tokens.
Red: JL1-JL6 fail on assertions (stubs return "" / {} / false).
Green: test_join_link; test_playtest.gd; full suite.
Stop: a JL expectation below turns out ambiguous for real links (e.g. uri_encode output differs): report, do not reword the test.
```

**Files:** create `game/scripts/join_link.gd`, `game/tests/test_join_link.gd` (+ both `.gd.uid` tracked); modify `game/scripts/playtest/playtest_settings.gd`, `game/tests/run_tests.gd` (append `preload("res://tests/test_join_link.gd")` as the last `SUITES` entry).

**Interfaces (produces):** `join_link.gd` (`extends RefCounted`, statics only):
- `const DEFAULT_RELAY := "wss://relay.pdstuber.dev/ws"`, `const ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"`, `const MAX_INPUT := 2048`.
- `static func parse(search: String) -> Dictionary`: strips one leading `?`, splits on `&`, each pair at the first `=`, value `uri_decode()`d; first occurrence of a key wins (as `URLSearchParams.get`); `{}` when `search.length() > MAX_INPUT`.
- `static func code(value: String) -> String`: `value.to_upper()` if it is 6 characters all in `ALPHABET`, else `""`.
- `static func relay(value: String) -> String`: `value` if it begins `wss://`, is longer than 6, at most 256, contains no whitespace and the character after `wss://` is not `/`; else `""`.
- `static func code_from(text: String) -> String`: `""` over `MAX_INPUT`; first the value after a case-insensitive `code=` (regex `(?i)code=([A-Z0-9]+)`) through `code()`; else the first standalone 6-character alphanumeric token (`(?i)(?<![A-Z0-9])[A-Z0-9]{6}(?![A-Z0-9])`) that passes `code()`.
- `static func link(base: String, match_code: String, relay_url: String) -> String`: `base + "?code=" + match_code`, plus `"&relay=" + relay_url.uri_encode()` only when `relay_url != DEFAULT_RELAY`.
- `playtest_settings.gd`: `static func prerelease(version: String = str(ProjectSettings.get_setting("application/config/version"))) -> bool: return version.ends_with("-dev")`; `enabled()` returns `stored if stored is bool else prerelease(version)`.

- [ ] **Step 1: Failing tests** in `test_join_link.gd` (header as `test_order_voice.gd`):
  - `test_query_parses_like_the_browser` (JL1): `parse("")` and `parse("?")` are `{}`; `parse("?code=ABC234&relay=wss%3A%2F%2Fx.example%2Fws")` gives `code` `ABC234`, `relay` `wss://x.example/ws`; `parse("?code=AAA222&code=BBB333").code == "AAA222"`; `parse("?x=1&code")` has `code` `""` and `x` `"1"`; `parse("?code=" + "A".repeat(3000))` is `{}`.
  - `test_code_accepts_only_relay_codes` (JL2): `code("ABC234") == "ABC234"`, `code("abc234") == "ABC234"`; `""` for `"ABC23"`, `"ABC2345"`, `"ABC0O1"`, `"ABCI34"`, `"<b>A</b>"`, `"ABC 23"`.
  - `test_relay_accepts_only_wss` (JL3): accepts `wss://x.example/ws`, `wss://wargrid-relay-exp.fly.dev/ws`; `""` for `ws://x.example/ws`, `https://x.example/ws`, `javascript:alert(1)`, `wss://`, `wss:///ws`, `wss://x.example/ws extra`, `"wss://" + "a".repeat(260)`.
  - `test_code_from_pasted_text` (JL4): `" abc234\n" -> "ABC234"`; `"https://wargrid-web-test.fly.dev/?code=QRS234" -> "QRS234"`; `"join me: https://x.example/?code=QRS234&relay=wss%3A%2F%2Fy.example%2Fws thanks" -> "QRS234"`; `"https://player.example/?code=ABC234" -> "ABC234"` (`code=` beats the look-alike host token); `"my code is QRS234 ok" -> "QRS234"`; `""` for `"hello"`, `"ABC2345"`, `"ABCI34"`, and a 2049-character text containing `code=ABC234`.
  - `test_link_carries_relay_only_when_not_default` (JL5): `link("https://wargrid-web-test.fly.dev/", "ABC234", JoinLink.DEFAULT_RELAY) == "https://wargrid-web-test.fly.dev/?code=ABC234"`; with `wss://x.example/ws` the result equals `...?code=ABC234&relay=wss%3A%2F%2Fx.example%2Fws`, and `parse` of its part from `?` returns that code and relay (round trip).
  - `test_prerelease_is_the_dev_suffix` (JL6): `prerelease("0.12.0-dev")` true; false for `"0.12.0"`, `"0.12.0-rc.1"`, `""`; `PlaytestSettings.enabled("0.12.0-dev")` and `enabled("0.12.0")` with a scratch `AudioSettings.path` (no stored key) equal `prerelease` of the same string.
- [ ] **Step 2: Red.** Stubs (consts set, funcs return `{}` / `""` / `false`) so the suite loads; `WARGRID_TEST_ONLY=test_join_link sh tools/run_tests.sh > ~/projects/wargrid-p2-work/t10a-red.log 2>&1`: assertion failures only, no `SCRIPT ERROR`.
- [ ] **Step 3: Implement** as in Interfaces.
- [ ] **Step 4: Green.** `WARGRID_TEST_ONLY=test_join_link`, `=test_playtest.gd` exit 0; full suite (baseline + 6 cases), lint, warnings, check_public exit 0; simulation/net diff empty. Evidence row.

---

### Task 10b: Launcher wiring

```text
Task: fold and relay field prerelease-only; pre-fill from ?code= (and ?relay= in prerelease); Copy copies a join link on the web.
Owns: game/scripts/launcher.gd, game/scenes/launcher.tscn, game/tests/test_online_scene.gd
Invariant: N5, N17, N18, N20 keep their meaning; desktop Copy still copies the bare code; no connection starts on load.
Boundary: release with a crafted ?relay=; prerelease with a bad ?relay=; oversize query; Copy with a non-default relay.
Red: N21-N24 fail (no prerelease/page/search members, fold visible in release, no link).
Green: test_online_scene; test_join_link; test_playtest.gd; full suite.
Stop: the release layout needs a node removed from _set_busy's list, or N5/N20 need more than the explicit prerelease = true.
```

**Interfaces:** `launcher.gd`:
- `const JoinLink = preload("res://scripts/join_link.gd")`; members `var prerelease: bool = PlaytestSettings.prerelease()`, `var page: String = _page_value("location.origin + location.pathname")`, `var search: String = _page_value("location.search")`; `static func _page_value(expression: String) -> String: return str(JavaScriptBridge.eval(expression)) if OS.has_feature("web") else ""` (tests set the members after `instantiate()`, before `add_child`, as `online_main.gd`'s `web` member is set).
- `func _apply_page() -> void`, called at the end of `_ready` (after `Advanced.toggled` is connected): `RelayUrl.text = JoinLink.DEFAULT_RELAY`; `Advanced.visible = prerelease`; `JoinRow/Code.text = JoinLink.code(query.get("code", ""))`; when `prerelease` and `JoinLink.relay(query.get("relay", ""))` is non-empty: set it as `RelayUrl.text` and `Advanced.button_pressed = true` (shows it); `WaitRow/Copy.text = "Copy link" if not page.is_empty() else "Copy code"`.
- `func _copy_text() -> String: return _code if page.is_empty() else JoinLink.link(page, _code, $Center/Box/RelayUrl.text.strip_edges())`; the Copy handler becomes `DisplayServer.clipboard_set(_copy_text())`.
- `launcher.tscn`: remove `text = "wss://relay.pdstuber.dev/ws"` from `RelayUrl` (one source: `JoinLink.DEFAULT_RELAY`). Before/after:
  ```text
  before: visible = false / layout_mode = 2 / text = "wss://relay.pdstuber.dev/ws" / placeholder_text = "Relay URL"
  after:  visible = false / layout_mode = 2 / placeholder_text = "Relay URL"
  ```

- [ ] **Step 1: Failing tests** in `test_online_scene.gd` (append to `cases()`; scratch `AudioSettings.path` as N20; helper `_launcher(runner, parent, prerelease, search, page)` instantiates, sets the three members, adds it, waits two frames):
  - N5 and N20: set `launcher.prerelease = true` before `add_child` (they open the fold; stays green on a release version).
  - `test_launcher_release_hides_relay` (N21), 1280x720 and 1920x1080, `prerelease = false`, `WaitRow` and `ThisBuild` visible: `not Advanced.visible`, `not RelayUrl.visible`, `RelayUrl.text == JoinLink.DEFAULT_RELAY`; `_set_busy(true)` then `RelayUrl.editable == false`, `_set_busy(false)` restores it; every `LAUNCHER_PATHS` entry except `Advanced` and `RelayUrl` inside the viewport, no two overlapping.
  - `test_launcher_prefills_from_page` (N22): release, `search = "?code=abc234&relay=wss%3A%2F%2Fx.example%2Fws"`: `Code.text == "ABC234"`, `RelayUrl.text == DEFAULT_RELAY`, `not RelayUrl.visible`. Prerelease, same search: `Code.text == "ABC234"`, `RelayUrl.text == "wss://x.example/ws"`, `RelayUrl.visible`, `Advanced.button_pressed`. Prerelease `?relay=https%3A%2F%2Fx.example%2Fws&code=ABC2345`: field default, fold closed, `Code.text == ""`. Prerelease `"?code=" + "A".repeat(3000)`: `Code.text == ""`. Every case: `launcher._transport == null and not launcher.is_processing()` ("N22 page address never connects").
  - `test_copy_link_on_web` (N23): `page = "https://wargrid-web-test.fly.dev/"`, prerelease, `_code = "ABC234"`: `Copy.text == "Copy link"`, `_copy_text() == "https://wargrid-web-test.fly.dev/?code=ABC234"`; after `RelayUrl.text = "wss://x.example/ws"`, `_copy_text()` ends with `&relay=wss%3A%2F%2Fx.example%2Fws`. `page = ""`: `Copy.text == "Copy code"`, `_copy_text() == "ABC234"`.
  - `test_launcher_reads_no_page_off_web` (N24): a plain `Launcher.instantiate()` in this headless run has `page == ""` and `search == ""`.
- [ ] **Step 2: Red.** `WARGRID_TEST_ONLY=test_online_scene sh tools/run_tests.sh > ~/projects/wargrid-p2-work/t10b-red.log 2>&1`: N21-N24 fail on assertions (members read through `launcher.get(...)`), no `SCRIPT ERROR`.
- [ ] **Step 3: Implement** as in Interfaces.
- [ ] **Step 4: Green.** `WARGRID_TEST_ONLY=test_online_scene`, `=test_join_link`, `=test_playtest.gd`, `=test_pause_menu` exit 0; full suite, lint, warnings, check_public exit 0; simulation/net diff empty; `rg -n 'JavaScriptBridge' game/scripts/launcher.gd` shows only `_page_value`. Record the `Center/Box` height at 1280x720 in release and prerelease.

---

### Task 10c: Paste shim

```text
Task: Cmd/Ctrl+V reaches the browser's paste event and lands in the focused editable LineEdit; the join field takes only a code.
Owns: game/scripts/presentation/paste_shim.gd (new), game/scripts/launcher.gd (install line), game/scenes/launcher.tscn (group), game/tests/test_join_link.gd
Invariant: desktop and headless never create the shim; stock paste still works on desktop.
Boundary: hidden, non-editable, non-LineEdit or no focus owner; selection; oversize; text without a code.
Red: PS1-PS5 fail (no insert, no group).
Green: test_join_link; test_online_scene; full suite.
Stop: GATE FIRST: the user confirms check C (research note §5) passed in Firefox. Not confirmed or failed: skip this task; 10d records "paste shim not built: check C failed/not run".
```

**Interfaces:** `paste_shim.gd` (`extends Node`, `name = "PasteShim"` in `_init`):
- `const JS := "if (!window.wargridPasteInstalled) { window.wargridPasteInstalled = true; window.addEventListener('keydown', e => { if (window.wargridPaste && (e.metaKey || e.ctrlKey) && !e.altKey && e.key.toLowerCase() === 'v') e.stopImmediatePropagation(); }, true); window.addEventListener('paste', e => { if (window.wargridPaste) window.wargridPaste(e.clipboardData.getData('text')); }, true); }"` (the capture listener stops the keydown before Godot's canvas listener cancels it, without `preventDefault`, so the browser fires `paste`).
- `var _callback: JavaScriptObject`; `_ready`: `JavaScriptBridge.eval(JS, true)`, `_callback = JavaScriptBridge.create_callback(_on_paste)`, `JavaScriptBridge.get_interface("window").wargridPaste = _callback` (the member keeps the callback alive, per the JavaScriptBridge docs); `_exit_tree`: `JavaScriptBridge.eval("window.wargridPaste = null", true)`; `_on_paste(args: Array)`: `insert(get_viewport().gui_get_focus_owner(), str(args[0]))`.
- `static func insert(focus: Control, text: String) -> bool`: false unless `focus is LineEdit`, `editable`, `is_visible_in_tree()`, `text.length() <= JoinLink.MAX_INPUT`. In group `join_code`: `JoinLink.code_from(text)`, false if empty, else replaces the whole text, caret at the end. Otherwise `text.strip_escapes()` (as `LineEdit.paste_text`), false if empty; deletes the selection (`delete_text(get_selection_from_column(), get_selection_to_column())`, `deselect()`), `insert_text_at_caret`. Both emit `text_changed` with the new text; return true.
- `launcher.gd` `_ready`, after `_apply_page()`: `if OS.has_feature("web") and not get_tree().root.has_node("PasteShim"): get_tree().root.add_child.call_deferred(PasteShim.new())`. `launcher.tscn` `JoinRow/Code`: `groups=["join_code"]` on its node line.

- [ ] **Step 0: Stop gate.** Coordinator asks the user for check C's Firefox result and records it in the verification file. Proceed only on "passed".
- [ ] **Step 1: Failing tests** in `test_join_link.gd` (LineEdits added under `runner.root`, freed at the end):
  - `test_paste_join_field_takes_the_code` (PS1): join-group LineEdit with `max_length = 6` and text `"XY"`: `insert(edit, "join me https://x.example/?code=qrs234 pls")` true, text `"QRS234"`, caret 6; `insert(edit, "hello")` false, text unchanged.
  - `test_paste_inserts_at_caret` (PS2): plain LineEdit `"wss://old"` with columns 6-9 selected: `insert(edit, "x.example/ws\n")` gives `"wss://x.example/ws"`; `text_changed` fired once.
  - `test_paste_refuses_unusable_targets` (PS3): false for `null` (no focus owner), a `Button`, a non-editable LineEdit, a hidden LineEdit, a 2049-character text; their text unchanged.
  - `test_paste_cannot_reach_release_relay` (PS4): a release launcher (`prerelease = false`, Task 10b helper reused through a local copy): `insert(RelayUrl, "wss://evil.example/ws")` false, `RelayUrl.text == JoinLink.DEFAULT_RELAY`.
  - `test_shim_only_on_web` (PS5): `Code.is_in_group("join_code")` in `launcher.tscn`; after a launcher's `_ready` and one frame in this headless run, `runner.root.has_node("PasteShim") == false`.
- [ ] **Step 2: Red** (`insert` stub returns false; group missing): `WARGRID_TEST_ONLY=test_join_link` to `~/projects/wargrid-p2-work/t10c-red.log`, assertion failures only.
- [ ] **Step 3: Implement.** **Step 4: Green:** `=test_join_link`, `=test_online_scene` exit 0; full suite, lint, warnings, check_public exit 0; simulation/net diff empty. The JS half is unverified until the manual checks below.

---

### Task 10d: F5 outcome and docs

```text
Task: record the F5 outcome and update the living docs for 10a-10c.
Owns: docs/STATUS.md (F5 row), docs/guide/05-presentation.md (Launcher bullet), docs/development.md (web section), game/data/playtest/focus.json (P2 card "paste" item text only), docs/superpowers/plans/2026-11-13-p2-you-clicked-we-heard.md (Task 10 and table row), docs/reference/p2-verification.md
Invariant: no "(user, DATE)" tag beyond those recorded in the verification file; symbols, not line numbers.
Green: test_playtest; full suite; check_public; links checked.
```

- [ ] **STATUS.md F5 row:** keep the report text, replace "not reproduced yet; fix soon" with: "reproduced by the user on the test app (date from the gate (a) row); cause in Godot 4.7.2's web clipboard (paste keydown cancelled, `LineEdit` reads a stale cache; upstream #119747, PR #105845 open); fixed on `p2-you-clicked` (join link and `?code=`, `PasteShim`, relay field prerelease-only with `?relay=`), not merged; Safari and iOS unverified". Without 10c: "`PasteShim` not built: check C failed/not run".
- [ ] **05-presentation.md, Launcher bullet:** replace "the relay URL sits under a fold named Advanced, closed by default" with: "in prerelease (`-dev`, `PlaytestSettings.prerelease`) builds the relay URL sits under a closed Advanced fold and a `?relay=wss://…` page address fills it; release builds show neither and use `JoinLink.DEFAULT_RELAY`. On the web, Copy copies a join link (`JoinLink.link`) and the launcher pre-fills the join field from `?code=`, never joining by itself; `PasteShim` makes Cmd/Ctrl+V work in text fields, because Godot 4.7.2's web input cancels the paste keydown".
- [ ] **development.md, web section:** after "Playtest builds go to the separate app `wargrid-web-test` and share that relay", add: "Prerelease builds accept `?relay=wss://…` to point the launcher at an experimental relay app; the host's join link carries it when it differs from the default."
- [ ] **focus.json** P2 card item `paste`: text "Online: Copy the join link, open it in a second tab, and paste a code into the join field" (id unchanged; `rg -n 'paste' game/tests` first to confirm no test pins the text).
- [ ] **P2 plan:** Task 10 body becomes "Replaced by [the F5 addendum](2026-11-13-p2-f5-paste-and-links.md): reproduced by the user on the test app, cause in Godot's web clipboard, fixed by 10a-10c"; table row 10 the same; Task 12 Step 1's test list gains JL1-JL6, N21-N24, PS1-PS5.
- [ ] **p2-verification.md:** Tasks table row `10 | F5 outcome` replaced by:
  ```text
  | 10a | Pure rules: JoinLink and PlaytestSettings.prerelease | not started |
  | 10b | Launcher: prerelease-only fold, ?code=/?relay=, Copy link | not started |
  | 10c | Paste shim (after the user's check C in Firefox) | not started |
  | 10d | F5 outcome and docs | not started |
  ```
  Gate (a) row: "F5 reproduced by the user on the test app" with the recorded steps; check C result (Firefox, then Chrome, Safari if run) in an evidence row; gate (b) gains "M1-M7 browser checks (Firefox, then Chrome)".
- [ ] Links: `rg -n '\]\(' <changed docs>`, open each relative target; `sh tools/check_public.sh` exit 0; `WARGRID_TEST_ONLY=test_playtest.gd` and full suite exit 0.

---

### Manual browser checks (stop gate b, test deploy of the final tree, Firefox first, then Chrome)

The test app is a `-dev` build: release behaviour (N21, N22, PS4) is covered headless only. Two tabs, A host, B joiner. Record pass/fail and any prompt or console error per item.

- [ ] **M1 Copy:** A: Create, the button reads "Copy link"; press it; paste into a text editor: `https://wargrid-web-test.fly.dev/?code=XXXXXX`, no `relay`.
- [ ] **M2 Link:** B opens that link: join field shows the code, Status empty, no "Connecting…"; pick a faction, Join; the match starts on both tabs.
- [ ] **M3 Relay override:** open `/?relay=wss%3A%2F%2F<experimental relay app>.fly.dev%2Fws`: fold open, field shows the URL, nothing connects; Create, Copy link: it carries `&relay=…`; B opens it: both fields filled, Join works. Then `/?relay=https%3A%2F%2Fx.example%2Fws` and `/?code=ABC2345`: default relay, fold closed, join field empty.
- [ ] **M4 Paste a code** (10c): copy `QRS234` in another app, click the join field, Cmd+V (Chrome on Linux/Windows: Ctrl+V): `QRS234`, no "Paste" menu or permission prompt. Copy `join https://wargrid-web-test.fly.dev/?code=QRS234 pls`, paste: `QRS234`.
- [ ] **M5 Paste elsewhere:** relay field: paste a URL; select part of it, paste again: the selection is replaced.
- [ ] **M6 Double install:** start offline, back to the menu, again; paste once into the relay field: the text appears once.
- [ ] **M7 Freed launcher:** start an online match (launcher freed); with the playtest helper on, paste into its note field: inserted; paste with nothing focused: nothing, no console error.
