#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Build/check a local artifact in isolated headless profiles; never install tools."""
import argparse
from functools import partial
from http.server import ThreadingHTTPServer
import json
from pathlib import Path
import shlex
import shutil
import subprocess
import threading
import uuid
from urllib.parse import quote

from serve import Handler


class QuietHandler(Handler):
    def log_message(self, format, *args):
        pass


def main():
    root = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--artifact', type=Path, help='Check an existing artifact instead of rebuilding dist')
    parser.add_argument('--at-root', action='store_true', help='Serve at / instead of under the artifact directory name')
    parser.add_argument('--cli', default='playwright-cli', help='Already installed Playwright CLI command; shell quoting is accepted, no shell is run')
    parser.add_argument('--output', type=Path, default=root / 'output/playwright/offline-package')
    args = parser.parse_args()
    cli = shlex.split(args.cli)
    if not cli or not shutil.which(cli[0]):
        parser.error('Install Playwright CLI and its browser separately, or pass --cli. This check does not download tools.')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)

    def run(command, name):
        result = subprocess.run(command, cwd=root, text=True, capture_output=True, timeout=180)
        (output / f'{name}.log').write_text(result.stdout + result.stderr)
        if result.returncode:
            raise RuntimeError(f'{name} failed; see {output / (name + ".log")}')
        return result.stdout

    if args.artifact:
        artifact = args.artifact.resolve()
    else:
        run(['npm', 'run', 'build'], 'build')
        artifact = root / 'dist'
    static = json.loads(run(['node', str(root / 'package-smoke.mjs'), str(artifact)], 'static'))
    directory = artifact if args.at_root else artifact.parent
    server = ThreadingHTTPServer(('127.0.0.1', 0), partial(QuietHandler, directory=str(directory)))
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    session = f'farey-offline-{uuid.uuid4().hex[:10]}'
    path = '/' if args.at_root else f'/{quote(artifact.name)}/'
    url = f'http://127.0.0.1:{server.server_port}{path}'
    try:
        # No --persistent or --headed: this cannot take over the user's profile/window.
        run([*cli, f'-s={session}', 'open', url], 'open')
        raw = run([*cli, f'-s={session}', 'run-code', '--filename', str(root / 'offline-checks.js')], 'browser')
        marker = '### Result\n'
        if marker not in raw:
            raise RuntimeError(f'Browser did not return a result; see {output / "browser.log"}')
        browser, _ = json.JSONDecoder().raw_decode(raw.split(marker, 1)[1])
        if browser.get('passed') is not True:
            raise RuntimeError(f'Browser check failed: {browser}')
        result = {'artifact': str(artifact), 'version': json.loads((artifact / 'source/package.json').read_text())['version'],
                  'static': static, 'browser': browser}
        (output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
        for name in ['offline-desktop.png', 'offline-mobile-390.png', 'offline-mobile-844.png', 'offline-no-webgl.png', 'offline-no-module.png', 'offline-no-js.png']:
            shutil.copy2(root / 'output/playwright' / name, output / name)
        print(json.dumps(result, indent=2))
    finally:
        try:
            run([*cli, f'-s={session}', 'close'], 'close')
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=5)


if __name__ == '__main__':
    main()
