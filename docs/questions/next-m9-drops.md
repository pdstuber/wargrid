# Next: M9 dropped, quitting and defeated players

Sources. **ZH src** = ~/projects/CnC_Generals_Zero_Hour @ 0a05454, paths under `GeneralsMD/Code/GameEngine/Source/`. **INI** = retail root `INIZH.big` decoded into the session scratchpad, cited as archive entry:line. Already decided or proposed, not asked: the blueprint lists "pause, or the player becomes a bot" as the drop options to choose from (§7 M9); relay reconnect by replaying the room's command log is a proposed design (§7 M9 "Relay beyond one machine"); bots never give up. Wargrid today: offline the Esc menu pauses, online the simulation keeps stepping and leaving disconnects this client; a forfeit message is deferred to M9 (wargrid `docs/development.md:51`).

## Findings (short, cited)
- **source** Stall: when the game waits on a player for 5 s, a disconnect screen appears for everyone (`NetworkDisconnectTime = 5000`, `data\ini\gamedata.ini:458`). After 15 s on that screen the others are notified (`NetworkDisconnectScreenNotifyTime = 15000`, :460). A player with no keep-alive for 60 s is dropped (`NetworkPlayerTimeoutTime = 60000`, :459; ZH src GameNetwork/DisconnectManager.cpp:209-248).
- **source** Vote: the others can vote a stalled player out; it needs votes from every other player (`numVotes >= numPlayers - 1`, DisconnectManager.cpp:727-738).
- **source** A dropped player (timed out or voted out) is destroyed: `DestroyPlayer` becomes a self-destruct with "no transfer", which kills all their units and buildings (DisconnectManager.cpp:706-721; GameNetwork/Network.cpp:659-673; GameLogic/System/GameLogicDispatch.cpp:1786-1820).
- **source** A player who quits from the menu, or surrenders, hands everything to a living ally: units, buildings and money (`transferAssetsFromThat`, Common/RTS/Player.cpp:2132-2172; GameLogicDispatch.cpp:1789-1808; GUICallbacks/Menus/QuitMenu.cpp:140-149, 185-197). With no living ally, everything is destroyed (GameLogicDispatch.cpp:1809-1813).
- **source** In multiplayer the menu's Restart button becomes Surrender; you cannot surrender once dead or after your team has won; the menu does not pause the game online (QuitMenu.cpp:409-439).
- **source** A defeated player sees the whole map from then on, the minimap is forced on, everyone gets a "player has been defeated" message with a sound, and their remaining units are destroyed (GameLogic/ScriptEngine/VictoryConditions.cpp:189-221, 229-238).
- **not found** Rejoining a running match after a drop (only buddy-chat reconnects, GameNetwork/GameSpyGP.cpp:49-51).

## Questions
Q1. When one player's connection stalls, what should the others see?
   a) The game freezes for everyone and a "waiting for player" screen appears after 5 s — ZH default (gamedata.ini:458)   b) The game keeps running; the stalled player's units stand still   c) The game freezes with no screen
   Recommendation: a, because lockstep must freeze anyway and players need to know why. Why it matters: Wargrid's netplay already stalls; this is the screen on top.

Q2. How long until a silent player is dropped automatically?
   a) 60 s without any contact — ZH default (gamedata.ini:459)   b) 30 s   c) Never automatically; only by vote
   Recommendation: a, because it is ZH and long enough for a short network blip or a browser tab switch. Why it matters: a browser tab in the background stalls everyone (development.md, unverified case).

Q3. Can the others vote a stalled player out before the timeout?
   a) Yes, and it needs every other player's vote — ZH default (DisconnectManager.cpp:727-738)   b) Yes, a simple majority   c) No votes, only the timeout
   Recommendation: a, because it is ZH and one troll cannot kick a friend. Why it matters: votes are a relay-side or lockstep-side message to design.

Q4. What happens to a dropped player's units and buildings?
   a) They are destroyed — ZH default (Network.cpp:659-673, GameLogicDispatch.cpp:1786-1820)   b) A bot takes them over at the match's bot level (blueprint option)   c) They go to a living teammate
   Recommendation: b, because in friends-versus-bots a 2v3 after one drop is no fun, and the blueprint already lists it. Why it matters: b needs a bot that can start mid-match from any state.

Q5. What happens when a player leaves on purpose (quits from the menu)?
   a) A living teammate gets all their units, buildings and money — ZH default (Player.cpp:2132-2172, QuitMenu.cpp:140-149)   b) Same as a drop (Q4)   c) Everything is destroyed
   Recommendation: a, because it is ZH and keeps the team at full strength. Why it matters: online "Back to main menu" must send this as a command before closing.

Q6. Can a player surrender during an online match?
   a) Yes, from the menu; it works like quitting (assets to a teammate) and the player stays to watch — ZH default (QuitMenu.cpp:185-197, 409-439)   b) No surrender, only quit   c) Only the whole team can surrender together
   Recommendation: a, because it is ZH and gives a clean way out of a lost game. Why it matters: one new lockstep command with same-tick cases (surrender versus own building destroyed in the same tick).

Q7. Can an online match be paused?
   a) No, the menu does not pause online — ZH default (QuitMenu.cpp:409-439) and Wargrid today   b) Yes, any player can pause; anyone can resume   c) Yes, with a limited number of pauses per player
   Recommendation: a, because it is ZH and already built. Why it matters: b or c need a pause command in the lockstep stream.

Q8. What does a defeated player see?
   a) The whole map, minimap on, as an observer — ZH default (VictoryConditions.cpp:195, 236)   b) Only what their team still sees   c) Nothing; the match ends for them
   Recommendation: a, because it is ZH and fun to watch; online the defeated player's client must keep stepping. Why it matters: the defeated player must not pass information to teammates; with a, they could over voice.

Q9. When a player is defeated, what happens to their leftover units?
   a) They are destroyed at once — ZH default (VictoryConditions.cpp:220 `killPlayer`)   b) They stay and fight on with no owner control   c) They go to a teammate
   Recommendation: a, because it is ZH and matches Wargrid's "a seat survives while it owns a victory building". Why it matters: decides what "defeated" means for leftover infantry.

Q10. Should everyone get a message when a player is defeated or drops?
   a) Yes, a text line plus a sound — ZH default (VictoryConditions.cpp:196-201)   b) Text only   c) Announcer voice line
   Recommendation: c, because the sound spike added a vocoder announcer and this is a key event. Why it matters: needs one new announcer line.

Q11. Should a dropped player be able to rejoin the running match?
   a) No rejoin — ZH (none found)   b) Yes, by replaying the match's commands (proposed relay design)   c) Later, after M9's exit gate
   Recommendation: c, because the 3v3 exit gate does not need it and replaying a long match in the browser may be slow. Why it matters: changes what the relay must store per room.
