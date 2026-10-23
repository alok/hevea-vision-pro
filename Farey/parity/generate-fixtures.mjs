// SPDX-License-Identifier: GPL-3.0-or-later
// Generates parity/fixtures.json from the browser's own modules, so every expected value below is what the
// canonical browser code computes, not a hand-typed claim. Native FareyCore checks the same file
// (ParityContractTests). Run from Farey/: node parity/generate-fixtures.mjs > parity/fixtures.json
import { vector, discriminant, kind, upperRoot, positiveRepresentative, polynomial } from '../WebXR/starscape-core.js';
import { enumerateLattice, tripleAt, inBall } from '../WebXR/lattice.js';
import { pairPlane, planeFromNormal, inPairPlane } from '../WebXR/pair-plane.js';
import { pushforward, pushforwardExact, transvection, act, inverse, nearestIntegral } from '../WebXR/mobius.js';
import { readFileSync } from 'node:fs';

const browserVersion = JSON.parse(readFileSync(new URL('../WebXR/package.json', import.meta.url))).version;
const radii = [4, 6, 8, 10, 12];
const gcd = (x, y) => { x = Math.abs(x); y = Math.abs(y); while (y) [x, y] = [y, x % y]; return x; };
const points = (radius) => { const l = enumerateLattice(radius); return Array.from({ length: l.count }, (_, i) => tripleAt(l, i)); };
const census = radius => {
  const all = points(radius), tally = { upper: 0, lower: 0, null: 0, exterior: 0 };
  for (const p of all) tally[kind(p)]++;
  return { radius, count: all.length, ...tally };
};

// Points of the contract: [id, triple, note].
const pointCases = [
  ['default', [1, -1, 2], 'default selection; upper root (1+i√7)/2'],
  ['default-sign-partner', [-1, 1, -2], 'same roots, opposite vector; keep the actual signed triple'],
  ['x2+1', [1, 0, 1], 'root i; visible R6 multiple pair with (2,0,2)'],
  ['2x2+2', [2, 0, 2], 'multiple of x²+1: same root, twice the vector, never reduced'],
  ['default-multiple', [2, -2, 4], 'Next after the default; norm² 44 > 36, so hidden at R6 until R8'],
  ['x2+x+1', [1, 1, 1], 'root (−1+i√3)/2'],
  ['(x-1)2', [1, -2, 1], 'null: double finite root 1'],
  ['constant-1', [0, 0, 1], 'null: no finite root; double projective root at ∞'],
  ['x', [0, 1, 0], 'exterior: finite root 0 and projective root ∞; normal of the plane b = 0'],
  ['x2-2', [1, 0, -2], 'exterior: roots ±√2, a nonrational plane normal'],
  ['user-seed', [13, 20, 34], 'the seed of the user\'s source URL: Δ −1368, norm² 3050, outside R ≤ 12, inside browser R96 only'],
];
// Exact real roots of a boundary or exterior form read projectively (binary quadratic ax² + bxy + cy²): '∞' is the
// projective point at infinity, not a real number. Interior forms have none.
const realRoots = abc => {
  if (kind(abc) === 'exterior') return planeFromNormal(abc).endpoints.map(e => e.label);
  if (kind(abc) !== 'null') return null;
  if (abc[0] === 0) return ['∞', '∞'];
  const [p, q] = [-abc[1], 2 * abc[0]], d = gcd(p, q) * Math.sign(q), label = q / d === 1 ? `${p / d}` : `${p / d}/${q / d}`;
  return [label, label];
};
// Exact machine-readable roots, so a consumer never parses labels or trusts a Double. Roots of A t² + B t + C with
// Δ = B² − 4AC, read projectively: A = 0 gives −C/B and ∞ (both ∞ for a constant); otherwise (−B + s√Δ)/(2A) for
// branch s = −1 then +1, given unreduced. 'rational' when Δ is a perfect square (then p/q in lowest terms).
const isqrt = n => { let x = Math.floor(Math.sqrt(n)); while (x * x > n) x--; while ((x + 1) * (x + 1) <= n) x++; return x; };
const ratio = (p, q) => { const d = gcd(p, q) * Math.sign(q); return { kind: 'rational', p: p / d + 0, q: q / d }; };
const exactRoots = ([A, B, C]) => {
  const delta = B * B - 4 * A * C;
  if (A === 0) return B === 0 ? [{ kind: 'infinity' }, { kind: 'infinity' }] : [ratio(-C, B), { kind: 'infinity' }];
  const root = isqrt(delta);
  return [-1, 1].map(sign => root * root === delta ? ratio(-B + sign * root, 2 * A)
    : { kind: 'quadratic', numerator: -B, sign, radicand: delta, denominator: 2 * A });
};
const fixturePoints = pointCases.map(([id, abc, note]) => {
  const representative = positiveRepresentative(abc), root = representative && upperRoot(representative);
  return {
    id, abc, note, kind: kind(abc), discriminant: discriminant(abc), vector: vector(abc).map(x => x + 0),
    parityYZ: ((vector(abc)[1] - vector(abc)[2]) % 2 + 2) % 2,
    polynomial: polynomial(abc), primitive: gcd(gcd(abc[0], abc[1]), abc[2]) === 1,
    // The upper root of the positive representative, exactly (−b + i√(−Δ))/(2a) with a > 0, and as a Double.
    upperRootExact: representative && { realNumerator: -representative[1], imaginaryRadicand: -discriminant(representative),
      denominator: 2 * representative[0] },
    upperRootApprox: root, positiveRepresentative: representative,
    realRoots: realRoots(abc), realRootsExact: ['null', 'exterior'].includes(kind(abc)) ? exactRoots(abc) : null,
    inBall: Object.fromEntries([...radii, 96].map(r => [r, inBall(abc, r)])),
  };
});

