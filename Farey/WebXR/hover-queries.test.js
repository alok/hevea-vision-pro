// SPDX-License-Identifier: GPL-3.0-or-later
import test from 'node:test';
import assert from 'node:assert/strict';
import { HoverQueries } from './hover-queries.js';
import { nearestToRayPacked } from './input.js';
import { enumerateLattice } from './lattice.js';

// Protocol mock: records messages and lets the test answer them in any order, like a real worker but synchronous.
class FakeWorker {
  constructor() { this.sent = []; this.terminated = false; }
  postMessage(message, transfer) { this.sent.push({ message, transfer }); }
  terminate() { this.terminated = true; }
  answer(query, index = nearestToRayPacked(query.origin, query.direction, this.lattice.xyz, this.lattice.count, query.maxAngle, query.minDistance)) {
    this.onmessage({ data: { type: 'result', hand: query.hand, request: query.request, generation: query.generation, index, ms: 1 } });
  }
  get queries() { return this.sent.map(s => s.message).filter(m => m.type === 'query'); }
  get lattice() { return this.sent.map(s => s.message).filter(m => m.type === 'lattice').at(-1); }
}
const setup = () => { let worker; const queries = new HoverQueries(() => (worker = new FakeWorker())); return { queries, worker: () => worker }; };
const lattice = enumerateLattice(8);

