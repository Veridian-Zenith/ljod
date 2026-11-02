#!/usr/bin/env python3
"""Serve the rendered screenshots so the browser preview shows current pixels.

The preview panel re-serves the page it was registered with; if the images are
embedded as base64 inside the HTML, a reload shows the *old* bytes until the
HTML itself is rewritten. Serving `screenshots/` over HTTP instead means a
plain reload always fetches whatever PNG is on disk right now.

It serves the same files README.md embeds, not a copy, so the preview cannot
describe a build the documentation no longer shows.

Usage:
    python3 tool/screenshots/serve.py [port]

Then register the printed URL as a preview. Regenerate the images with:
    flutter test tool/screenshots/screens_test.dart --update-goldens
"""

from __future__ import annotations

import functools
import http.server
import pathlib
import socketserver
import sys

ROOT = pathlib.Path(__file__).resolve().parent
SCREENS = ROOT.parent.parent / "screenshots"

CAPTIONS = {
    "home.png": "Home — mini player bar",
    "library.png": "Library — tracks, albums and recently added",
    "player.png": "Player — seek bar and transport controls",
    "lyrics.png": "Lyrics sheet — synced lines follow playback",
    "insights.png": "Insights — plays, artists and listening time",
    "settings.png": "Settings — appearance, scan and storage",
    "diagnostics.png": "Diagnostics — warnings and errors only",
}


class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self) -> None:  # noqa: N802 - stdlib naming
        if self.path in ("/", "/index.html"):
            self._index()
            return
        super().do_GET()

    def translate_path(self, path: str) -> str:
        # `/screenshots/<name>.png` is served from the repository's screenshots
        # directory; nothing else in the project is exposed.
        if path.startswith("/screenshots/"):
            name = path.split("?", 1)[0].rsplit("/", 1)[-1]
            return str(SCREENS / name)
        return super().translate_path(path)

    def _index(self) -> None:
        known = [SCREENS / name for name in CAPTIONS]
        images = [p for p in known if p.exists()]
        images += sorted(
            p for p in SCREENS.glob("*.png") if p.name not in CAPTIONS
        )
        cards = "\n".join(
            f'<figure><figcaption>{CAPTIONS.get(p.name, p.name)}</figcaption>'
            f'<img src="/screenshots/{p.name}?v={int(p.stat().st_mtime)}"></figure>'
            for p in images
        )
        body = f"""<!doctype html><meta charset="utf-8"><title>Ljod screens</title>
<style>
 body{{margin:0;background:#101014;color:#F4F1E8;font:13px system-ui,sans-serif}}
 .col{{padding:10px}} figure{{margin:0 0 16px}} figcaption{{color:#FFB347;padding:4px 0}}
 img{{display:block;width:390px;height:auto;border:1px solid #2B2A30;border-radius:8px}}
 .empty{{padding:24px;color:#7A756C}}
</style>
<div class="col">{cards or '<p class="empty">No screenshots yet — run:<br>'
                         '<code>flutter test tool/screenshots/screens_test.dart '
                         '--update-goldens</code></p>'}</div>"""
        payload = body.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(payload)

    def end_headers(self) -> None:
        # Goldens are rewritten in place; a cached copy hides every fix.
        self.send_header("Cache-Control", "no-store, must-revalidate")
        super().end_headers()

    def log_message(self, fmt: str, *args: object) -> None:
        sys.stderr.write(f"{self.address_string()} {fmt % args}\n")


def main() -> None:
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    handler = functools.partial(Handler, directory=str(ROOT))
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("127.0.0.1", port), handler) as server:
        print(f"serving {ROOT} on http://127.0.0.1:{port}/", flush=True)
        server.serve_forever()


if __name__ == "__main__":
    main()