const r6 = points(6);
const planeSummary = plane => {
  const members = r6.filter(p => discriminant(p) < 0 && inPairPlane(plane.normal, p));
  return {
    normal: plane.normal, equation: plane.equation, endpoints: plane.endpoints.map(e => e.label),
    endpointsExact: exactRoots(plane.normal),
    interiorTriplesR6: members.length, upperR6: members.filter(p => p[0] > 0).length,
    lowerR6: members.filter(p => p[0] < 0).length,
  };
};
const planes = [
  { id: 'pair x²+1 / x²+x+1', first: [1, 0, 1], second: [1, 1, 1], ...planeSummary(pairPlane([1, 0, 1], [1, 1, 1])) },
  { id: 'normal x', normalInput: [0, 1, 0], ...planeSummary(planeFromNormal([0, 1, 0])) },
  { id: 'normal x²−2', normalInput: [1, 0, -2], ...planeSummary(planeFromNormal([1, 0, -2])) },
];
// Browser error text mapped to the shared codes native uses (CuttingPlaneError).
const code = error => /same primitive/.test(error) ? 'sameDirection' : /inside the cone/.test(error) ? 'notInterior'
  : /real geodesic/.test(error) ? 'notExterior' : /zero/.test(error) ? 'zero' : 'other';
const rejections = [
  { first: [1, 0, 1], second: [2, 0, 2], why: 'multiple: same ray' },
  { first: [1, 0, 1], second: [-2, 0, -2], why: 'sign partner: same projective direction' },
  { first: [1, 0, 1], second: [1, 2, 1], why: 'second point null, not interior' },
  { first: [1, 0, 1], second: [1, 3, 1], why: 'second point exterior' },
].map(r => ({ ...r, error: code(pairPlane(r.first, r.second).error) }))
  .concat([[1, 2, 1], [1, 0, 1], [0, 0, 0]].map(n => ({ normalInput: n, error: code(planeFromNormal(n).error) })));