test('each lattice generation is copied once and transferred, never the drawn array itself', () => {
  const { queries, worker } = setup();
  assert.ok(queries.request(0, 1, lattice, [0, 0, 0], [0, 1, 0], 0.02, 0, 'ray'));
  worker().answer(worker().queries[0]);
  assert.ok(queries.request(0, 1, lattice, [0, 0, 0], [0, 1, 0], 0.02, 0, 'ray'));
  const copies = worker().sent.filter(s => s.message.type === 'lattice');
  assert.equal(copies.length, 1);
  assert.notEqual(copies[0].message.xyz, lattice.xyz);
  assert.deepEqual(copies[0].transfer, [copies[0].message.xyz.buffer]);
  assert.deepEqual([...copies[0].message.xyz], [...lattice.xyz]);
  assert.equal(queries.copyBytes, lattice.xyz.byteLength);
});
test('at most one query per hand is in flight; hands are independent', () => {
  const { queries, worker } = setup();
  assert.ok(queries.request(0, 1, lattice, [0, 0, 0], [0, 1, 0], 0.02, 0, 'left'));
  assert.equal(queries.request(0, 1, lattice, [0, 0, 0], [1, 1, 0], 0.02, 0, 'left2'), false);
  assert.ok(queries.request(1, 1, lattice, [0, 0, 0], [0, 1, 1], 0.02, 0, 'right'));
  const [left, right] = worker().queries;
  worker().answer(right, 7); worker().answer(left, 3);
  assert.equal(queries.result(0).index, 3); assert.equal(queries.result(0).ray, 'left');
  assert.equal(queries.result(1).index, 7); assert.equal(queries.result(1).ray, 'right');
});
test('late, duplicate and out-of-order answers are ignored', () => {
  const { queries, worker } = setup();
  queries.request(0, 1, lattice, [0, 0, 0], [0, 1, 0], 0.02, 0, 'first');
  const first = worker().queries[0];
  worker().answer(first, 5);
  queries.request(0, 1, lattice, [0, 0, 0], [0, 1, 0], 0.02, 0, 'second');
  worker().answer(first, 99);              // duplicate of an answered request
  assert.equal(queries.result(0).index, 5);
  assert.ok(queries.busy(0));
  worker().answer({ ...worker().queries[1], request: 12345 }, 42);  // answer to a request never made
  assert.ok(queries.busy(0)); assert.equal(queries.result(0).index, 5);
});
test('reset while a query is in flight drops its late answer; the hand waits for that answer before posting again', () => {
  const { queries, worker } = setup();
  queries.request(0, 1, lattice, [0, 0, 0], [0, 1, 0], 0.02, 0, 'old');
  const inFlight = worker().queries[0];
  queries.reset();
  const next = enumerateLattice(6);
  assert.equal(queries.request(0, 2, next, [0, 0, 0], [0, 1, 0], 0.02, 0, 'new'), false, 'obsolete query still queued');
  worker().answer(inFlight, 11);
  assert.equal(queries.result(0), null); assert.equal(queries.busy(0), false);
  assert.ok(queries.request(0, 2, next, [0, 0, 0], [0, 1, 0], 0.02, 0, 'new'));
  assert.equal(worker().lattice.generation, 2); assert.equal(worker().lattice.count, next.count);
  worker().answer({ ...worker().queries[1], generation: 1 }, 4);  // answer stamped with the old generation
  assert.equal(queries.result(0), null);
});
test('repeated resets cannot grow the worker queue beyond one query per hand', () => {
  const { queries, worker } = setup();
  for (let generation = 1; generation <= 50; generation++) {
    queries.request(0, generation, lattice, [0, 0, 0], [0, 1, 0], 0.02, 0, 'left');
    queries.request(1, generation, lattice, [0, 0, 0], [1, 1, 0], 0.02, 0, 'right');
    queries.reset();
  }
  const kinds = worker().sent.map(s => s.message.type);
  assert.equal(kinds.filter(k => k === 'query').length, 2);
  assert.equal(kinds.filter(k => k === 'lattice').length, 1);
  for (const query of worker().queries) worker().answer(query, 1);
  assert.equal(queries.result(0), null); assert.equal(queries.result(1), null);
  assert.ok(queries.request(0, 50, lattice, [0, 0, 0], [0, 1, 0], 0.02, 0, 'left'));
  assert.equal(worker().sent.filter(s => s.message.type === 'lattice').length, 2);
});
test('a worker reply for a lattice it does not hold is discarded', () => {
  const { queries, worker } = setup();
  queries.request(0, 1, lattice, [0, 0, 0], [0, 1, 0], 0.02, 0, 'ray');
  worker().answer(worker().queries[0], null);
  assert.equal(queries.result(0), null); assert.equal(queries.busy(0), false);
});
test('worker errors, or a missing Worker, fall back to the synchronous path', () => {
  const { queries, worker } = setup();
  queries.request(0, 1, lattice, [0, 0, 0], [0, 1, 0], 0.02, 0, 'ray');
  worker().onerror(new Event('error'));
  assert.equal(queries.available, false); assert.ok(worker().terminated); assert.equal(queries.busy(0), false);
  assert.equal(queries.request(0, 1, lattice, [0, 0, 0], [0, 1, 0], 0.02, 0, 'ray'), false);
  const missing = new HoverQueries(() => { throw new ReferenceError('Worker is not defined'); });
  assert.equal(missing.available, false);
});

for (const failing of ['lattice', 'query']) test(`a throwing postMessage for the ${failing} falls back instead of escaping`, () => {
  let worker;
  const queries = new HoverQueries(() => (worker = Object.assign(new FakeWorker(), {
    postMessage(message) { if (message.type === failing) throw new DOMException('synthetic clone failure', 'DataCloneError'); this.sent.push({ message }); },
  })));
  assert.doesNotThrow(() => assert.equal(queries.request(0, 1, lattice, [0, 0, 0], [0, 1, 0], 0.02, 0, 'ray'), false));
  assert.equal(queries.available, false); assert.ok(worker.terminated); assert.equal(queries.busy(0), false);
});
test('a failed worker cannot deliver late results', () => {
  const { queries, worker } = setup();
  queries.request(0, 1, lattice, [0, 0, 0], [0, 1, 0], 0.02, 0, 'ray');
  const old = worker(), query = old.queries[0];
  old.onerror(new Event('error'));
  old.answer(query, 3);
  assert.equal(queries.result(0), null);
});
