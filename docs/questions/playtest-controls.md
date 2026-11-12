# Zero Hour controls vs Wargrid (friend's playtest)

Paths: ZH = ~/projects/CnC_Generals_Zero_Hour/GeneralsMD/Code/GameEngine/Source (abbrev `ZH/`). Retail dumps in ~/projects/wargrid-overnight-work/scratch_ctl/ (decoded with read_big on a copy of tools/check_reference.py, `python3 -I`).

## Findings (short, cited)

### 1. Default key map (source: retail EnglishZH.big `data\english\commandmap.ini`, 988 lines)
`INIZH.big data\ini\commandmap.ini` exists but is a 4-line header only (no bindings). `commandmapdebug.ini` / `commandmapdemo.ini` are cheat/debug, ignored here. Only mappings with a key or modifier are listed; all fire on key DOWN unless noted.

| Key | Modifier | Meaning |
|---|---|---|
| Arrow keys | none | scroll camera (hardcoded, not in commandmap: ZH/GameClient/MessageStream/LookAtXlat.cpp:171-216) |
| F1..F8 | none | jump to saved camera view 1..8 |
| F1..F8 | Ctrl | save camera view 1..8 |
| 0..9 | Ctrl | create control group |
| 0..9 | none | select control group (double press centres on it, inferred, not checked) |
| 0..9 | Shift | add group to selection |
| 0..9 | Alt | view (centre camera on) group |
| Q | none | select all units (skips KINDOF_IGNORES_SELECT_ALL; CommandXlat.cpp:2888-2951) |
| E | none | select all of the same type as selection (SELECT_MATCHING_UNITS) |
| H | none | jump to Command Center (CommandXlat.cpp:2861) |
| H | Ctrl | select hero (CommandXlat.cpp:2825) |
| Space | none | jump to last radar event (CommandXlat.cpp:2867-2884; works without radar) |
| Ctrl+Right / Ctrl+Left | Ctrl | select next / previous unit |
| Ctrl+Up / Ctrl+Down | Ctrl | select next / previous worker (dozer/worker) |
| S | none | stop |
| Ctrl+F | Ctrl | create formation |
| F | none | fast-forward replay (replays only) |
| Ctrl+C | Ctrl | all cheer |
| Ctrl (hold) | Ctrl | force-attack mode while held (BEGIN/END_FORCEATTACK) |
| Alt (hold) | Alt | waypoint mode while held (BEGIN/END_WAYPOINTS) |
| Shift (hold) | Shift | "prefer selection" mode while held: shift-click adds/toggles in selection (SelectionXlat.cpp:514-731) |
| Ctrl+B | Ctrl | place beacon |
| Del | none | delete beacon |
| Enter | none | chat to everyone |
| Backspace | none | chat to allies |
| Tab | none | diplomacy screen |
| Esc | none | options menu |
| F9 | none | toggle control bar |
| F12 | none | screenshot |
| Numpad 4 / 6 | none | rotate camera left / right (hold) |
| Numpad 8 / 2 | none | zoom camera in / out (hold) |
| Numpad 5 | none | reset camera |
| Shift+Alt+Ctrl+T | | toggle camera tracking drawable (debug-ish) |

Not in commandmap (source: absent from the ini): attack move, guard, scatter, build menus, production. Those are per-command-button hotkeys taken from the localized strings (generals.csf `&` markers). Not decoded here: **not found**.

### 2. Shift-queueing
- **Shift is NOT a queue key in ZH.** Shift = "prefer selection" (add to selection): commandmap `BEGIN_PREFER_SELECTION` Shift (retail commandmap), handled CommandXlat.cpp:3466-3474, used in SelectionXlat.cpp:514, 641, 731 and CommandXlat.cpp:1470. (source)
- **Waypoint queueing is Alt-hold + right-click**: `BEGIN_WAYPOINTS` = Alt (retail commandmap) sets waypoint mode (CommandXlat.cpp:3460-3464); move orders then become `MSG_ADD_WAYPOINT` (CommandXlat.cpp:878-880), dispatched to `groupMoveToPosition(&dest, true, ...)` (GameLogic/System/GameLogicDispatch.cpp:819-829). With addWaypoint the group drops formation (AIGroup.cpp:1568-1571) and each unit calls `aiFollowPathAppend` (AIGroup.cpp:1744-1750). Hover shows `MSG_ADD_WAYPOINT_HINT` (CommandXlat.cpp:1494). Only move; attack-move/others are not appended there (inferred from the dispatch code seen).
- **Dozers cannot queue several buildings.** `DozerAIUpdate::newTask`: "we should never be given more than one [build task]"; a second pending build task is cancelled (ZH/GameLogic/Object/Update/AIUpdate/DozerAIUpdate.cpp:1982-1996). A new `MSG_DOZER_CONSTRUCT` places the new site at once (`buildObjectNow`, GameLogicDispatch.cpp:1387-1420) and the dozer drops the old task; the half-built site stays and can be resumed later. Line-building (walls etc.) is one `MSG_DOZER_CONSTRUCT_LINE` drag (PlaceEventTranslator.cpp:270-282). So the friend's "queue buildings with Shift" is not a ZH feature (source).
- Production queue is a different thing (building queue of 9, already decided in design-answers-2026-11-08.md).

