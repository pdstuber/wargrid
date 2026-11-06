import functools
import http.server
import sys
import time
from pathlib import Path

if len(sys.argv) < 3:
    sys.exit("usage: python3 -I tools/serve_web_bench.py EXPORT_DIR RESULTS_DIR [PORT]")
root, results = Path(sys.argv[1]), Path(sys.argv[2])
port = int(sys.argv[3]) if len(sys.argv) > 3 else 8060


class Handler(http.server.SimpleHTTPRequestHandler):
    # Cross-origin isolation lifts the browsers' 1 ms timer rounding.
    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def do_POST(self) -> None:
        if self.path != "/result":
            self.send_error(404)
            return
        body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        results.mkdir(parents=True, exist_ok=True)
        (results / f"web-{time.strftime('%Y%m%d-%H%M%S')}.log").write_bytes(body)
        self.send_response(204)
        self.end_headers()


http.server.ThreadingHTTPServer(("127.0.0.1", port), functools.partial(Handler, directory=str(root))).serve_forever()
