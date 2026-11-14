"""Serve only this worktree's local Flutter home fixture with external IO blocked.

Usage: python3 tool/fixtures/home_shadcn_server.py 8894
Build tool/fixtures/home_shadcn.dart first. The CSP also blocks Google Sign-In's
shared web plugin bootstrap; no sign-in is needed by this isolated fixture.
"""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import sys


class FixtureHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        self.send_header(
            "Content-Security-Policy",
            "default-src 'self' data: blob:; "
            "script-src 'self' 'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval'; "
            "style-src 'self' 'unsafe-inline'; connect-src 'self'; "
            "img-src 'self' data: blob:; font-src 'self' data:; "
            "worker-src 'self' blob:; frame-src 'none'; object-src 'none'",
        )
        super().end_headers()


if __name__ == "__main__":
    directory = Path(__file__).resolve().parents[2] / "build" / "web"
    port = int(sys.argv[1])
    handler = partial(FixtureHandler, directory=str(directory))
    print(f"Home local fixture: http://127.0.0.1:{port}", flush=True)
    ThreadingHTTPServer(("127.0.0.1", port), handler).serve_forever()
