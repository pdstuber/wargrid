# Playing online (M5 spike)

Two players, one match, through the relay. Both need the same build; a different build is refused with a version error.

## Install

1. Download the build for your system from the link the host sends you and unpack it.
2. **macOS:** the app is ad-hoc signed, not notarized. Right-click the app and choose Open. If macOS blocks it anyway (newer macOS versions may not offer Open on the first try), open System Settings → Privacy & Security and choose Open Anyway. Not verified on a current macOS yet.
3. **Windows:** SmartScreen warns about an unknown publisher. Choose More info → Run anyway.
4. **Linux:** `chmod +x` the binary and run it.

## Play

1. The launcher opens. The relay URL is prefilled; leave it unless the host says otherwise.
2. One player presses **Create match** and reads the 6-character code (`Match code: XXXXXX — waiting for player 2`) to the other.
3. The other player types the code and presses **Join**. The match starts at once. The creator is player 1 (blue), the joiner player 2 (red).
4. **Play offline** starts the normal single-player skirmish.

Controls are the same as offline. Restart is hidden online.

## Status lines

| Line | Meaning |
|---|---|
| `Waiting for player N` | Their input for the next tick has not arrived. The game resumes by itself. |
| `Player N disconnected` | The other player left or lost connection. The match stops. |
| `Connection to relay lost` | No data from the relay for 5 s, or the socket closed. The match stops. |
| `Relay: <reason>` | The relay refused or ended the session (full match, wrong code, version mismatch). |
| `Desync — report saved to <path>` | The two games disagreed. The match stops and the report is written. |
| `Protocol error: <reason>` | A malformed frame arrived. The match stops. |

## Reports and latency

- Desync report: `desync-seat<N>.json` in the `desync` folder of the game's user data directory (the status line prints the full path). Send both players' files to the host.
- At the end of a match the game prints and saves command latency (p50/p95) and relay round-trip p95 to `netplay-latency.txt` in the same user data directory.
