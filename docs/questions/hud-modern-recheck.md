# HUD answers re-checked against modern RTS games (M7.6)

Scope: interface only (blueprint §2 "Gameplay vs interface", user 2026-11-09). Selling and Guard values are gameplay and not re-checked. Already decided controls (blueprint "Controls", design answers "Controls") are not asked again.

Sources. **ZH src** = ~/projects/CnC_Generals_Zero_Hour @ 0a05454, paths under `GeneralsMD/Code/GameEngine/`. **GGC** = ~/projects/GeneralsGameCode @ afc2a103f. **OpenRA** = ~/projects/OpenRA @ 9636b63eae. **BAR** = github.com/beyond-all-reason/Beyond-All-Reason @ 81c5db4eda, `luaui/Widgets/` (fetched 2026-11-09). Web pages fetched 2026-11-09. Company of Heroes 3: not sourced (no primary page found quickly).

## Findings (short, cited)

Minimap attack flash
- **source** ZH limits "under attack" radar events to one per 10 s within 250 units (`Source/Common/System/Radar.cpp:1302-1303`), but the distance line has no parentheses (`Radar.cpp:1317-1318`: `x - pos->x * x - pos->x + ...`), so the "nearby" test passes almost always. **inferred** retail ZH shows at most one attack flash per 10 s map-wide, wherever the second attack is.
- **source** GGC fixed the formula (`Core/GameEngine/Source/Common/System/Radar.cpp:1190`) but deliberately keeps the map-wide suppression by default, "because otherwise they trigger way too frequent from cargo planes" (`Radar.cpp:1193-1196`, `Core/GameEngine/Include/Common/GameDefines.h:67-68`).
- **source** ZH flashes only for the local player's own objects (`Source/GameLogic/Object/Object.cpp:1872-1878`); an event lives 4 s by default (`Include/Common/Radar.h:184`).
- **source** AoE IV Season Two (ageofempires.com/news/age-of-empires-iv-update-17718/): "Reduced number of map pings when multiple attacks occur next to each other", "Ally under attack ping changed from red to blue", "Increased notification re-trigger time when buildings are attacked from 0 to 15 seconds"; developer note: "When there are too many alerts on the map they can become meaningless noise."
- **source** BAR's attack notification repeats at most every 15 s (`unit_attackMoveNotification.lua:18`). Wargrid's "base under attack" voice line has a 900-tick (30 s at 30 Hz) cooldown (`game/scripts/presentation/announcer.gd:4`, `game/project.godot:45`).

Health bars
- **source** Wargrid today: bar when selected or damaged (`game/scripts/presentation/world_view.gd:251-252`). ZH: selected or hovered (next-m76-hud.md, Drawable.cpp:3855-3859).
- **source** AoE IV patch 5.1.148 (ageofempires.com/news/age-of-empires-iv-patch-51148/): setting "Always on" (all bars at 90 % opacity) or "Smart" (hidden "until damaged or selected"). Wargrid's answer equals AoE IV "Smart".
- **source** SC2 patch 2.0.4 (news.blizzard.com/en-us/starcraft2/8724162): life bar setting incl. "Damaged: Only show for units with less than their maximum life, energy, or shields", and "Display Team Colored Life Bar".
- **source** OpenRA setting Standard / when damaged / always (`OpenRA.Game/Settings.cs:26, 339`); selected, drag-boxed and hovered units always get bars (`OpenRA.Mods.Common/Traits/Render/SelectionDecorationsBase.cs:80-86`); hotkey CycleStatusBars on comma (`mods/common/hotkeys/game.yaml:51`), which Wargrid already uses for idle army.

Map pings
- **source** OpenRA: one beacon per player, a new one replaces the old (`OpenRA.Mods.Common/Traits/Player/PlaceBeacon.cs:68-74`), lives 750 ticks (`:21`) = 30 s at the default 40 ms step (`mods/ra/mod.yaml:297-299`); hotkey B (`mods/common/hotkeys/game.yaml:46`).
- **source** SC2 3.0.3 (news.blizzard.com/en-us/article/19930935): "Advanced Ping": Alt + drag-click picks "Attack, Defend, On My Way, or Retreat". No limit or duration stated.
- **source** AoE2 DE learn-to-play (ageofempires.com/learn-to-play/control-resources-aoe2/): Signal Allies "Puts a flare on the mini-map of allies for 3 seconds".
- **source** BAR auto-erases map marks after 60 s (`map_auto_mapmark_eraser.lua:15`) and plays a sound for allied point marks (`snd_mapmark_ping.lua:6`).