// Möbius transformations (WebXR/mobius.js): g = [p, q, r, s] moves roots by z ↦ (pz+q)/(rz+s) and pushes coefficients
// forward by a′ = s²a − rs b + r²c, b′ = −2qs a + (ps+qr) b − 2pr c, c′ = q²a − pq b + p²c. Integer matrices act
// exactly; a real transvection is given only approximately, with its exact description.
const generators = { T: [1, 1, 0, 1], 'T⁻¹': [1, -1, 0, 1], S: [0, -1, 1, 0] };
const mobius = {
  convention: 'g = [p, q, r, s] = [[p, q], [r, s]], det 1; roots z ↦ (pz+q)/(rz+s); coefficients Q ↦ Q∘g⁻¹',
  generators: Object.entries(generators).map(([name, g]) => ({
    name, g, pushforwardRows: pushforward(g).map(x => x + 0),
    images: pointCases.map(([id, abc]) => ({ id, image: pushforwardExact(g, abc).map(Number) })),
  })),
  dragStep: (() => {
    const z0 = { x: 0, y: 1 }, z1 = { x: 1, y: 1 }, g = transvection(z0, z1);
    return {
      description: 'transvection carrying i to 1 + i along their geodesic: exactly [[3, 1], [1, 2]]/√5',
      z0, z1, gApprox: g, imageOfZ0Approx: act(g, z0), inverseApprox: inverse(g),
      imageOfDefaultApprox: pushforward(g).length && applyPush(g, [1, -1, 2]),
    };
  })(),
  // Snap: reduce g·i into the fundamental domain, then of γ and γS take the residual γ⁻¹g with the smaller polar
  // rotation about i. Recorded on her viewer (2026-10-23): one drag from −0.4 + 0.1i to −0.4 + i landed on
  // γ = [1, 4; 0, 1] and relabelled (13,20,34) as (13,−84,162). Entrywise distance would instead pick [4, −1; 1, 0].
  snap: [{
    description: 'transvection from −0.4 + 0.1i to −0.4 + i, Snap on',
    gRecordedApprox: [3.162278103784889, 1.1384199665329495, 4.0371747379733554e-16, 0.31622772165519336],
    gamma: nearestIntegral([3.162278103784889, 1.1384199665329495, 4.0371747379733554e-16, 0.31622772165519336]),
    selection: [13, 20, 34],
    absorbed: pushforwardExact(nearestIntegral(transvection({ x: -0.4, y: 0.1 }, { x: -0.4, y: 1 })), [13, 20, 34]).map(Number),
  },
  // Half-way translations: rounding halves toward +∞, as her viewer's Math.round does.
  ...[[1, -0.5, 0, 1], [1, 0.5, 0, 1], [1, -1.5, 0, 1]].map(g => ({ description: 'half-way translation', gRecordedApprox: g, gamma: nearestIntegral(g) }))],
};
function applyPush(g, abc) { const m = pushforward(g); return [0, 1, 2].map(i => m[3 * i] * abc[0] + m[3 * i + 1] * abc[1] + m[3 * i + 2] * abc[2]); }

process.stdout.write(JSON.stringify({
  contract: 'farey-coefficient-parity', contractVersion: 1, generatedFrom: `browser ${browserVersion} modules`,
  basis: {
    display: '(X,Y,Z) = (−b, a+c, c−a)', discriminant: 'Δ = b² − 4ac = X² + Z² − Y²',
    ball: 'b² + 2a² + 2c² ≤ R², equivalently X²+Y²+Z² ≤ R², zero excluded', parity: 'Y ≡ Z (mod 2)',
    exactness: 'Integers, kinds, equations and the *Exact fields are exact; *Approx fields are IEEE doubles for '
      + 'tolerance checks only; realRoots and endpoints are human-readable labels. Values are generated by the browser '
      + 'modules and checked against native FareyCore: regression contracts, not kernel-verified theorems.',
  },
  census: radii.map(census),
  browserOnlyCapacity: { radius: 96, count: 1852484, note: 'browser extension; native caps at R12 (one entity per point)' },
  points: fixturePoints, planes, rejections, mobius,
}, null, 1) + '\n');
