# Next: M9 lobby rules and match options

Sources. **ZH src** = ~/projects/CnC_Generals_Zero_Hour @ 0a05454, paths under `GeneralsMD/Code/GameEngine/Source/` (headers `Include/`). **INI** = retail root `INIZH.big` decoded into the session scratchpad, cited as archive entry:line. Already decided, not asked: lobby look from the mockup (map list, your team with two friend slots, bot team, one bot difficulty 1-5 and one play style for all bots, Create match with a code, Join by code), relay stack, A/B pages for layout (blueprint §7 M9). Morning-summary questions not repeated: map dropdown row, relay settings cap, Credits `get_copyright_info()`.

## Findings (short, cited)
- **source** Start spots: a pre-chosen spot is taken first but never recorded as its team's position; only slots placed by the random loop set `teamPosIdx` (ZH src GameLogic/System/GameLogic.cpp:957-959, 977, 1018). So the teammate of a player who picked a spot is placed far away (largest summed distance), not next to them. Wargrid's `StartSpots.assign` copies this and test SS7 pins it (wargrid `docs/superpowers/plans/2026-11-08-converted-maps-playable.md:15, 159`).
- **source** Each lobby slot has faction, colour, start spot and team; a slot can be open, closed, human or computer at any level, on any team (Include/GameNetwork/GameInfo.h:66-120). Team "none" is allowed (start-spot rule treats it as no team, GameLogic.cpp:979-1019).
- **source** Random choices: "Random" is offered for faction, colour and start spot (`data\ini\multiplayer.ini:39-41`); random factions and colours are drawn from the seeded game random at start, and two players never get the same colour (GameLogic.cpp:682-806). There are 8 colours (multiplayer.ini, 8 `MultiplayerColor` blocks).
- **source** Starting money choices 5,000 / 10,000 (default) / 20,000 / 50,000 (multiplayer.ini:92-108; default also `data\ini\gamedata.ini:440`). Wargrid starts everyone at 10,000 (wargrid `game/scripts/simulation/skirmish.gd:10`). The only other ZH game option is a superweapon limit (GameInfo.h:200-203).
- **source** Observer slots exist; an observer sees the whole map from the start (GameLogic.cpp:1744-1748).
- **source** Every human must tick "Accept"; changing options clears everyone's accept (GameInfo.h:66-68); the host's start then counts down 5 s (`StartCountdownTimer = 5`, multiplayer.ini:36).
- **source** Skirmish Restart starts the same map again with the same game info (ZH src GameClient/GUI/GUICallbacks/Menus/QuitMenu.cpp:200-250); start spots chosen at the first start were written into that game info (GameLogic.cpp:974, 1015, 1034 `slot->setStartPos`). **inferred** Restart keeps the same starts, matching Wargrid's offline Restart (converted-maps finding 2).
- **source** In-game chat exists, to allies or everyone; a defeated player can only chat to everyone (ZH src GameLogic/ScriptEngine/VictoryConditions.cpp:236-237; GUICallbacks/InGameChat.cpp).

## Questions
Q1. If a player picks a start spot and a teammate's spot is random, where does the teammate start?
   a) Far away, as if the picked spot did not belong to the team — ZH default (GameLogic.cpp:957-959, 977, 1018; pinned by SS7)   b) Next to the picked spot (the closest free start)   c) Random among the free starts
   Recommendation: b, because ZH's behaviour looks like an oversight and teammates expect to start together. Why it matters: one changed line in `StartSpots.assign` and a re-pinned SS7.

Q2. Can players pick their start spot in the lobby?
   a) Yes, by clicking a spot on the map preview, or leave it on "Random" — ZH default (multiplayer.ini:40, GameInfo.h:81-82)   b) No, always random   c) Only the host picks for everyone
   Recommendation: a, because the mockup already shows the starting positions on the map. Why it matters: feeds the `chosen` input that `StartSpots.assign` already takes.

