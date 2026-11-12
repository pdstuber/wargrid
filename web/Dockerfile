FROM alpine:3.24 AS compress
RUN apk add --no-cache brotli
WORKDIR /site
COPY site/ .
COPY og.png .
# Precompress once at build time: the 40 MB wasm would otherwise be recompressed on every request.
RUN for f in index.wasm index.pck index.js index.html; do brotli -k -q 11 "$f" && gzip -k -9 "$f"; done

FROM joseluisq/static-web-server:2.44.1
COPY --from=compress /site /public
COPY sws.toml /sws.toml
ENV SERVER_PORT=8080 SERVER_HEALTH=true SERVER_COMPRESSION_STATIC=true SERVER_CACHE_CONTROL_HEADERS=false SERVER_CONFIG_FILE=/sws.toml
USER 65534:65534
