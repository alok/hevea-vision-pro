// SPDX-License-Identifier: GPL-3.0-or-later
// The local server must accept one page load's burst of simultaneous module requests without resetting connections.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { connect } from 'node:net';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const root = dirname(fileURLToPath(import.meta.url));
const port = 20000 + Math.floor(Math.random() * 20000);

const request = () => new Promise(done => {
  const socket = connect(port, '127.0.0.1');
  let data = '';
  socket.on('connect', () => socket.end('GET /serve.py HTTP/1.1\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n'));
  socket.on('data', chunk => { data += chunk; });
  socket.on('error', error => done(error.code));
  socket.on('close', () => done(data.startsWith('HTTP/1.0 200') ? 'ok' : data ? 'other' : 'empty'));
});

test('serve.py answers a burst of 60 simultaneous connections', async () => {
  const server = spawn('python3', [resolve(root, 'serve.py'), '--port', String(port), '--directory', root], { stdio: ['ignore', 'pipe', 'pipe'] });
  try {
    await new Promise((ready, fail) => { server.stdout.once('data', ready); server.once('exit', code => fail(Error(`serve.py exited ${code}`))); });
    const results = await Promise.all(Array.from({ length: 60 }, request));
    assert.deepEqual(results.filter(result => result !== 'ok'), []);
  } finally { server.kill(); }
});
