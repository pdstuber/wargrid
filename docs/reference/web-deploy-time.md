# Web deploy time: where it goes (2026-11-13)

Status: findings and one recommendation. Nothing was changed. Tree: `3ecdd3c`, clean.

## The short version

- **One Docker build step is 84 % of the deploy.** The `Deploy web` step of the 0.11.0 release run took 199 s; 166 s of that is the precompression line in `web/Dockerfile` (`brotli -q 11` plus `gzip -9`).
- **Most of that work is repeated on identical input.** `index.wasm` is the Godot export template: the same bytes on every deploy until the engine version or the export template changes. It is recompressed every time because it shares a layer with the pack file, which changes with every commit.
- **Recommendation:** give the wasm its own cached layer and compress the pack at quality 9. Expected deploy time about 40 s instead of about 200 s (estimate), for 121 KB more download per player.
- Everything outside the Docker build is already fast. No work needed there.

Labels: **measured** (command or log named), **estimate** (computed from measured numbers, not timed).

## Where the time goes

`sh tools/deploy_web.sh` exports the web build, adds the licence files, then runs `fly deploy`, which builds the image on fly's remote builder (Depot, per the CI log).

| Stage | Time | Label and source |
|---|---|---|
| Godot web export (`tools/export_build.sh Web`) | 1.5 s | measured, development Mac, import cache present |
| Licence dump (`tools/godot_licenses.gd`) | 0.2 s | measured, development Mac |
| Build context upload (53 MB) | 6 s | measured, CI log |
| Precompression (`web/Dockerfile`, the `RUN for f in …` line) | **166 s** | measured, CI log |
| Image export | 4 s | measured, CI log |
| Machine update | 14 s | measured, CI log |
| Health check (`curl`) | 2 s | measured, CI log |

CI log: release workflow run 43304990341 (2026-11-12, release 0.11.0), job `publish`, step `Deploy web`, 199 s in total. That step covers the stages from the context upload onward; in CI the export runs in an earlier job. Run 42650538019 (release 0.10.0) took 197 s for the same step. For comparison, `Deploy relay` in the same run took 40 s.

Not measured: a deploy started from the development Mac. No deploy was run for this note, because a fly deploy needs approval. The script uses the same Dockerfile as CI. That it also builds on Depot is assumed, not verified: CI pins flyctl 0.5.5, the development Mac has 0.5.10. The context upload depends on the home connection and may differ from CI's 6 s.

## What the precompression step costs per file

Timed on the development Mac with the files of a fresh export (`brotli -k -q N FILE`, `gzip -k -9 FILE`, one run each). The remote builder needed 166 s for what took about 59 s here, so it is roughly 3 times slower.

| File | Size | brotli q11 | q11 result | brotli q9 | q9 result | gzip -9 |
|---|---|---|---|---|---|---|
| `index.wasm` | 39.5 MB | 41.6 s | 6.90 MB | 1.8 s | 7.89 MB | 1.1 s |
| `index.pck` | 13.3 MB | 15.8 s | 12.23 MB | 2.2 s | 12.35 MB | 0.3 s |
| `index.js` | 280 KB | 0.2 s | 60 KB | under 0.1 s | 64 KB | under 0.1 s |
| `index.html` | 6 KB | under 0.1 s | 2 KB | under 0.1 s | 2 KB | under 0.1 s |

Two things follow.

**The wasm does not change between deploys.** The SHA-256 of `index.wasm` from the 2026-11-12 export equals that of an export of today's tree (both start `fc74679e3b97f768`); `index.js` is identical too. Only `index.pck` and `index.html` differ (the page embeds the pack size). The Dockerfile copies the whole `site/` folder in one step, so the changed pack invalidates the layer and the wasm is compressed again.

**The pack barely compresses.** Quality 11 shrinks it by 8 %, and by only 121 KB more than quality 9, for 13.6 s of extra time here (about 40 s on the builder, estimate).

## Recommendation

Change `web/Dockerfile` only: compress the wasm in its own layer, before the rest of the site is copied, and lower the quality for the other files to 9.

```dockerfile
FROM alpine:3.24 AS compress
RUN apk add --no-cache brotli
WORKDIR /site
# The wasm is the Godot template, unchanged until the engine version changes: its own layer keeps the slow brotli pass cached.
COPY site/index.wasm .
RUN brotli -k -q 11 index.wasm && gzip -k -9 index.wasm
COPY site/ .
COPY og.png .
RUN for f in index.pck index.js index.html; do brotli -k -q 9 "$f" && gzip -k -9 "$f"; done
```

The second stage of the Dockerfile stays as it is.

- **Expected result (estimate):** the precompression step drops from 166 s to under 10 s when the wasm layer is cached, so the whole deploy lands near 40 s. After a Godot upgrade the first deploy pays the slow wasm pass once.
- **Cost to players:** 121 KB more pack download (1 %), plus about 5 KB on `index.js`. The wasm keeps quality 11.
- **Same change speeds up CI:** `.github/workflows/release.yml` deploys with this Dockerfile.

### Alternative not recommended

Quality 9 for every file needs no cache and is one changed number, but the wasm grows from 6.90 MB to 7.89 MB: about 1 MB more on every player's first load.

### Not worth changing

The export, the licence dump, the health check and the build context. A `.dockerignore` would save nothing: `site/` is nearly the whole 53 MB context.

## Open points

- **The gain depends on the builder's layer cache.** The CI log shows the `apk add` layer as `CACHED`, so the cache persists between deploys of `wargrid-web`. Whether `wargrid-web-test` shares that cache is unverified; if not, each app pays the slow pass once per Godot version.
- **Checked locally (review, 2026-11-13, Apple `container` CLI with BuildKit, a copy of `web/`):** the proposed Dockerfile builds and `/site` holds the same file set as today, with `index.wasm.br` at the quality 11 size. On a rebuild with a changed pack and page and a touched wasm timestamp, the wasm copy and its `RUN` were `CACHED` and the remaining loop took 3.6 s. This shows the layer split works on BuildKit; it says nothing about the remote builder's cache.
- **Verification still to do:** apply the change, run `sh tools/deploy_web.sh test` twice and read the step times of the second run; check that the served `index.wasm` still arrives brotli-compressed.
- **Docs to check when applying:** [development notes](../development.md) and [performance and platforms](../guide/12-performance-and-platforms.md) describe the precompression.