Idle units, control groups, production overview
- **source** ZH already has an idle-worker button with a count (`Source/GameClient/GUI/ControlBar/ControlBar.cpp:1202-1205, 2756-2785`; `Source/GameClient/InGameUI.cpp:5578-5597`) and draws the control-group number next to a unit's health bar (`Source/GameClient/Drawable.cpp:3124-3157`).
- **source** SC2 2.0.4: "New Select Army Units button is located next to the Idle Worker and Select all Warp Gates buttons." AoE IV Season Two: "Select all idle military units, and Cycle through idle military units". BAR ships an idle-builder panel on by default (`gui_idle_builders.lua:6, 11`).
- **source** SC2 has control-group buttons on screen (patch 1.3.0, news.blizzard.com/en-us/article/2356436: "These can now be set to ignore mouse clicks or be hidden completely"). BAR shows groups as stacked icons, on by default (`gui_unitgroups.lua:6, 11`). OpenRA draws the number on units only (`WithTextControlGroupDecoration.cs`).
- **source** AoE IV has a "global build queue" (update 17718: "Siege queued for construction in the field will only be seen in the global build queue"). BAR's "BuildBar" gives factory menus "everywhere on the map without selecting them" but is off by default (`gui_buildbar.lua:6, 11`).

Formation
- **source** ZH Ctrl+F (`MSG_CREATE_FORMATION`, `Source/GameLogic/System/GameLogicDispatch.cpp:885-889`) stores each unit's offset (`Source/GameLogic/AI/AIGroup.cpp:1097-1105`); a group moves at its slowest member's speed (`AIGroup.cpp:399-443`).
- **source** BAR draws formation lines with right-drag (`cmd_customformations2.lua:22`); Wargrid's right-drag already pans (decided). **source** AoE IV has formations (update 17718: "Units will now respect formation changes after finding a target"; source check 2026-11-09: PARTLY, the page shows formations exist, not that every group move uses them); AoE2 DE lists "Formations" as an advanced command (learn-to-play page). Default formations change how every group moves, which is gameplay, not interface (**inferred**).

Kept without a question (re-checked, no better modern option found)
- Queue of 9: OpenRA RA has no limit (`OpenRA.Mods.Common/Traits/Player/ProductionQueue.cs:55`, default 0), D2K uses 6 (`mods/d2k/rules/player.yaml:68`); SC2's queue size not found in a Blizzard page. Queue size affects how much money a player commits ahead (ZH charges at queueing), so it stays ZH.
- No selection limit: SC2 raised its cap to 500 (patch 1.5.2, news.blizzard.com/en-us/article/6830760), effectively none for Wargrid's army sizes.
- Chevrons on all sides: no modern game found that hides enemy veterancy (not found, not proof).
- Minimap free with the Command Center and blank at low power: power and radar are gameplay levers, not interface.
- Not asked (no primary source found in time): alert feed or alert list, tooltip contents, ally/team strip (BAR has `gui_ally_cursors.lua`, `gui_teamstats.lua`; not read).

## Questions

Q1. How often should the minimap flash when your stuff is attacked?
   a) At most once every 10 s anywhere on the map — ZH retail in effect (Radar.cpp:1302-1318 bug; kept on purpose by GGC Radar.cpp:1193-1196)   b) Once every 10 s per area (about 250 units), so a second attack elsewhere still flashes — ZH as written (Radar.cpp:1302-1303), AoE IV merges nearby attacks (update 17718)   c) Every hit flashes
   Recommendation: b, because in 3v3 a raid on your expansion during a main-base fight must not stay hidden for 10 s. Why it matters: the voice line keeps its own 30 s cooldown; this is the visual only.

Q2. Should the settings menu offer a health-bar choice?
   a) No, fixed: selected or damaged (current answer, AoE IV "Smart")   b) Yes: "Selected or damaged" (default) or "Always" — AoE IV patch 5.1.148, OpenRA Settings.cs:26   c) Yes, with also "Selected only" — SC2 2.0.4, ZH-like
   Recommendation: b, because some players want every bar during big fights and it is one setting; c adds an option few would use. Why it matters: no hotkey, comma is taken by idle army.

Q3. How many map pings may one player have at once?
   a) 3 — ZH (multiplayer.ini:37)   b) 1; a new ping replaces your old one — OpenRA (PlaceBeacon.cs:68-74)   c) No limit; old pings fade out
   Recommendation: b, because with 3 teammates the map stays readable and no count needs showing. Why it matters: closes the open "how many" answer.