### 3. Camera without arrow keys (all source: ZH/GameClient/MessageStream/LookAtXlat.cpp)
- Edge scrolling: 3 px band (`edgeScrollSize = 3`, :69), starts on mouse position (:284-318). Only when NOT windowed (`!TheGlobalData->m_windowed`, :301). Retail GameData.ini has `Windowed = No`.
- Right-mouse drag: RMB down starts `SCROLL_RMB` unless selecting (:221-233); offset = HorizontalScrollSpeedFactor/VerticalScrollSpeedFactor * mouse delta from anchor (:420-421). A plain click (no drag) still issues the move/lookAt (ControlBarCallback.cpp:262-271 shows RMB on minimap = look at). Retail GameData.ini: `RightMouseAlwaysScrolls = Yes`.
- Middle mouse: held + drag rotates the view (:248-258, 322-338, factor 0.01 rad/px); a quick click (<5 frames, <5 px move) resets angle, pitch and zoom (:261-278).
- Wheel: each notch changes camera height by 10 (View.cpp:128-136; LookAtXlat.cpp:357-376).
- Minimap (radar window, ControlBarCallback.cpp:222-320): right-click (default mouse mode) or empty selection moves camera to that point; with units selected, left-click on minimap = `MSG_DO_MOVETO` order (:313).
- Space = last radar event, H = Command Center (see table).
- Retail GameData.ini (INIZH.big data\ini\gamedata.ini): CameraPitch 37.5, CameraHeight 232, MinCameraHeight 120, MaxCameraHeight 310, CameraAdjustSpeed 0.3, HorizontalScrollSpeedFactor 1.6, VerticalScrollSpeedFactor 2.0, KeyboardScrollSpeedFactor 2.0, ScrollAmountCutoff 50, KeyboardCameraRotateSpeed 0.1, EnforceMaxCameraHeight No.
- Options slider "Scroll Speed" writes pref `ScrollFactor` (OptionsMenu.cpp:358-362, 1193-1197); default is 0.5 (GlobalData.cpp:979); it multiplies keyboard/edge scroll (`SCROLL_AMT = 100`, LookAtXlat.cpp:67, 435-469). Slider does not scale RMB drag (only the INI factors do; :420-421).

### 4. What Wargrid binds today (source: game/project.godot [input], rg in game/scripts)
- project.godot: `camera_left/right/up/down` = A/D/W/S + arrow keys; `deselect` = Esc (keycode 4194305). Used only by the debug scene `main.gd:98` (extended by base/skirmish/online).
- Skirmish (`skirmish_main.gd:49`) pans with `ui_left/right/up/down` (arrows only), so WASD does not clash with S = stop.
- main.gd: wheel zoom via `change_zoom` (:143-146), Shift = add to selection (:132,169), Ctrl (:134,164), double click select-same-type (:164 `_double`), B = obstacle (debug), F3 = debug. No edge scroll, no RMB drag (RMB = order), no MMB, no jump keys.
- skirmish_main.gd:100-106: A = attack-move mode (then left click; Esc or RMB cancels), S = stop. RMB = move/attack/defence order (:116-118).
- base_main.gd:182-194: 1..N = build/production menu entries (conflicts with ZH 0..9 control groups), E = produce selected, U = unload, Esc = cancel placement/deselect.
- volume_sliders.gd:39: M = mute-ish volume panel key.
- Not present anywhere: control groups, Q select all, H command centre, Space last event, Ctrl hero/next worker, camera views F1-F8, waypoint queue, force attack (Ctrl), minimap (not built yet, milestone M7.6), edge scroll.
- Decisions already made (not re-asked): minimap flashes on attack, queue of 9, minimap free with Command Center (design-answers-2026-11-08.md:30, blueprint:614).

## Questions

Q1. Should Wargrid scroll the camera when the mouse touches the screen edge?
   a) Yes, 3 px edge band, fullscreen only — ZH default (LookAtXlat.cpp:69, 301)   b) Yes, always including windowed   c) No
   Recommendation: b, because the friend asked for non-arrow camera movement and edge scroll is the most natural one. Why it matters: windowed play (the web build) would otherwise get no edge scroll.

Q2. Should dragging with the right mouse button pan the camera?
   a) Yes, right-drag pans, plain right-click still orders — ZH default (LookAtXlat.cpp:221-233, GameData.ini RightMouseAlwaysScrolls = Yes)   b) No, right-click is orders only   c) Pan with middle-mouse drag instead
   Recommendation: a, because it is ZH feel and needs a small drag threshold. Why it matters: Wargrid's right click is the order button today.