Q3. Can humans play against humans in the 3v3 lobby?
   a) Yes, any slot can be any human or bot on any team — ZH default (GameInfo.h:66-120)   b) No, always friends versus bots, as in the mockup   c) Later, after the friends-versus-bots version works
   Recommendation: c, because the mockup and the 3v3 exit gate are friends versus bots; mixed teams change the lobby layout. Why it matters: decides if the lobby has two fixed panels or free slots.

Q4. Can a friend slot be filled by a bot?
   a) Yes, any open slot can take a bot — ZH default (GameInfo.h:73-75 slot states)   b) No, friend slots are humans only; empty slots stay empty   c) Empty friend slots are filled by bots automatically at start
   Recommendation: a, because two friends then still get a 3v3. Why it matters: a bot on the human team needs the same team-vision coordination as on the bot team.

Q5. Should starting money be a lobby option?
   a) Yes: 5,000 / 10,000 / 20,000 / 50,000, default 10,000 — ZH default (multiplayer.ini:92-108)   b) No, always 10,000 (today)   c) Yes, 10,000 or 20,000 only
   Recommendation: a, because it is ZH and Wargrid already starts at 10,000. Why it matters: one field in the opaque `settings`; bots must not assume 10,000.

Q6. Can players choose their colour?
   a) Yes, 8 colours or "Random", never two the same — ZH default (multiplayer.ini colour blocks, GameLogic.cpp:682-806)   b) No, colours fixed by slot   c) Team colours only (all allies one colour)
   Recommendation: a, because it is ZH and helps friends tell each other apart. Why it matters: colours must be deterministic from the seed when random.

Q7. Can a player choose "Random" as faction?
   a) Yes, drawn at start from the match seed — ZH default (multiplayer.ini:39, GameLogic.cpp:718-786)   b) No
   Recommendation: a, because it is ZH and cheap. Why it matters: the draw must happen on every lockstep client from the relay seed.

Q8. Should the lobby allow observers who watch with the whole map revealed?
   a) Yes, observer slots that see everything — ZH default (GameLogic.cpp:1744-1748)   b) No observers   c) Later
   Recommendation: c, because the relay and lockstep would carry a non-playing seat; not needed for the 3v3 exit gate. Why it matters: an observer seat changes the relay's room size.

Q9. How does a match start once everyone is in?
   a) Every human ticks "Accept"; any option change clears all accepts; then the host starts and a 5 s countdown runs — ZH default (GameInfo.h:66-68, multiplayer.ini:36)   b) The host starts whenever all slots are filled   c) It starts on its own when all slots are filled
   Recommendation: a, because it stops a host changing the map at the last second. Why it matters: adds a ready state per slot to the lobby protocol.

Q10. Should offline Restart keep the same start spots?
   a) Yes, the same starts as the first start — ZH (QuitMenu.cpp:200-250, GameLogic.cpp:974-1034; inferred) and what the converted-maps run built   b) No, draw new starts from a new seed
   Recommendation: a, because it matches ZH and is already built. Why it matters: confirms a choice the plan made without you.

Q11. Should there be in-game chat?
   a) Yes, to allies or to everyone; a defeated player chats to everyone only — ZH default (VictoryConditions.cpp:236-237)   b) Allies only   c) No chat; use voice outside the game
   Recommendation: c for M9, because friends usually talk on voice and chat needs text input in the browser build too; revisit later. Why it matters: chat messages would ride the relay outside the lockstep commands.

Q12. Can a teammate use a map with fewer starts than players?
   a) No: the lobby only offers maps with at least as many starts as filled slots — ZH (slot count limited by `m_numPlayers`, GameLogic.cpp:815-819; inferred for the lobby)   b) Yes, players share starts
   Recommendation: a, because Dry Wells has only 2 starts and a 3v3 needs 6. Why it matters: the mockup's "Ashfall supports this 6-player setup" line needs this rule.
