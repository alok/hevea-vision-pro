#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Serve the local demo without stale development assets."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from functools import partial
import argparse


class Server(ThreadingHTTPServer):
    # The default listen backlog of 5 is shorter than one page load's burst of module requests; on macOS the excess
    # connections were reset (ERR_CONNECTION_RESET on a fresh load). 128 is the macOS kern.ipc.somaxconn cap.
    request_queue_size = 128


class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument("--directory", type=Path, default=Path(__file__).parent)
    args = parser.parse_args()
    handler = partial(Handler, directory=str(args.directory))
    print(f"Farey preview: http://127.0.0.1:{args.port}", flush=True)
    try:
        Server(("127.0.0.1", args.port), handler).serve_forever()
    except KeyboardInterrupt:
        pass
