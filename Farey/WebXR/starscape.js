// SPDX-License-Identifier: GPL-3.0-or-later
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { examples, vector, project, upperRoot, discriminant, height, kind, positiveRepresentative } from './starscape-core.js';
import { xrAvailability, controllerRay, captureView, restoreView } from './xr-support.js';
import { TapSelection, nearestToRayPacked } from './input.js';
import { cameraPlaneLabel } from './camera-planes.js';
import { coefficientColor, gradientCSS, paletteRange, categoryPalettes, glyphRadius, glyphScale, outlinePixels, sourceRadiusFactor, drawnPixels } from './appearance.js';
import { enumerateLattice, inBall, isUpper, tripleAt, latticeRadii, ballCount } from './lattice.js';
import { pointCloudMaterial, pointCloud, fillColors, fillFactors } from './point-cloud.js';
import { pairPlane, planeFromNormal, planeSection, coneDirections, inPairPlane } from './pair-plane.js';
const $ = id => document.getElementById(id);
let radius = 6, whole = true, symmetricColor = false, projectionVisible = false;
let selected = examples[0], lattice = null, cloudMesh, imageMesh;
let session = null, savedView = null, startingXR = false;
let inhabited=false, overviewView=null, lookDrag=null, look={yaw:0,pitch:0};
const overviewFov=45, originFov=100;
let categories='viridis', glyphKey=null, focusGlyphs=[], sigma=1, planeFocus=false;
let secondSelection=null, pairMessage='', pairGlyphs=[], planeMembers=new Set(), originMode=false, timings={}, colorKey='', factorKey='';
let renderer;
try { renderer = new THREE.WebGLRenderer({ antialias: true }); }
catch {
  $('fatal').hidden = false;
  $('fatal').textContent = 'WebGL is unavailable. The source links and mathematical explanation remain available.';
  document.querySelectorAll('.controls button, .controls input, .controls select').forEach(c => { c.disabled = true; });
  $('debug-toggle').disabled = true;
  $('xr').textContent = 'VR unavailable without WebGL';
  throw Error('WebGL unavailable');
}
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
renderer.xr.enabled = true; renderer.xr.setReferenceSpaceType('local-floor');
$('viewport').append(renderer.domElement);
renderer.domElement.tabIndex = 0;
renderer.domElement.setAttribute('role', 'img');
renderer.domElement.setAttribute('aria-label', 'Signed integer coefficient lattice in and around a double cone');
const scene = new THREE.Scene(); scene.background = new THREE.Color(0);
const camera = new THREE.PerspectiveCamera(45, 1, 0.05, 60);
const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = false; controls.minDistance = 1; controls.maxDistance = 20;
controls.listenToKeyEvents(renderer.domElement);
const world = new THREE.Group(); world.position.set(0, 1.4, -3.1); scene.add(world);
const scale = 0.16, physical = p => new THREE.Vector3(...p).multiplyScalar(scale);
const cloud = new THREE.Group(), disk = new THREE.Group(), cone = new THREE.Group(), focus = new THREE.Group();
world.add(cloud, disk, cone, focus);
// Unlit discs: the drawn color is exactly the legend color, with no shading or tone mapping.
const sphere = new THREE.SphereGeometry(glyphRadius, 12, 8);
const cloudMaterial = pointCloudMaterial();
const white = new THREE.MeshBasicMaterial({ color: 0xffffff });
const imageMaterial = new THREE.PointsMaterial({ color: 0x54e9f5, size: 2, sizeAttenuation: false });
const selectionMaterial=new THREE.MeshBasicMaterial({color:0xffffff,side:THREE.BackSide});
const pairMaterial=new THREE.MeshBasicMaterial({color:0xffba6b,side:THREE.BackSide});
function pointColor(point) {
  return new THREE.Color().setRGB(...coefficientColor(point,symmetricColor,categories),THREE.SRGBColorSpace);
}
function disposeChildren(group) {
  for (const object of [...group.children]) {
    group.remove(object);
    if (object.geometry && object.geometry !== sphere) object.geometry.dispose();
    if (object.material && ![white,imageMaterial,cloudMaterial,selectionMaterial,pairMaterial].includes(object.material)) object.material.dispose();
    object.dispose?.();
  }
}
function lines(paths,color,opacity=1) {
  const vertices=[];
  for(const path of paths) for(let i=1;i<path.length;i++) vertices.push(...path[i-1],...path[i]);
  const geometry=new THREE.BufferGeometry(); geometry.setAttribute('position',new THREE.Float32BufferAttribute(vertices,3));
  return new THREE.LineSegments(geometry,new THREE.LineBasicMaterial({color,transparent:opacity<1,opacity}));
}
function circle(h) {
  return Array.from({length:65},(_,i)=>[scale*Math.abs(h)*Math.cos(i*Math.PI/32),scale*h,scale*Math.abs(h)*Math.sin(i*Math.PI/32)]);
}
function surface(h,isDisk,opacity) {
  const vertices=[],ring=circle(h);
  for(let i=0;i<64;i++) vertices.push(0,isDisk?h*scale:0,0,...ring[i],...ring[i+1]);
  const geometry=new THREE.BufferGeometry(); geometry.setAttribute('position',new THREE.Float32BufferAttribute(vertices,3));
  return new THREE.Mesh(geometry,new THREE.MeshBasicMaterial({color:0x54e9f5,transparent:true,opacity,side:THREE.DoubleSide,depthWrite:false}));
}
const matrix = new THREE.Matrix4();
function rebuild() {
  glyphKey=null;
  disposeChildren(cloud); disposeChildren(disk); disposeChildren(cone);
  let t=performance.now();
  lattice = enumerateLattice(radius, !whole);
  timings.enumerate=performance.now()-t;t=performance.now();
  cloudMesh = pointCloud(lattice, cloudMaterial, symmetricColor, categories); cloudMesh.scale.setScalar(scale); cloud.add(cloudMesh);
  colorKey=[radius,whole,symmetricColor,categories].join();factorKey=[radius,whole,symmetricColor,''].join();
  timings.attributes=performance.now()-t;imageMesh=null;
  // Overview distance is 5.4·R/8 (resetView); far clipping and zoom limits leave room beyond the whole ball.
  camera.far=20+8*radius*scale;camera.updateProjectionMatrix();controls.maxDistance=Math.max(20,8*radius*scale);
  disk.add(surface(height,true,0.1), lines([circle(height)],0x54e9f5,0.8));
  for(const sign of [-1,1]) {
    const h=radius*sign;
    cone.add(surface(h,false,0.018));
    cone.add(lines([circle(h),...Array.from({length:8},(_,i)=>[[0,0,0],circle(h)[i*8]])],0x7896a8,0.26));
  }
}
const origin = new THREE.Mesh(sphere,white); world.add(origin);
const shown=p=>inBall(p,radius)&&(whole||isUpper(p));
const latticePoints=()=>Array.from({length:lattice.count},(_,i)=>tripleAt(lattice,i));
// Interior displayed triples on the Lorentz plane −2C·a + B·b − 2A·c = 0 (exact: |coefficients| ≤ 96).
function planeInteriorMembers([A,B,C]){
  const out=[], exact=Math.max(Math.abs(A),Math.abs(B),Math.abs(C))<2**40;
  for(let i=0;i<lattice.count;i++){
    const a=lattice.abc[3*i],b=lattice.abc[3*i+1],c=lattice.abc[3*i+2];
    if(b*b-4*a*c<0&&(exact?-2*C*a+B*b-2*A*c===0:inPairPlane([A,B,C],[a,b,c])))out.push([a,b,c]);
  }
  return out;
}
// Color and size attributes are O(n) to fill, so refill only when their inputs change.
// Radial images of every interior point on the screen y = height, built only once projection is shown.
function buildImages(){
  const t=performance.now(),images=new Float32Array(3*lattice.count);let n=0;
  for(let i=0;i<lattice.count;i++){const q=positiveRepresentative(tripleAt(lattice,i));if(q){images.set(project(q),3*n);n++;}}
  const geometry=new THREE.BufferGeometry();geometry.setAttribute('position',new THREE.BufferAttribute(images.subarray(0,3*n),3));
  imageMesh=new THREE.Points(geometry,imageMaterial);imageMesh.scale.setScalar(scale);imageMesh.frustumCulled=false;disk.add(imageMesh);
  timings.images=performance.now()-t;
}
function refreshColors(){
  const key=[radius,whole,symmetricColor,categories].join();if(key===colorKey)return;colorKey=key;
  const t=performance.now();fillColors(lattice,symmetricColor,categories,cloudMesh.geometry.attributes.color.array);
  cloudMesh.geometry.attributes.color.needsUpdate=true;timings.colors=performance.now()-t;
}
function refreshFactors(planeKey){
  const key=[radius,whole,symmetricColor,planeKey].join();if(key===factorKey)return;factorKey=key;
  const t=performance.now();
  fillFactors(lattice,symmetricColor,i=>planeMembers.size>0&&isUpper(tripleAt(lattice,i))&&planeMembers.has(tripleAt(lattice,i).join()),cloudMesh.geometry.attributes.aFactor.array);
  cloudMesh.geometry.attributes.aFactor.needsUpdate=true;timings.factors=performance.now()-t;
}
function selectPoint(point,asPair=false) {
  if(asPair) {
    const result=pairPlane(selected,point);
    if(result.error){pairMessage=result.error;$('pair-status').textContent=pairMessage;$('pair-status').hidden=false;return;}
    secondSelection=[...point];
  } else {selected=[...point];secondSelection=null;}
  pairMessage='';update();
  if(asPair)$('pair-details').scrollIntoView({block:'nearest'});
}
// As in Stange's viewer: two interior stars span a plane, and a selected exterior triple is a plane's normal.
function currentPlane(){
  if(secondSelection)return pairPlane(selected,secondSelection);
  if(kind(selected)==='exterior'){const plane=planeFromNormal(selected);if(!plane.error)return plane;}
  return null;
}
function updatePair() {
  $('pair-status').textContent=pairMessage;$('pair-status').hidden=!pairMessage;
  const plane=currentPlane();
  $('pair-details').hidden=!plane;$('pair-clear').hidden=!secondSelection;
  const focusUniform=cloudMaterial.uniforms.uFocus.value;focusUniform.w=0;
  if(!plane){refreshFactors('');return;}
  if(planeFocus){const [A,B,C]=plane.normal,n=new THREE.Vector3(-B,-A-C,C-A).normalize();focusUniform.set(n.x,n.y,n.z,1);cloudMaterial.uniforms.uFocusFade.value.x=0.5*radius;}
  cloudMaterial.uniforms.uKeep.value.set(...vector(selected));
  const members=planeInteriorMembers(plane.normal);
  planeMembers=new Set(members.map(p=>p.join()));refreshFactors(plane.normal.join());
  if(secondSelection){
    const root=upperRoot(positiveRepresentative(secondSelection));
    $('pair-second').textContent=`Second point: (${secondSelection.join(', ')}) · Δ = ${discriminant(secondSelection)} · root ${root[0].toFixed(3)} + ${root[1].toFixed(3)}i`;
  } else $('pair-second').textContent=`Cutting plane with normal (${plane.normal.join(', ')}): the plane Lorentz-orthogonal to the selected exterior triple.`;
  $('pair-equation').textContent=`Plane: ${plane.equation}`;
  $('pair-endpoints').textContent=`Geodesic endpoints: ${plane.endpoints.map(p=>p.label).join(' and ')}`;
  const secondVisible=!secondSelection||shown(secondSelection);
  $('pair-count').textContent=`${members.length} displayed complex-root points lie exactly in this plane (amber rings). Multiples remain separate points.${secondVisible?'':' The second point is hidden by this filter/crop.'}`;
  const ring=new THREE.InstancedMesh(sphere,pairMaterial,members.length);
  focus.add(ring);pairGlyphs.push({mesh:ring,points:members});
  const boundary=planeSection(plane.normal,radius).map(p=>physical(p).toArray()), vertices=[];
  for(let i=1;i<boundary.length;i++)vertices.push(0,0,0,...boundary[i-1],...boundary[i]);
  const geometry=new THREE.BufferGeometry();geometry.setAttribute('position',new THREE.Float32BufferAttribute(vertices,3));
  const sheet=new THREE.Mesh(geometry,new THREE.MeshBasicMaterial({color:0xffba6b,transparent:true,opacity:0.045,side:THREE.DoubleSide,depthWrite:false}));sheet.name='pair-plane';focus.add(sheet);
  focus.add(lines([boundary],0xffba6b,0.35));
  const directions=coneDirections(plane);
  focus.add(lines(directions.map(p=>[p.map(x=>-radius*scale*x),p.map(x=>radius*scale*x)]),0xffba6b,0.7));
  if(secondSelection&&secondVisible) {
    const marker=new THREE.Mesh(sphere,pairMaterial);marker.position.copy(physical(vector(secondSelection)));
    focus.add(marker);focusGlyphs.push({mesh:marker,extra:outlinePixels,point:secondSelection});
  }
  if(projectionVisible)focus.add(lines([directions.map(p=>p.map(x=>height*scale*x))],0xffba6b,0.9));
}
function update() {
  refreshColors();planeMembers=new Set();
  disposeChildren(focus);focusGlyphs=[];pairGlyphs=[];glyphKey=null; disk.visible=projectionVisible;if(projectionVisible&&!imageMesh)buildImages(); cone.visible=$('cone').checked;
  const inCloud=shown(selected);
  if(inCloud) {
    focus.add(lines([[[0,0,0],physical(vector(selected)).toArray()]],0xbacbd6,0.35));
    const marker=new THREE.Mesh(sphere,selectionMaterial);
    marker.position.copy(physical(vector(selected)));focus.add(marker);focusGlyphs.push({mesh:marker,extra:outlinePixels,point:selected});
  }
  const representative=positiveRepresentative(selected);
  if(projectionVisible && representative && inCloud) {
    const image=physical(project(representative));focus.add(lines([[[0,0,0],image.toArray()]],0xffffff));
    const marker=new THREE.Mesh(sphere,white);marker.position.copy(image);focus.add(marker);focusGlyphs.push({mesh:marker,extra:0});
  }
  $('point-state').textContent=`(a,b,c) = (${selected.join(', ')}) · Δ = ${discriminant(selected)}`;
  const root=representative?upperRoot(representative):null;
  $('root-state').textContent=root?`Upper root: ${root[0].toFixed(3)} + ${root[1].toFixed(3)}i${kind(selected)==='lower'?' · sign-flipped representative':''}`:kind(selected)==='null'?(selected[0]===0?'Boundary: double root at infinity':'Boundary: repeated real root'):'Exterior: real roots (outside the Klein disk)';
  $('coefficient').value=selected.join(',');$('projection').checked=projectionVisible;
  $('status').textContent=inCloud?'':'The selected point is hidden by this filter or crop.';
  $('inhabit').disabled=!inCloud&&!inhabited;
  updatePair();
  renderer.domElement.setAttribute('aria-description',`Selected coefficient point ${selected.join(', ')}. ${kind(selected)} region. ${lattice.count} points. Both cone halves ${cone.visible?'shown':'hidden'}.`);
  const [lo,hi]=paletteRange, reach=lattice.maxInterior;
  $('palette-bar').style.background=gradientCSS(categories);
  $('palette-label').textContent=`Upper interior |Δ| (log, ${categories==='viridis'?'Viridis 0.2–1':'Stange anchors'}) · crop reaches ${reach}`;
  for(const type of ['exterior','null','lower'])$(`swatch-${type}`).style.background=categoryPalettes[categories][type];
  $('palette-low').textContent=lo;$('palette-high').textContent=hi;
  render();
}
const tempLocal=new THREE.Vector3(),tempWorld=new THREE.Vector3();
// Which of her size causes applies: the origin-eye rule in Origin mode, plane emphasis for upper members.
const radiusFactor=p=>sigma*sourceRadiusFactor(p,{origin:originMode,onPlane:!originMode&&kind(p)==='upper'&&planeMembers.has(p.join()),symmetric:symmetricColor});
function updateGlyphSizes(){
  if(!cloudMesh)return;
  camera.updateMatrixWorld();world.updateMatrixWorld(true);
  const height=renderer.domElement.clientHeight;
  const key=camera.matrixWorld.elements.join(',')+'|'+height+'|'+camera.zoom+'|'+session+'|'+camera.fov;
  if(key===glyphKey)return;glyphKey=key;
  // Her overview fog: alpha falls by up to 55% between d−0.7R and d+0.9R from the eye (none in eye mode).
  const d=camera.position.distanceTo(controls.target), R=radius*scale, u=cloudMaterial.uniforms;
  u.uFog.value.set(Math.max(0.1*scale,d-0.7*R),d+0.9*R,inhabited||session?0:0.55);
  u.uHalfH.value=height/2;u.uGlyph.value=glyphRadius*sigma;u.uDpr.value=renderer.getPixelRatio();u.uOrigin.value=originMode&&!session?1:0;
  for(const item of pairGlyphs) {
    item.points.forEach((p,i)=>{
      tempLocal.copy(physical(vector(p)));
      tempWorld.copy(tempLocal).applyMatrix4(world.matrixWorld).applyMatrix4(camera.matrixWorldInverse);
      const size=session?1.2:glyphScale(-tempWorld.z,height,camera.fov,camera.zoom,0.65,radiusFactor(p));
      matrix.makeScale(size,size,size);matrix.setPosition(tempLocal);item.mesh.setMatrixAt(i,matrix);
    });
    item.mesh.instanceMatrix.needsUpdate=true;item.mesh.computeBoundingSphere();
  }
  origin.visible=!eyeAtOrigin();
  for(const item of [{mesh:origin,extra:0},...focusGlyphs]){
    tempWorld.copy(item.mesh.position).applyMatrix4(world.matrixWorld).applyMatrix4(camera.matrixWorldInverse);
    item.mesh.scale.setScalar(session?(item.extra?1.4:1):glyphScale(-tempWorld.z,height,camera.fov,camera.zoom,item.extra,item.point?radiusFactor(item.point):1));
  }
}
function render(){if(!renderer.getContext().isContextLost()){updateGlyphSizes();renderer.render(scene,camera);if(!$('debug').hidden)showDebug();}}
// Debug overlay: closed by default; reads only counters that already exist, and only while open.
let frameMeasure=null, frameRequest=null;
function showDebug(){
  if($('debug').hidden)return;
  const info=renderer.info.render, attributes=cloudMesh.geometry.attributes, ms=x=>x===undefined?'—':`${x.toFixed(1)} ms`;
  const bytes=lattice.abc.byteLength+lattice.xyz.byteLength+attributes.color.array.byteLength+attributes.aFactor.array.byteLength;
  const gl=renderer.getContext(),ext=gl.getExtension('WEBGL_debug_renderer_info');
  const rows=[
    ['Distinct lattice points (exact)',lattice.count.toLocaleString()],
    ['Bound (exact)',`b²+2a²+2c² ≤ ${radius}²${whole?'':', a>0, Δ<0'}`],
    ['GL point primitives (measured, last frame)',info.points.toLocaleString()],
    ['Triangles (measured, last frame)',info.triangles.toLocaleString()],
    ['Draw calls (measured, last frame)',info.calls],
    ['Enumerate lattice (measured CPU)',ms(timings.enumerate)],
    ['Fill point buffers (measured CPU)',ms(timings.attributes)],
    ['Recolor (measured CPU)',ms(timings.colors)],
    ['Size factors (measured CPU)',ms(timings.factors)],
    ['Klein images (measured CPU)',ms(timings.images)],
    ['Last click pick (measured CPU)',ms(timings.pick)],
    ['Lattice + point buffers (estimated)',`${(bytes/1048576).toFixed(1)} MB`],
    ['JS heap (measured, Chrome only)',performance.memory?`${(performance.memory.usedJSHeapSize/1048576).toFixed(0)} MB`:'unavailable'],
    ['Frame interval, 60 frames (measured, vsync-capped)',frameMeasure??'not measured'],
    ['GL renderer',ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER)],
  ];
  $('debug-rows').replaceChildren(...rows.flatMap(([k,v])=>{const dt=document.createElement('dt'),dd=document.createElement('dd');dt.textContent=k;dd.textContent=v;return [dt,dd];}));
}
function closeDebug(){
  if(frameRequest!==null)cancelAnimationFrame(frameRequest);
  frameRequest=null;$('debug-frames').disabled=false;
  $('debug').hidden=true;$('debug-toggle').setAttribute('aria-expanded','false');$('debug-toggle').focus();
}
$('debug-toggle').onclick=()=>{if(!$('debug').hidden){closeDebug();return;}$('debug').hidden=false;$('debug-toggle').setAttribute('aria-expanded','true');render();};
$('debug-close').onclick=closeDebug;
document.addEventListener('keydown',event=>{if(event.key==='Escape'&&!$('debug').hidden){event.preventDefault();event.stopPropagation();closeDebug();}},true);
$('debug-frames').onclick=()=>{
  if(frameRequest!==null||$('debug').hidden)return;
  $('debug-frames').disabled=true;
  const times=[];let last=performance.now();
  const step=now=>{
    frameRequest=null;if($('debug').hidden)return;
    times.push(now-last);last=now;render();
    if(times.length<60)frameRequest=requestAnimationFrame(step);
    else{times.sort((a,b)=>a-b);frameMeasure=`median ${times[30].toFixed(1)} ms · p90 ${times[54].toFixed(1)} ms`;$('debug-frames').disabled=false;showDebug();}
  };
  frameRequest=requestAnimationFrame(step);
};

