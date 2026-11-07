# Test environment: design

Small separate task, not a milestone. Approved approach: 1 (user, 2026-11-07).

## Intent

Give friends a browser link to an unreleased build for playtests, without touching the live site.

## Goals

- `sh tools/deploy_web.sh test` exports the web build from the local tree and deploys it to fly app `wargrid-web-test` (`https://wargrid-web-test.fly.dev/`).
- A test build can never share a relay room with a production build.

## Non-goals (user, 2026-11-07)

- No test relay: test builds use the production relay `wargrid-relay-jvm`. The relay puts only clients with equal `build` strings in a room (`relay/room.go`), so test and production players never meet.
- No custom domain; `*.fly.dev` is enough.
- No GitHub automation or `test` Environment; the deploy runs locally.

## Design

- `tools/deploy_web.sh` takes an optional argument `test`. Without it, it deploys `wargrid-web` as today; with it, `wargrid-web-test`. Same export, Dockerfile, `fly.toml` (app overridden with `-a`) and `--ha=false`.
- Guard, before exporting: `test` refuses unless `config/version` in `game/project.godot` contains `-` (prerelease, e.g. `0.7.0-dev`). My call: the production path refuses a version with `-`, so a dev build can't go live by hand either. Same rule as `tools/release_version.py`'s `is_prerelease`.
- Convention: right after a release, `main` gets bumped to the next `-dev` version (now: `0.7.0-dev`). This also keeps local dev builds out of production rooms.
- After the deploy, `curl` the test site's `/health`, as `release.yml` does for production. My call.
- README's command list gets the `test` line.

## Approaches considered

1. **Chosen.** App-name argument plus prerelease guard. About 5 lines. Limit: two test deploys with the same `-dev` version share a build string. Only an old tab kept open across a redeploy could join the new build and desync. Accepted for playtests among friends.
2. A git hash stamped into the build string at export. Unique per deploy and no version bump needed, but it rewrites the tracked `project.godot` during the export and must restore it on every exit path. Rejected as fragile.
3. A separate `deploy_web_test.sh`. Rejected: duplicates the export.

## Setup (user, once)

`fly apps create wargrid-web-test`. Deploys need explicit approval, as today.

## Left to the builder

- How to read the version in sh (`sed -n` on `config/version`, matching `release_version.py`'s regex).
- Whether the `0.7.0-dev` bump lands on `main` with this change or separately. `m7-factions` carries its own version line.
