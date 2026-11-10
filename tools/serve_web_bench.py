import functools
import http.server
import sys
import time
from pathlib import Path

args = [a for a in sys.argv[1:] if a != "--no-isolation"]
isolated = len(args) == len(sys.argv) - 1
if len(args) < 2:
    sys.exit("usage: python3 -I tools/serve_web_bench.py EXPORT_DIR RESULTS_DIR [PORT] [--no-isolation]")
root, results = Path(args[0]), Path(args[1])
port = int(args[2]) if len(args) > 2 else 8060


class Handler(http.server.SimpleHTTPRequestHandler):
    # Cross-origin isolation lifts the browsers' 1 ms timer rounding.
    def end_headers(self) -> None:
        if isolated:
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