const eyeAtOrigin=()=>inhabited&&camera.position.distanceTo(world.position)<1e-9;
function showLocation() {
  if(!inhabited)return;
  const p=camera.position.clone().sub(world.position).divideScalar(scale);
  $('location').textContent=`Eye (x,y,z): ${p.toArray().map(x=>x.toFixed(2)).join(', ')} · ${cameraPlaneLabel(camera.quaternion)}`;
  $('origin-note').hidden=!eyeAtOrigin();
  $('origin').setAttribute('aria-pressed',String(eyeAtOrigin()));
}
// Explicit yaw/pitch avoid re-deriving angles from a quaternion at the poles, so the eye can look exactly along ±Y.
function applyLook(){
  camera.quaternion.setFromEuler(new THREE.Euler(look.pitch,look.yaw,0,'YXZ'));
  controls.target.copy(camera.position).add(camera.getWorldDirection(new THREE.Vector3()));
  showLocation();render();
}
function beginEgocentric(){
  if(!inhabited)overviewView=captureView(camera,controls);
  inhabited=true;controls.enabled=false;camera.near=0.008;
  $('navigation').hidden=false;$('inhabit').textContent='Return to overview';$('view').disabled=true;
  renderer.domElement.focus({preventScroll:true});
}
function enterInhabit() {
  beginEgocentric();originMode=false;camera.fov=overviewFov;camera.updateProjectionMatrix();
  camera.position.copy(world.position).add(physical(vector(selected))).add(new THREE.Vector3(0.10,0.12,0.10));
  const aim=world.position.clone();aim.y=camera.position.y;camera.lookAt(aim);
  const e=new THREE.Euler().setFromQuaternion(camera.quaternion,'YXZ');look={yaw:e.y,pitch:e.x};applyLook();
}
// The coordinate origin is the zero polynomial: no unique root or projective point, and radial projection is
// undefined. Every line of sight from it is one projective class of nonzero forms, and looking along +Y the perspective image of the upper nappe is the Klein disk.
function enterOrigin() {
  beginEgocentric();originMode=true;glyphKey=null;camera.fov=originFov;camera.updateProjectionMatrix();
  camera.position.copy(world.position);look={yaw:0,pitch:Math.PI/2};applyLook();
}
function leaveInhabit() {
  if(!inhabited)return;
  inhabited=false;originMode=false;glyphKey=null;controls.enabled=true;camera.near=0.05;camera.fov=overviewFov;camera.updateProjectionMatrix();
  if(overviewView)restoreView(overviewView,camera,controls);overviewView=null;
  $('navigation').hidden=true;$('inhabit').textContent='Inhabit';$('view').disabled=false;
  $('origin').setAttribute('aria-pressed','false');render();
}
function moveEye(direction) {
  if(!inhabited)return;
  const forward=camera.getWorldDirection(new THREE.Vector3());
  const right=new THREE.Vector3(1,0,0).applyQuaternion(camera.quaternion);
  const delta=direction==='forward'?forward:direction==='back'?forward.negate():direction==='right'?right:direction==='left'?right.negate():new THREE.Vector3(0,direction==='up'?1:-1,0);
  delta.multiplyScalar(0.12);camera.position.add(delta);controls.target.add(delta);showLocation();render();
}
$('inhabit').onclick=()=>inhabited?leaveInhabit():enterInhabit();
// Origin is a location preset inside the egocentric mode; the Inhabit button alone toggles back to the overview.
$('origin').onclick=enterOrigin;
for(const button of document.querySelectorAll('[data-look]'))button.onclick=()=>{look.pitch={up:Math.PI/2,level:0,down:-Math.PI/2}[button.dataset.look];applyLook();renderer.domElement.focus({preventScroll:true});};
for(const button of document.querySelectorAll('[data-move]'))button.onclick=()=>{moveEye(button.dataset.move);renderer.domElement.focus({preventScroll:true});};
function resetView(){controls.target.copy(world.position);camera.position.copy(world.position).add(new THREE.Vector3(2.4,1.5,4.6).multiplyScalar(Math.max(1,radius/8)));controls.update();}
function resize(){if(session)return;const r=$('viewport').getBoundingClientRect();if(r.width<=0||r.height<=0)return;camera.aspect=r.width/r.height;camera.updateProjectionMatrix();renderer.setSize(r.width,r.height);render();}
$('next').onclick=()=>{const sequence=[...examples,[-1,1,-2],[1,2,1],[1,3,1]];const i=sequence.findIndex(p=>p.every((x,j)=>x===selected[j]));selectPoint(sequence[(i+1)%sequence.length]);};
// Her Star size control (0.4–2.5) scales every star radius.
$('star-size').oninput=()=>{sigma=Number($('star-size').value);$('star-size-value').textContent=sigma.toFixed(2);glyphKey=null;render();};
$('plane-focus').onchange=()=>{planeFocus=$('plane-focus').checked;update();};
$('palette').onchange=()=>{categories=$('palette').value;update();};
$('projection').onchange=()=>{projectionVisible=$('projection').checked;update();};
$('cone').onchange=update;
$('whole').onchange=()=>{whole=$('whole').checked;rebuild();update();};
$('symmetric-color').onchange=()=>{symmetricColor=$('symmetric-color').checked;update();};
$('radius').onchange=()=>{radius=Number($('radius').value);rebuild();if(!inhabited)resetView();update();};
$('view').onclick=()=>{camera.position.sub(controls.target).applyAxisAngle(new THREE.Vector3(0,1,0),Math.PI/3).add(controls.target);controls.update();};
$('reset').onclick=()=>{leaveInhabit();selected=examples[0];secondSelection=null;pairMessage='';radius=6;whole=true;symmetricColor=false;projectionVisible=false;$('radius').value='6';$('whole').checked=true;$('cone').checked=true;$('symmetric-color').checked=false;rebuild();resetView();update();};
function selectEntered(asPair=false) {
  const parts=$('coefficient').value.split(',').map(s=>s.trim()),next=parts.map(Number);
  if(parts.length!==3||parts.some(s=>!/^[-+]?\d+$/.test(s))||!shown(next)) {
    $('status').textContent='Choose a nonzero integer triple inside the current coefficient ball. The current selection is unchanged.';return;
  }
  selectPoint(next,asPair);
}
$('coefficient-form').onsubmit=event=>{event.preventDefault();selectEntered();};
$('pair-add').onclick=()=>selectEntered(true);
$('pair-clear').onclick=()=>{secondSelection=null;pairMessage='';update();$('pair-add').focus({preventScroll:true});};
const raycaster=new THREE.Raycaster(),pointer=new THREE.Vector2(),tap=new TapSelection();
// The ray is mapped into lattice units (a uniform scale and translation keep angles), then searched exactly.
function pickIndex(ray,maxAngle){
  const t=performance.now();
  cloudMesh.updateMatrixWorld(true);
  const inverse=new THREE.Matrix4().copy(cloudMesh.matrixWorld).invert();
  const o=ray.origin.clone().applyMatrix4(inverse), d=ray.direction.clone().transformDirection(inverse);
  const i=nearestToRayPacked(o.toArray(),d.toArray(),lattice.xyz,lattice.count,maxAngle,session?0:camera.near/scale);
  timings.pick=performance.now()-t;
  return i;
}
function pickPoint(ray,maxAngle,asPair=false){const i=pickIndex(ray,maxAngle);if(i>=0)selectPoint(tripleAt(lattice,i),asPair);}
// Desktop clicks select the nearest center within about 10 CSS pixels of the pointer.
function selectAt(event){const r=renderer.domElement.getBoundingClientRect();pointer.set(2*(event.clientX-r.left)/r.width-1,1-2*(event.clientY-r.top)/r.height);raycaster.setFromCamera(pointer,camera);pickPoint(raycaster.ray,10*2*Math.tan(camera.fov*Math.PI/360)/(r.height*camera.zoom),event.shiftKey);}
renderer.domElement.addEventListener('pointerdown',e=>{tap.begin(e);if(inhabited){lookDrag={x:e.clientX,y:e.clientY};renderer.domElement.setPointerCapture(e.pointerId);}});renderer.domElement.addEventListener('pointermove',e=>{
  tap.move(e);if(!inhabited||!lookDrag)return;
  look.yaw-=(e.clientX-lookDrag.x)*0.004;
  look.pitch=THREE.MathUtils.clamp(look.pitch-(e.clientY-lookDrag.y)*0.004,-Math.PI/2,Math.PI/2);
  lookDrag={x:e.clientX,y:e.clientY};applyLook();
});renderer.domElement.addEventListener('pointerup',e=>{lookDrag=null;if(tap.end(e)&&!session)selectAt(e);});renderer.domElement.addEventListener('pointercancel',e=>{lookDrag=null;tap.cancel(e);});
renderer.domElement.addEventListener('keydown',e=>{const move={w:'forward',s:'back',a:'left',d:'right',q:'down',e:'up'}[e.key.toLowerCase()];if(inhabited&&move){e.preventDefault();moveEye(move);return;}if(e.key==='Escape'&&inhabited){leaveInhabit();return;}if(e.key==='Home'){e.preventDefault();leaveInhabit();resetView();}if(['+','=','-'].includes(e.key)){e.preventDefault();if(inhabited){moveEye(e.key==='-'?'back':'forward');return;}const d=camera.position.distanceTo(controls.target),n=THREE.MathUtils.clamp(d*(e.key==='-'?1.1:1/1.1),controls.minDistance,controls.maxDistance);camera.position.sub(controls.target).multiplyScalar(n/d).add(controls.target);controls.update();}});
controls.addEventListener('change',render);window.addEventListener('resize',resize);new ResizeObserver(resize).observe($('viewport'));
const xrPanel=new THREE.Group();xrPanel.position.set(0,1,-1.15);xrPanel.visible=false;scene.add(xrPanel);const xrTargets=[];
for(const [i,label] of ['Next','Projection','Reset','Exit'].entries()) {
  const canvas=document.createElement('canvas');canvas.width=256;canvas.height=128;const ctx=canvas.getContext('2d');ctx.fillStyle='#142b38';ctx.fillRect(0,0,256,128);ctx.fillStyle='#fff';ctx.font='32px system-ui';ctx.textAlign='center';ctx.fillText(label,128,76);
  const button=new THREE.Mesh(new THREE.PlaneGeometry(0.22,0.11),new THREE.MeshBasicMaterial({map:new THREE.CanvasTexture(canvas)}));button.position.x=(i-1.5)*0.24;button.userData.action=()=>{if(i===3)session?.end();else $(['next','projection','reset'][i]).click();};xrTargets.push(button);xrPanel.add(button);
}
for(let i=0;i<2;i++){const controller=renderer.xr.getController(i);scene.add(controller);controller.addEventListener('select',()=>{controllerRay(controller,raycaster);const button=raycaster.intersectObjects(xrTargets)[0];if(button)button.object.userData.action();else pickPoint(raycaster.ray,0.02);});}
async function checkXR(){const availability=await xrAvailability(navigator.xr,isSecureContext);$('xr').disabled=!availability.supported;$('xr').textContent=availability.supported?'Enter VR':'VR unavailable here';$('xr-status').textContent=availability.message;}
$('xr').onclick=async()=>{if(startingXR||session)return;startingXR=true;$('xr').disabled=true;savedView=captureView(camera,controls);try{session=await navigator.xr.requestSession('immersive-vr',{optionalFeatures:['local-floor']});await renderer.xr.setSession(session);controls.enabled=false;xrPanel.visible=true;document.body.classList.add('immersive');renderer.setAnimationLoop(render);}catch{await session?.end().catch(()=>{});session=null;$('status').textContent='VR entry was cancelled or unavailable. The browser scene remains usable.';checkXR();}finally{startingXR=false;}};
renderer.xr.addEventListener('sessionend',()=>{session=null;controls.enabled=!inhabited;xrPanel.visible=false;document.body.classList.remove('immersive');renderer.setAnimationLoop(null);if(savedView)restoreView(savedView,camera,controls);savedView=null;resize();checkXR();});
renderer.domElement.addEventListener('webglcontextlost',e=>{e.preventDefault();$('fatal').hidden=false;$('fatal').textContent='3D graphics paused. Waiting for the browser to restore the graphics context; reload if it does not recover.';controls.enabled=false;$('xr').disabled=true;session?.end().catch(()=>{});});
renderer.domElement.addEventListener('webglcontextrestored',()=>{$('fatal').hidden=true;controls.enabled=!session&&!inhabited;resize();update();checkXR();});
for(const option of $('radius').querySelectorAll('optgroup option'))option.textContent=`${option.value} · ${ballCount(Number(option.value)).toLocaleString()} points`;
rebuild();resetView();resize();update();checkXR();
