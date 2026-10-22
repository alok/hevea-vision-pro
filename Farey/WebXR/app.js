// SPDX-License-Identifier: GPL-3.0-or-later
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { FareyState, fraction, grid, onRay, position, primitive } from './core.js';
import { xrAvailability, controllerRay, captureView, restoreView } from './xr-support.js';
import { TapSelection } from './input.js';
import { readSelection, writeSelection } from './recovery.js';

const $ = id => document.getElementById(id);
const state = new FareyState();
const savedSelection = readSelection();
for (const turn of savedSelection?.word ?? '') state.step(turn);
if (savedSelection?.point) state.select(savedSelection.point.p, savedSelection.point.q);
const colors = { base: 0x267ac9, muted: 0x254354, left: 0x54e9f5, right: 0xb18aee, selected: 0xffa140, ray: 0x58e896, inspected: 0xffffff };
let renderer;
try {
  renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
} catch {
  $('fatal').hidden = false;
  $('fatal').textContent = 'A WebGL-capable browser is needed to draw the lattice. The mathematics and native visionOS version remain available in the repository.';
  document.querySelectorAll('.controls button, .controls input, .controls select').forEach(control => { control.disabled = true; });
  throw new Error('WebGL unavailable');
}
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
renderer.xr.enabled = true;
renderer.xr.setReferenceSpaceType('local-floor');
$('viewport').append(renderer.domElement);
renderer.domElement.tabIndex = 0;
renderer.domElement.setAttribute('role', 'img');
renderer.domElement.setAttribute('aria-label', 'Interactive Farey lattice');
renderer.domElement.setAttribute('aria-describedby', 'geometry-description view-help');
const scene = new THREE.Scene();
scene.background = new THREE.Color(0x000000);
const camera = new THREE.PerspectiveCamera(48, 1, 0.05, 60);
camera.position.set(3.3, 3.1, 2.1);
const controls = new OrbitControls(camera, renderer.domElement);
controls.target.set(0, 1.75, -3.2);
controls.minDistance = 1.2;
controls.maxDistance = 14;
controls.enableDamping = false;
controls.listenToKeyEvents(renderer.domElement);
controls.update();
scene.add(new THREE.HemisphereLight(0xc9e8ff, 0x31404a, 2.3));
const light = new THREE.DirectionalLight(0xffffff, 3);
light.position.set(-2, 4, 1); scene.add(light);
const lattice = new THREE.Group();
lattice.position.set(0, 1.8, -2.1);
lattice.rotation.x = Math.PI / 7;
scene.add(lattice);
const pointsGroup = new THREE.Group(), selection = new THREE.Group();
lattice.add(pointsGroup, selection);
const sphere = new THREE.SphereGeometry(0.036, 16, 10);
const materials = Object.fromEntries(Object.entries(colors).map(([key, color]) => [key, new THREE.MeshStandardMaterial({ color, roughness: 0.35 })]));
const origin = new THREE.Mesh(sphere, new THREE.MeshBasicMaterial({ color: 0xffffff }));
origin.scale.setScalar(1.5); lattice.add(origin);
const raycaster = new THREE.Raycaster();
const pointer = new THREE.Vector2();
let bound = savedSelection?.grid ?? 12, points = [], gridLines, session = null, startingXR = false, desktopView, aspectFit = 1;
let graphicsLost = false;
$('bound').value = String(bound);
let lesson = null;
const lessonSteps = [
  { turn: 'L', choices: ['1/3', '2/3', '3/2'] },
  { turn: 'R', choices: ['3/4', '3/5', '2/5'] }
];
const vrPanel = new THREE.Group();
vrPanel.position.set(0, 1.15, -1.15);
vrPanel.visible = false;
scene.add(vrPanel);
const vrTargets = [];
const axisLabels = ['q', 'p'].map(text => {
  const sprite = new THREE.Sprite(new THREE.SpriteMaterial({ map: makeText(text, 128, 128, '#000') }));
  sprite.scale.set(0.18, 0.18, 1); lattice.add(sprite); return sprite;
});