Q4. How long should a ping stay on the map?
   a) Until the player removes it (ZH beacon lifetime: not checked)   b) 30 s — OpenRA (PlaceBeacon.cs:21, mod.yaml:297-299)   c) 3 s flash — AoE2 DE flare (learn-to-play page)   d) 60 s — BAR (map_auto_mapmark_eraser.lua:15)
   Recommendation: b, because long enough to look and react, short enough that nobody clears pings. Why it matters: a ping is a lockstep command; the lifetime runs on ticks.

Q5. Should a ping say what it means, without text?
   a) Plain ping only (current answer)   b) Pick one of four icons: Attack, Defend, On my way, Retreat — SC2 3.0.3 "Advanced Ping"
   Recommendation: a for M7.6, because one gesture is enough to start and an icon kind can be added later to the same command. Why it matters: b needs a radial menu and four icons.

Q6. Should your minimap also show when a teammate is attacked?
   a) No, only your own objects — ZH (Object.cpp:1877)   b) Yes, in a different colour — AoE IV ("Ally under attack ping changed from red to blue", update 17718)
   Recommendation: b, because in 3v3 helping a teammate in time is half the game. Why it matters: needs the same per-area limit as Q1, or allied fights flood your minimap.

Q7. Which idle buttons should the HUD show?
   a) Idle builder button with a count — ZH (ControlBar.cpp:1202-1205, InGameUI.cpp:5578-5597)   b) a) plus an idle army button with a count — SC2 2.0.4 "Select Army", AoE IV idle military (update 17718)
   Recommendation: b, because the comma hotkey for idle army is already decided and a button makes it visible to new players. Why it matters: clicking does what period/comma do; no new command.

Q8. Should the HUD show your control groups?
   a) Group number next to the unit's health bar only — ZH (Drawable.cpp:3124-3157)   b) a) plus a row of group buttons with unit count, click selects — SC2 (patch 1.3.0), BAR (gui_unitgroups.lua)
   Recommendation: b, because large 3v3 armies spread over several groups and the row shows which groups exist and are alive. Why it matters: needs a headless layout test like any HUD change.

Q9. Should there be an overview of everything your buildings are producing?
   a) No; select a building to see its queue — ZH   b) A small strip with each factory's current item and progress; click jumps to the factory — AoE IV "global build queue" (update 17718)   c) b) plus queueing from the strip — BAR BuildBar (gui_buildbar.lua:6, off by default)
   Recommendation: b, because it saves camera trips in long games without becoming a second build menu. Why it matters: c duplicates the build buttons and their hotkeys.

Q10. How should "keep formation" work?
   a) Ctrl+F groups the selected units; they keep their spacing and move at the slowest member's speed — ZH (GameLogicDispatch.cpp:885-889, AIGroup.cpp:399-443, 1097-1105)   b) Draw a line with a drag to place units along it — BAR (cmd_customformations2.lua:22), needs another button since right-drag pans   c) Formations on every group move — AoE IV, AoE2 DE
   Recommendation: a, because it is opt-in and leaves normal movement and the replay traces unchanged; c is a movement gameplay change. Why it matters: a is a new command with same-tick cases.

Q11. Should the unit under the mouse also show its health bar?
   a) Yes — ZH (Drawable.cpp:3855-3859), OpenRA (SelectionDecorationsBase.cs:80-81)   b) No, only selected or damaged (current answer)
   Recommendation: a, because hovering an enemy to read its health is free information both games give. Why it matters: one extra condition in the bar drawing.

Q12. Should allied health bars use team colours?
   a) No, one colour for all — ZH (**inferred**, not checked), Wargrid today (world_view.gd:254)   b) Yes, coloured by own / ally / enemy — SC2 2.0.4 "Display Team Colored Life Bar"
   Recommendation: b, because in a 3v3 brawl you must tell your units from your teammates' at a glance. Why it matters: must fit the decided selection colours of M7.5.

## Answers (2026-11-09)
Answered on a click page: Q1 b, Q2 a (against the recommendation), Q3 b, Q4 b, Q5 a, Q6 b, Q7 a (against the recommendation), Q8 b, Q9 b, Q10 a, Q11 a, Q12 c (compromise added on the page). Recorded in the [design answers](../reference/design-answers-2026-11-08.md#hud-m76).

## Source check (2026-11-09)
A Sonnet agent fetched every cited page (10 web pages, 7 BAR files, all reachable): 26 claims confirmed, 2 partly (the AoE IV formation line above; and Q10's "formations on every group move" option: neither the AoE IV nor the AoE2 DE page says every group move uses formations), none unsupported. Still unsourced or inferred as marked: Company of Heroes 3, Zero Hour beacon lifetime, Q12's Zero Hour colour, the unread BAR widgets. Table with quotes kept outside the repo (session scratchpad).
