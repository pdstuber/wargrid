FROM alpine:3.24 AS compress
RUN apk add --no-cache brotli
WORKDIR /site
# Precompress once at build time: the 40 MB wasm would otherwise be recompressed on every request.
# The wasm is the Godot template, unchanged until an engine upgrade: its own layer keeps the slow q11 pass cached.
COPY site/index.wasm .
RUN brotli -k -q 11 index.wasm && gzip -k -9 index.wasm
COPY site/ .
COPY og.png .
# q9: the pack changes every commit and q11 saves only about 1 % of it (docs/reference/web-deploy-time.md).
RUN for f in index.pck index.js index.html; do brotli -k -q 9 "$f" && gzip -k -9 "$f"; done

FROM joseluisq/static-web-server:2.44.1
COPY --from=compress /site /public
COPY sws.toml /sws.toml
ENV SERVER_PORT=8080 SERVER_HEALTH=true SERVER_COMPRESSION_STATIC=true SERVER_CACHE_CONTROL_HEADERS=false SERVER_CONFIG_FILE=/sws.toml
USER 65534:65534