function makeText(text, width, height, background = '#142b38') {
  const canvas = document.createElement('canvas'); canvas.width = width; canvas.height = height;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = background; ctx.fillRect(0, 0, width, height);
  ctx.fillStyle = '#eaf7ff'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  ctx.font = `${Math.floor(height * 0.42)}px system-ui`; ctx.fillText(text, width / 2, height / 2);
  return new THREE.CanvasTexture(canvas);
}
function panelButton(text, x, action) {
  const mesh = new THREE.Mesh(new THREE.PlaneGeometry(0.145, 0.08), new THREE.MeshBasicMaterial({ map: makeText(text, 256, 128) }));
  mesh.position.set(x, 0, 0); mesh.userData.action = action; vrPanel.add(mesh); vrTargets.push(mesh);
}
panelButton('L', -0.4, () => state.step('L'));
panelButton('R', -0.24, () => state.step('R'));
panelButton('Undo', -0.08, () => state.undo());
panelButton('Reset', 0.08, reset);
panelButton('3/5', 0.24, () => state.select(3, 5));
panelButton('Exit', 0.4, () => session?.end());
const vrLabel = new THREE.Mesh(new THREE.PlaneGeometry(1, 0.1), new THREE.MeshBasicMaterial({ map: makeText('', 1600, 160) }));
vrLabel.position.y = 0.1; vrPanel.add(vrLabel);
const vrCredit = new THREE.Mesh(new THREE.PlaneGeometry(1.1, 0.08), new THREE.MeshBasicMaterial({ map: makeText('Katherine Stange · L/R coding: Caroline Series', 1800, 128, '#080f16') }));
vrCredit.position.y = -0.1; vrPanel.add(vrCredit);