Q3. What should the Space key do?
   a) Jump to the last radar event (last attack alert) — ZH default (CommandXlat.cpp:2867-2884)   b) Nothing   c) Jump to the selected units
   Recommendation: a, because the attack-flash alert already exists as a design decision. Why it matters: fast reaction to base attacks.

Q4. What should H do?
   a) Centre on the Command Center — ZH default (retail commandmap VIEW_COMMAND_CENTER, CommandXlat.cpp:2861)   b) Centre on the selected units   c) Nothing
   Recommendation: a. Why it matters: lets the player get home without a minimap.

Q5. Should camera positions be savable with function keys?
   a) Yes, Ctrl+F1..F8 saves, F1..F8 jumps — ZH default (retail commandmap SAVE_VIEW/VIEW_VIEW)   b) Later, not first   c) Never
   Recommendation: b, because it is rarely used and the minimap covers most of it. Why it matters: scope of the first controls batch.

Q6. Should the mouse wheel zoom the camera?
   a) Yes, in steps — ZH default (LookAtXlat.cpp:357-376, 10 height units a notch, 120..310 range)   b) No zoom   c) Yes, but only a few fixed levels
   Recommendation: c, because the pixel art needs integer zoom levels; Wargrid already has fixed ZOOMS (main.gd:106-111). Why it matters: ZH zoom is a continuous 3D height; pixel art cannot copy that.

Q7. Should the middle mouse click reset the camera?
   a) Click resets zoom (and angle) — ZH default (LookAtXlat.cpp:261-278)   b) No   c) Middle-drag rotates (not possible in a fixed isometric view)
   Recommendation: a for zoom only, because it is cheap. Why it matters: rotation does not exist in the fixed-angle iso view anyway.

Q8. Which keys select and group units first?
   a) Ctrl+0..9 makes a group, 0..9 selects it, Shift+0..9 adds, Alt+0..9 centres — ZH default (retail commandmap TEAM)   b) Same but only Ctrl and number (no Shift/Alt variants)   c) Later
   Recommendation: b, because groups are the biggest skill gap. Why it matters: 1..N already picks build menu entries in base_main.gd:184, so the two must not clash.

Q9. Should Q select all units and E select all of the same type on screen?
   a) Both — ZH default (retail commandmap SELECT_ALL=Q, SELECT_MATCHING_UNITS=E)   b) Only Q   c) Neither; keep double-click only
   Recommendation: c until a conflict is resolved, because Wargrid already uses E for produce (base_main.gd:188). Why it matters: E means different things in Wargrid and ZH.

Q10. How should the player queue several move points for units?
   a) Hold Alt and right-click each point — ZH default (retail commandmap BEGIN_WAYPOINTS = Alt, CommandXlat.cpp:878)   b) Hold Shift and right-click (common in other RTS games)   c) No waypoints
   Recommendation: a, because Shift is already add-to-selection in both games. Why it matters: friend expected Shift queuing; ZH has none.

Q11. Should a dozer or worker queue several buildings?
   a) No, a new order replaces the old one, the half-built site stays — ZH default (DozerAIUpdate.cpp:1982-1996)   b) Yes, queue with Alt or Shift click   c) Yes, queue always when placing a second one
   Recommendation: a, because that is ZH; but the friend asked, so this is a real design choice. Why it matters: it is the one place the friend's expectation and ZH differ.

Q12. Which key stops units, and should Ctrl force attack?
   a) S stops, hold Ctrl+right-click force-attacks — ZH default (retail commandmap STOP=S, BEGIN_FORCEATTACK=Ctrl)   b) S stops only   c) Keep today's A and S only
   Recommendation: a for S (done) and later for Ctrl. Why it matters: force attack is needed to hit own or neutral structures.

Q13. Which keys select units one by one?
   a) Ctrl+Left/Right next/previous unit, Ctrl+Up/Down next/previous worker — ZH default (retail commandmap)   b) Only next worker   c) None
   Recommendation: b, because finding idle dozers is the real use. Why it matters: the friend's building findings started from dozer handling.

Q14. How should building and production hotkeys work?
   a) Per-button letter keys from the command card — ZH default (letters come from generals.csf `&`, not decoded here)   b) Keep 1..N for menu slots as today   c) Both
   Recommendation: b for now, because the letter table needs the localized strings we have not read. Why it matters: group keys 0..9 and menu keys 1..N share the number row.

Q15. Which HUD keys come first?
   a) Esc = options, F9 = hide control bar, Tab = diplomacy, Enter/Backspace = chat — ZH default (retail commandmap)   b) Only Esc and Enter chat   c) None before the HUD milestone
   Recommendation: c, because the HUD (M7.6) is not built. Why it matters: stops key work for screens that do not exist.