function disposeGroup(group) {
  while (group.children.length) {
    const object = group.children[0]; group.remove(object);
    object.geometry?.dispose();
    if (object.material) object.material.dispose();
  }
}
function segment(a, b, color) {
  const geometry = new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(...a), new THREE.Vector3(...b)]);
  selection.add(new THREE.Line(geometry, new THREE.LineBasicMaterial({ color })));
}
function vector(end, color) {
  const v = new THREE.Vector3(...end);
  // Each selection owns its line and cone, so disposal never touches shared sphere meshes.
  segment([0, 0, 0], end, color);
  const head = new THREE.Mesh(new THREE.ConeGeometry(0.025, 0.07, 10), new THREE.MeshBasicMaterial({ color }));
  head.position.copy(v.clone().addScaledVector(v.clone().normalize(), -0.035));
  head.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), v.normalize()); selection.add(head);
}
function rebuildGrid() {
  for (const mesh of points) pointsGroup.remove(mesh);
  points = grid(bound).map(point => {
    const mesh = new THREE.Mesh(sphere, materials[primitive(point) ? 'base' : 'muted']);
    mesh.position.fromArray(position(point)); mesh.userData.point = point; pointsGroup.add(mesh); return mesh;
  });
  if (gridLines) { lattice.remove(gridLines); gridLines.geometry.dispose(); gridLines.material.dispose(); }
  const vertices = [];
  for (let n = 0; n <= bound; n++) {
    vertices.push(...position({ p: n, q: 0 }), ...position({ p: n, q: bound }));
    vertices.push(...position({ p: 0, q: n }), ...position({ p: bound, q: n }));
  }
  const geometry = new THREE.BufferGeometry(); geometry.setAttribute('position', new THREE.Float32BufferAttribute(vertices, 3));
  gridLines = new THREE.LineSegments(geometry, new THREE.LineBasicMaterial({ color: 0x263743 })); lattice.add(gridLines);
  axisLabels[0].position.fromArray(position({ p: 0, q: bound })).y += 0.14;
  axisLabels[1].position.fromArray(position({ p: bound, q: 0 })).y += 0.14;
}
function update() {
  disposeGroup(selection);
  const m = state.mediant;
  for (const mesh of points) {
    const point = mesh.userData.point;
    let key = primitive(point) ? 'base' : 'muted';
    if (onRay(point, m)) key = 'ray';
    if (point.p === state.left.p && point.q === state.left.q) key = 'left';
    if (point.p === state.right.p && point.q === state.right.q) key = 'right';
    if (point.p === m.p && point.q === m.q) key = 'selected';
    if (state.selectedPoint && point.p === state.selectedPoint.p && point.q === state.selectedPoint.q && !primitive(point)) key = 'inspected';
    mesh.material = materials[key]; mesh.scale.setScalar(['selected', 'inspected'].includes(key) ? 1.65 : 1);
  }
  const scale = bound / Math.max(m.p, m.q);
  const end = position({ p: m.p * scale, q: m.q * scale }), h = 0.65;
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute([0, 0, 0, ...end, 0, h, 0, end[0], h, end[2]], 3));
  geometry.setIndex([0, 1, 2, 2, 1, 3]); geometry.computeVertexNormals();
  selection.add(new THREE.Mesh(geometry, new THREE.MeshBasicMaterial({ color: colors.ray, transparent: true, opacity: 0.16, side: THREE.DoubleSide, depthWrite: false })));
  segment([0, 0, 0], end, colors.ray); segment([0, h, 0], [end[0], h, end[2]], colors.ray);
  const inside = m.p <= bound && m.q <= bound;
  if (inside) {
    const a = position(state.left), b = position(state.right), c = position(m);
    vector(a, colors.left); vector(b, colors.right); vector(c, colors.selected);
    segment(a, c, colors.right); segment(b, c, colors.left);
  }
  $('word').textContent = state.word || 'Start';
  $('fraction').textContent = `${fraction(state.left)} < ${fraction(m)} < ${fraction(state.right)}`;
  $('rational').value = fraction(m);
  $('matrix').textContent = `M = [${state.right.p} ${state.left.p}; ${state.right.q} ${state.left.q}] · det M = ${state.determinant} · ${state.word.length}/24 moves`;
  const inspection = state.inspection;
  $('vector-state').textContent = `Primitive vector (q,p) = (${m.q},${m.p}) · gcd(${inspection.point.q}, ${inspection.point.p}) = ${inspection.divisor}`;
  $('point-equation').textContent = `Point (q,p): ${inspection.equation}`;
  const inspectedInside = inspection.point.p <= bound && inspection.point.q <= bound;
  $('point-detail').textContent = `${inspection.reduction}. Divide both coordinates by ${inspection.divisor} to obtain the primitive vector. Positive multiples share the same ray and upright green plane. White marks the inspected point when it differs from the orange primitive point. ${inspectedInside ? '' : 'The inspected point is beyond this finite grid; its coordinates have not been moved to the edge. '}L/R follows the reduced fraction, not the distance from the origin. Axis points 0 and ∞ are boundaries and do not replace this positive selection.`;
  const saved = writeSelection(state.word, bound, undefined, state.selectedPoint);
  $('graphics-message').textContent = `Your exact selection is ${fraction(m)}, with grid ${bound}. `
    + (saved ? 'Reloading will keep this selection.' : 'Tab storage is unavailable; this selection may not survive a reload.');
  const spoken = value => value.q === 0 ? 'infinity' : `${value.p} over ${value.q}`;
  $('geometry-description').textContent = `Finite integer lattice. Selected fraction ${spoken(m)}, direction vector (${m.q}, ${m.p}). Inspected point (${inspection.point.q}, ${inspection.point.p}) is ${inspection.divisor} times this primitive vector. Neighbors ${spoken(state.left)} and ${spoken(state.right)}. Their vectors add to the primitive vector. The green plane contains its integer multiples.`;
  $('receipt').textContent = `${points.length} lattice points · ${points.filter(p => onRay(p.userData.point, m)).length} on this ray${inside ? '' : ' · primitive point beyond the finite grid'}`;
  $('left').disabled = $('right').disabled = state.word.length >= 24;
  $('undo').disabled = !state.word;
  vrLabel.material.map.dispose();
  vrLabel.material.map = makeText(`${state.word || 'Start'}   ${fraction(m)}   ${inspection.equation}`, 1600, 160);
  if (lesson && lesson.word !== state.word) lesson = null;
  renderLesson();
  render();
}
function startLesson() {
  reset(); state.select(1, 2);
  lesson = { step: 0, phase: 'predict', guess: null, word: state.word };
  update();
  $('lesson-choices').firstElementChild?.focus({ preventScroll: true });
}
function renderLesson() {
  $('lesson').hidden = !lesson;
  document.body.classList.toggle('learning', !!lesson);
  if (!lesson) { $('lesson-choices').replaceChildren(); return; }
  const step = lessonSteps[lesson.step];
  const predicting = lesson.phase === 'predict';
  $('lesson-question').textContent = predicting
    ? `Selected: ${fraction(state.mediant)}. After ${step.turn}, which rational will be selected?`
    : `Selected after ${step.turn}: ${fraction(state.mediant)}`;
  const choices = $('lesson-choices');
  if (!predicting) choices.replaceChildren();
  else {
    if (choices.dataset.step !== String(lesson.step) || !choices.childElementCount) {
      choices.replaceChildren(...step.choices.map(choice => {
        const button = document.createElement('button'); button.textContent = choice;
        button.onclick = () => { lesson.guess = choice; renderLesson(); };
        return button;
      }));
      choices.dataset.step = String(lesson.step);
    }
    for (const button of choices.children) button.setAttribute('aria-pressed', String(lesson.guess === button.textContent));
  }
  $('lesson-apply').hidden = !predicting;
  $('lesson-apply').disabled = !lesson.guess;
  $('lesson-apply').textContent = `Apply ${step.turn}`;
  $('lesson-next').hidden = predicting || lesson.step === 1;
  $('lesson-explanation').textContent = predicting
    ? `${step.turn} replaces the ${step.turn === 'L' ? 'lower' : 'upper'} endpoint with the current mediant. Make a prediction, then apply the actual move.`
    : lesson.explanation;
}
$('learn').onclick = startLesson;
$('lesson-restart').onclick = startLesson;
$('lesson-close').onclick = () => { lesson = null; renderLesson(); $('learn').focus({ preventScroll: true }); };
$('lesson-next').onclick = () => {
  lesson = { step: 1, phase: 'predict', guess: null, word: state.word }; renderLesson();
  $('lesson-choices').firstElementChild?.focus({ preventScroll: true });
};
$('lesson-apply').onclick = () => {
  if (!lesson || !lesson.guess || lesson.phase !== 'predict') return;
  const turn = lessonSteps[lesson.step].turn;
  const old = fraction(turn === 'L' ? state.left : state.right), middle = fraction(state.mediant);
  state.step(turn);
  const m = state.mediant, a = state.left, b = state.right;
  lesson.explanation = `${lesson.guess === fraction(m) ? 'Your prediction matched.' : `You predicted ${lesson.guess}; the selected fraction is ${fraction(m)}.`} ${turn} replaced ${old} with ${middle}. The new neighbors are ${fraction(a)} and ${fraction(b)}. Their lattice vectors add: (${a.q},${a.p}) + (${b.q},${b.p}) = (${m.q},${m.p}), so the mediant is ${fraction(m)}.`;
  lesson.phase = 'explain'; lesson.word = state.word;
  update();
  $(lesson.step === 0 ? 'lesson-next' : 'lesson-close').focus({ preventScroll: true });
};
function reset() {
  state.reset(); bound = 12; $('bound').value = '12'; rebuildGrid();
  if (!session) { camera.position.set(3.3, 3.1, 2.1); controls.target.set(0, 1.75, -3.2); aspectFit = 1; fitAspect(); controls.update(); }
}
function render() { if (!graphicsLost) renderer.render(scene, camera); }
function fitAspect() {
  const next = Math.max(1, 0.85 / camera.aspect);
  camera.position.sub(controls.target).multiplyScalar(next / aspectFit).add(controls.target);
  controls.maxDistance = 14 * next;
  aspectFit = next;
}
function resize() {
  if (session) return;
  const viewport = $('viewport');
  const landscape = matchMedia('(max-height: 500px) and (orientation: landscape)').matches;
  const phone = matchMedia('(max-width: 700px)').matches;
  viewport.style.top = phone || landscape ? `${document.querySelector('header').getBoundingClientRect().bottom + 12}px` : '0';
  viewport.style.bottom = landscape ? '12px' : phone ? `${innerHeight - document.querySelector('.controls').getBoundingClientRect().top + 12}px` : '0';
  const width = viewport.clientWidth, height = Math.max(1, viewport.clientHeight);
  camera.aspect = width / height;
  fitAspect();
  camera.updateProjectionMatrix(); renderer.setSize(width, height); render();
}
function setPointer(event) {
  const rect = renderer.domElement.getBoundingClientRect();
  pointer.set((event.clientX - rect.left) / rect.width * 2 - 1, 1 - (event.clientY - rect.top) / rect.height * 2);
}
function activate(hits) {
  if (!hits.length) return;
  const { object } = hits[0];
  if (object.userData.action) object.userData.action();
  else if (object.userData.point?.p > 0 && object.userData.point?.q > 0) {
    if (state.select(object.userData.point.p, object.userData.point.q)) lesson = null;
  }
  update();
}
const tap = new TapSelection();
renderer.domElement.addEventListener('pointerdown', e => tap.begin(e));
renderer.domElement.addEventListener('pointermove', e => {
  tap.move(e);
  if (session || e.buttons) { $('hover').hidden = true; return; }
  setPointer(e);
  raycaster.setFromCamera(pointer, camera);
  const point = raycaster.intersectObjects(points)[0]?.object.userData.point;
  $('hover').hidden = !point;
  if (point) {
    $('hover').textContent = `${fraction(point)} · (q,p) = (${point.q},${point.p})`;
    $('hover').style.left = `${e.clientX + 15}px`; $('hover').style.top = `${e.clientY + 15}px`;
  }
});
renderer.domElement.addEventListener('pointerleave', () => { $('hover').hidden = true; });
renderer.domElement.addEventListener('pointerup', e => {
  if (!tap.end(e) || session) return;
  setPointer(e);
  raycaster.setFromCamera(pointer, camera); activate(raycaster.intersectObjects(points));
});
renderer.domElement.addEventListener('pointercancel', e => tap.cancel(e));
renderer.domElement.addEventListener('keydown', e => {
  if (session || graphicsLost) return;
  if (e.key === 'Home') { e.preventDefault(); $('view').click(); }
  if (['+', '=', '-'].includes(e.key)) {
    e.preventDefault();
    const distance = camera.position.distanceTo(controls.target);
    const next = THREE.MathUtils.clamp(distance * (e.key === '-' ? 1.1 : 1 / 1.1), controls.minDistance, controls.maxDistance);
    camera.position.sub(controls.target).multiplyScalar(next / distance).add(controls.target);
    controls.update(); render();
  }
});
for (let i = 0; i < 2; i++) {
  const controller = renderer.xr.getController(i);
  const line = new THREE.Line(new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(), new THREE.Vector3(0, 0, -1)]), new THREE.LineBasicMaterial({ color: 0x80dfea }));
  line.scale.z = 6; controller.add(line); scene.add(controller);
  controller.addEventListener('select', () => {
    controllerRay(controller, raycaster);
    activate(raycaster.intersectObjects([...vrTargets, ...points]));
  });
}
$('left').onclick = () => { state.step('L'); update(); };
$('right').onclick = () => { state.step('R'); update(); };
$('undo').onclick = () => { state.undo(); update(); };
$('reset').onclick = () => { reset(); update(); };
$('example').onclick = () => { state.select(3, 5); update(); };
$('bound').onchange = () => { bound = Number($('bound').value); rebuildGrid(); update(); };
$('view').onclick = () => {
  camera.position.set(0, 2.5, 3.2); controls.target.set(0, 1.75, -3.2);
  aspectFit = 1; fitAspect(); controls.update(); render();
};
$('select-form').onsubmit = e => {
  e.preventDefault(); const [p, q] = $('rational').value.split('/').map(Number);
  if (state.select(p, q)) { lesson = null; update(); }
  else $('receipt').textContent = 'Choose positive integers up to 1000 with a path of at most 24 moves.';
};
$('reload-graphics').onclick = () => location.reload();
renderer.domElement.addEventListener('webglcontextlost', event => {
  event.preventDefault(); graphicsLost = true; controls.enabled = false;
  renderer.domElement.style.visibility = 'hidden';
  renderer.domElement.tabIndex = -1;
  renderer.domElement.setAttribute('aria-disabled', 'true');
  $('graphics-notice').hidden = false; $('hover').hidden = true; $('xr').disabled = true;
  renderer.setAnimationLoop(null);
  session?.end().catch(() => {});
});
renderer.domElement.addEventListener('webglcontextrestored', () => {
  graphicsLost = false; controls.enabled = !session;
  renderer.domElement.tabIndex = 0;
  renderer.domElement.removeAttribute('aria-disabled');
  requestAnimationFrame(() => {
    resize(); renderer.domElement.style.visibility = ''; $('graphics-notice').hidden = true;
  });
  checkXR();
});
controls.addEventListener('change', render);
window.addEventListener('resize', resize);
const layoutObserver = new ResizeObserver(resize);
layoutObserver.observe(document.querySelector('header'));
layoutObserver.observe(document.querySelector('.controls'));
renderer.xr.addEventListener('sessionend', () => {
  session = null; startingXR = false; vrPanel.visible = false; controls.enabled = !graphicsLost;
  if (desktopView) restoreView(desktopView, camera, controls);
  desktopView = null;
  document.body.classList.remove('immersive'); $('xr').textContent = 'Enter VR'; $('xr').disabled = graphicsLost;
  renderer.setAnimationLoop(null); resize();
});
$('xr').onclick = async () => {
  if (startingXR || session || graphicsLost) return;
  startingXR = true; $('xr').disabled = true;
  $('xr').textContent = 'Waiting for VR…';
  desktopView = captureView(camera, controls);
  const waiting = setTimeout(() => {
    if (startingXR && !session) $('receipt').textContent = 'VR is waiting for the browser. Check its permission prompt; you can keep exploring here.';
  }, 8000);
  try {
    session = await navigator.xr.requestSession('immersive-vr', { optionalFeatures: ['local-floor'] });
    await renderer.xr.setSession(session);
    controls.enabled = false; vrPanel.visible = true; document.body.classList.add('immersive');
    renderer.setAnimationLoop(render);
  } catch (error) {
    await session?.end().catch(() => {}); session = null; startingXR = false;
    $('xr').disabled = graphicsLost; $('xr').textContent = 'Enter VR';
    $('receipt').textContent = 'VR entry was cancelled or unavailable. The desktop view is still ready.';
  } finally {
    clearTimeout(waiting);
  }
};
async function checkXR() {
  const availability = await xrAvailability(navigator.xr, isSecureContext);
  $('xr').disabled = !availability.supported || graphicsLost;
  $('xr').textContent = availability.supported ? 'Enter VR' : 'VR unavailable here';
  $('xr').title = availability.message;
  $('xr-status').textContent = availability.message;
}
rebuildGrid(); update(); resize(); checkXR();
