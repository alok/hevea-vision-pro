// SPDX-License-Identifier: GPL-3.0-or-later
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { examples, vector, project, upperRoot, discriminant, height, kind, positiveRepresentative, polynomial } from './starscape-core.js';
import { xrAvailability, controllerRay, captureView, restoreView } from './xr-support.js';
import { TapSelection, nearestToRayPacked } from './input.js';
import { HoverQueries } from './hover-queries.js';
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
let hoverPointer=null, hoverFrame=0; // desktop pointer hover (see refreshHover)
const overviewFov=45, originFov=100;
let categories='viridis', glyphKey=null, focusGlyphs=[], sigma=1, planeFocus=false;
let latticeGeneration=0, secondSelection=null, pairMessage='', pairGlyphs=[], planeMembers=new Set(), originMode=false, timings={}, colorKey='', factorKey='';
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
  // A new lattice generation: worker answers still in flight for the old one are dropped on arrival.
  glyphKey=null;latticeGeneration++;hoverQueries.reset();showHover(null);
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
  $('polynomial-state').textContent=`f(x) = ${polynomial(selected)}`;
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
function render(){if(!renderer.getContext().isContextLost()){updateGlyphSizes();if(session)updateAims();renderer.render(scene,camera);if(!$('debug').hidden)showDebug();if(hoverPointer&&!session)scheduleHover();}}
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
    ['XR hover queries',lattice.count<hoverWorkerPoints?'main thread (small crop)':hoverQueries.failed?'main thread (worker unavailable)':'worker'],
    ['Worker scan / round trip (measured)',`${ms(hoverQueries.lastQueryMs)} / ${ms(hoverQueries.lastLatencyMs)}`],
    ['Lattice copy for worker (measured CPU)',ms(hoverQueries.copyMs)],
    ['Last transferred worker buffer',`${hoverQueries.copyBytes.toLocaleString()} bytes`],
    ['Lattice + point buffers (estimated)',`${(bytes/1048576).toFixed(1)} MB`],
    ['Main-realm JS heap (Chrome; excludes worker)',performance.memory?`${(performance.memory.usedJSHeapSize/1048576).toFixed(0)} MB`:'unavailable'],
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
function rayInLattice(ray){
  cloudMesh.updateMatrixWorld(true);
  const inverse=new THREE.Matrix4().copy(cloudMesh.matrixWorld).invert();
  return {origin:ray.origin.clone().applyMatrix4(inverse).toArray(),direction:ray.direction.clone().transformDirection(inverse).toArray(),minDistance:session?0:camera.near/scale};
}
function pickIndex(ray,maxAngle){
  const t=performance.now(), local=rayInLattice(ray);
  const i=nearestToRayPacked(local.origin,local.direction,lattice.xyz,lattice.count,maxAngle,local.minDistance);
  timings.pick=performance.now()-t;
  return i;
}
function pickPoint(ray,maxAngle,asPair=false){const i=pickIndex(ray,maxAngle);if(i>=0)selectPoint(tripleAt(lattice,i),asPair);}
// Desktop clicks select the nearest center within about 10 CSS pixels of the pointer.
const clickAngle=r=>10*2*Math.tan(camera.fov*Math.PI/360)/(r.height*camera.zoom);
function pointerRay(x,y){const r=renderer.domElement.getBoundingClientRect();pointer.set(2*(x-r.left)/r.width-1,1-2*(y-r.top)/r.height);raycaster.setFromCamera(pointer,camera);return {ray:raycaster.ray.clone(),angle:clickAngle(r)};}
function selectAt(event){const {ray,angle}=pointerRay(event.clientX,event.clientY);pickPoint(ray,angle,event.shiftKey);}
renderer.domElement.addEventListener('pointerdown',e=>{tap.begin(e);showHover(null);if(inhabited){lookDrag={x:e.clientX,y:e.clientY};renderer.domElement.setPointerCapture(e.pointerId);}});renderer.domElement.addEventListener('pointermove',e=>{
  tap.move(e);
  if(e.pointerType==='touch')hoverPointer=null;else hoverPointer={x:e.clientX,y:e.clientY};
  if(e.buttons||lookDrag)showHover(null);else scheduleHover();
  if(!inhabited||!lookDrag)return;
  look.yaw-=(e.clientX-lookDrag.x)*0.004;
  look.pitch=THREE.MathUtils.clamp(look.pitch-(e.clientY-lookDrag.y)*0.004,-Math.PI/2,Math.PI/2);
  lookDrag={x:e.clientX,y:e.clientY};applyLook();
});renderer.domElement.addEventListener('pointerup',e=>{lookDrag=null;if(tap.end(e)&&!session)selectAt(e);scheduleHover();});renderer.domElement.addEventListener('pointerleave',()=>{hoverPointer=null;showHover(null);});renderer.domElement.addEventListener('pointercancel',e=>{lookDrag=null;tap.cancel(e);});
renderer.domElement.addEventListener('keydown',e=>{const move={w:'forward',s:'back',a:'left',d:'right',q:'down',e:'up'}[e.key.toLowerCase()];if(inhabited&&move){e.preventDefault();moveEye(move);return;}if(e.key==='Escape'&&inhabited){leaveInhabit();return;}if(e.key==='Home'){e.preventDefault();leaveInhabit();resetView();}if(['+','=','-'].includes(e.key)){e.preventDefault();if(inhabited){moveEye(e.key==='-'?'back':'forward');return;}const d=camera.position.distanceTo(controls.target),n=THREE.MathUtils.clamp(d*(e.key==='-'?1.1:1/1.1),controls.minDistance,controls.maxDistance);camera.position.sub(controls.target).multiplyScalar(n/d).add(controls.target);controls.update();}});
controls.addEventListener('change',render);window.addEventListener('resize',resize);new ResizeObserver(resize).observe($('viewport'));
const xrPanel=new THREE.Group();xrPanel.position.set(0,1,-1.15);xrPanel.visible=false;scene.add(xrPanel);const xrTargets=[];
for(const [i,label] of ['Next','Projection','Reset','Exit'].entries()) {
  const canvas=document.createElement('canvas');canvas.width=256;canvas.height=128;const ctx=canvas.getContext('2d');ctx.fillStyle='#142b38';ctx.fillRect(0,0,256,128);ctx.fillStyle='#fff';ctx.font='32px system-ui';ctx.textAlign='center';ctx.fillText(label,128,76);
  const button=new THREE.Mesh(new THREE.PlaneGeometry(0.22,0.11),new THREE.MeshBasicMaterial({map:new THREE.CanvasTexture(canvas)}));button.position.x=(i-1.5)*0.24;button.userData.label=label;button.userData.action=()=>{if(i===3)session?.end();else $(['next','projection','reset'][i]).click();};xrTargets.push(button);xrPanel.add(button);
}
// XR aiming. The hover preview and the trigger use the same rule (aimTarget): an in-world button hit first,
// otherwise the lattice center nearest the controller ray within aimAngle. The trigger recomputes on its own
// ray, so after any movement, even below aimStale, it can pick a different point than the last preview; dense
// crops are not fully disambiguated. The viewer-facing ring uses distance × tan(aimAngle) as an approximate angular-scale cue, not a mathematical locus.
// Hover is cyan and never changes the selection; the selected point keeps its white outline.
const aimAngle=0.02, aimStale=0.001, aimColor=0x9fdcff;
const describe=p=>`(${p.join(', ')}) · ${polynomial(p)} · Δ = ${discriminant(p)}`;
const readoutCanvas=document.createElement('canvas');readoutCanvas.width=1024;readoutCanvas.height=190;
const readoutTexture=new THREE.CanvasTexture(readoutCanvas);
const readout=new THREE.Mesh(new THREE.PlaneGeometry(0.94,0.175),new THREE.MeshBasicMaterial({map:readoutTexture,transparent:true}));
readout.position.y=0.155;xrPanel.add(readout);let readoutText='';
function showReadout(lines){
  const text=lines.join('\n');if(text===readoutText)return;readoutText=text;
  const ctx=readoutCanvas.getContext('2d');ctx.clearRect(0,0,1024,190);ctx.fillStyle='#0b1218d9';ctx.fillRect(0,0,1024,190);
  ctx.font='28px ui-monospace,Menlo,monospace';lines.forEach((line,i)=>{ctx.fillStyle=line.includes(' aim ')?'#9fdcff':'#f0f5f8';ctx.fillText(line,18,40+i*44);});
  readoutTexture.needsUpdate=true;
}
// Crops at least this large answer hover in a module worker; smaller ones scan in well under a millisecond.
const hoverWorkerPoints=50000;
const hoverQueries=new HoverQueries(()=>new Worker(new URL('./aim-worker.js',import.meta.url),{type:'module'}));
// Desktop pointer hover names the exact signed polynomial of the point a click there would select: the same
// angular radius and nearest-center scan as selectAt. It never selects, pairs or moves the camera. Crops of
// hoverWorkerPoints or more ask the worker on their own slot with one query in flight, so pointer motion never
// scans a dense crop on the UI thread. As in XR, an answer is shown only for the ray it was computed from, so
// orbiting, zooming, Inhabit, a rebuild, a press, leaving the canvas or a session hides it until recomputed.
const pointerSlot='pointer';
hoverQueries.onsettled=slot=>{if(slot===pointerSlot)scheduleHover();};
function scheduleHover(){if(!hoverFrame)hoverFrame=requestAnimationFrame(refreshHover);}
function refreshHover(){
  hoverFrame=0;
  if(!hoverPointer||session||lookDrag||tap.active.size||renderer.getContext().isContextLost()){showHover(null);return;}
  const {ray,angle}=pointerRay(hoverPointer.x,hoverPointer.y);
  if(lattice.count>=hoverWorkerPoints&&hoverQueries.available){
    const result=hoverQueries.result(pointerSlot), fresh=result?.generation===latticeGeneration&&!rayMoved(ray,result.ray);
    showHover(fresh&&result.index>=0?result.index:null);
    if(!fresh&&!hoverQueries.busy(pointerSlot)){const local=rayInLattice(ray);hoverQueries.request(pointerSlot,latticeGeneration,lattice,local.origin,local.direction,angle,local.minDistance,ray);}
  } else {const index=pickIndex(ray,angle);showHover(index>=0?index:null);}
}
function showHover(index){
  const label=$('hover-label');
  if(index===null){label.hidden=true;label.dataset.point='';return;}
  const point=tripleAt(lattice,index), r=renderer.domElement.getBoundingClientRect();
  const v=new THREE.Vector3().fromArray(lattice.xyz,3*index).applyMatrix4(cloudMesh.matrixWorld).project(camera);
  $('hover-text').textContent=polynomial(point);label.dataset.point=point.join();
  label.style.transform=`translate(${r.left+(v.x+1)*r.width/2}px,${r.top+(1-v.y)*r.height/2}px)`;label.hidden=false;
}
function pointTarget(index,ray){
  const point=new THREE.Vector3().fromArray(lattice.xyz,3*index).applyMatrix4(cloudMesh.matrixWorld);
  return {index,point,distance:point.distanceTo(ray.origin)};
}
const rayMoved=(ray,from,distance=1)=>ray.direction.angleTo(from.direction)>aimStale||ray.origin.distanceTo(from.origin)>aimStale*distance;
// One staleness test for a hand: the preview is hidden, and a dense hand re-queries, under exactly the same condition.
const aimStaleFor=(aim,ray)=>rayMoved(ray,aim.scanned,aim.target?.distance??1);
function aimTarget(controller){
  controllerRay(controller,raycaster);
  const hit=raycaster.intersectObjects(xrTargets)[0];
  if(hit)return {button:hit.object,distance:hit.distance};
  const index=pickIndex(raycaster.ray,aimAngle);
  return index<0?null:pointTarget(index,raycaster.ray);
}
const aims=[0,1].map(i=>{
  const controller=renderer.xr.getController(i);scene.add(controller);
  const line=new THREE.Line(new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(),new THREE.Vector3(0,0,-1)]),new THREE.LineBasicMaterial({color:aimColor,transparent:true,opacity:0.35}));
  line.visible=false;controller.add(line);
  const ring=new THREE.Mesh(new THREE.RingGeometry(0.8,1,48),new THREE.MeshBasicMaterial({color:aimColor,transparent:true,opacity:0.9,side:THREE.DoubleSide,depthWrite:false}));
  ring.visible=false;ring.renderOrder=10;scene.add(ring);
  const aim={controller,line,ring,target:null,shown:null,next:0,source:null,scanned:new THREE.Ray(),index:i};
  controller.addEventListener('connected',e=>{aim.source=e.data;});
  controller.addEventListener('disconnected',()=>{aim.source=null;aim.target=aim.shown=null;line.visible=ring.visible=false;});
  controller.addEventListener('select',()=>{
    const target=aimTarget(controller);aim.target=target;aim.scanned.copy(raycaster.ray);aim.generation=latticeGeneration;
    if(target)aim.source?.gamepad?.hapticActuators?.[0]?.pulse?.(0.3,30);
    if(target?.button)target.button.userData.action();else if(target)selectPoint(tripleAt(lattice,target.index));
  });
  return aim;
});
let hoverGeneration=null;
function updateAims(){
  const now=performance.now(), eye=renderer.xr.getCamera();
  // Once per rebuilt lattice (radius, filter or reset), drop both hands' in-flight and answered worker queries.
  if(hoverGeneration!==latticeGeneration){hoverQueries.reset();hoverGeneration=latticeGeneration;}
  for(const aim of aims){
    aim.shown=null;
    if(!aim.source){aim.line.visible=aim.ring.visible=false;continue;}
    // A rebuilt lattice (radius, filter or reset) invalidates cached indices, positions and scan deadlines.
    if(aim.generation!==latticeGeneration){aim.target=null;aim.next=0;}
    aim.controller.updateWorldMatrix(true,false);cloudMesh.updateMatrixWorld();
    // A preview is shown only for the ray it was computed from: once the ray has moved more than aimStale it is
    // hidden until a newer answer arrives, while the trigger always recomputes on the current ray with the same
    // rule. Small crops, or a browser without a working module worker, scan here on the UI thread, waiting in
    // proportion to the scan's measured cost.
    controllerRay(aim.controller,raycaster);
    if(lattice.count>=hoverWorkerPoints&&hoverQueries.available){
      // Dense crops: buttons are hit-tested here (cheap, and they take priority); the point query runs in the worker.
      // The preview shows the latest answer for this generation, judged stale against the ray it was asked for.
      const hit=raycaster.intersectObjects(xrTargets)[0], result=hoverQueries.result(aim.index);
      if(hit){aim.target={button:hit.object,distance:hit.distance};aim.scanned.copy(raycaster.ray);}
      else if(result?.generation===latticeGeneration){aim.target=result.index<0?null:pointTarget(result.index,result.ray);aim.scanned.copy(result.ray);}
      else{aim.target=null;aim.scanned.copy(raycaster.ray);}
      aim.generation=latticeGeneration;
      if(!hit&&!hoverQueries.busy(aim.index)&&(result?.generation!==latticeGeneration||aimStaleFor(aim,raycaster.ray))){
        const local=rayInLattice(raycaster.ray);
        hoverQueries.request(aim.index,latticeGeneration,lattice,local.origin,local.direction,aimAngle,local.minDistance,raycaster.ray.clone());
      }
    } else if(now>=aim.next){const t=performance.now();aim.target=aimTarget(aim.controller);aim.scanned.copy(raycaster.ray);aim.generation=latticeGeneration;const cost=performance.now()-t;aim.next=now+(cost>4?8*cost:0);}
    const stale=aimStaleFor(aim,raycaster.ray);
    const target=aim.shown=stale?null:aim.target;
    aim.line.visible=true;aim.line.scale.z=target?target.distance:0.6;
    aim.ring.visible=!!target?.point;
    if(target?.point){aim.ring.position.copy(target.point);aim.ring.quaternion.copy(eye.quaternion);aim.ring.scale.setScalar(Math.max(target.distance*Math.tan(aimAngle),0.004));}
  }
  for(const button of xrTargets)button.material.color.setScalar(aims.some(a=>a.shown?.button===button)?1.6:1);
  // One aim line per connected hand, named by the input source's handedness, so each ring has its trigger.
  const hands=aims.filter(a=>a.source).sort((a,b)=>(a.source.handedness==='right')-(b.source.handedness==='right'));
  const aimLines=hands.map(a=>{
    const hand={left:'Left',right:'Right'}[a.source.handedness]??`Hand ${a.index+1}`;
    return `${hand} aim${' '.repeat(Math.max(1,6-hand.length))}${a.shown?.button?a.shown.button.userData.label:a.shown?describe(tripleAt(lattice,a.shown.index)):'—'}`;
  });
  const plane=currentPlane();
  showReadout([...aimLines,`Selected    ${describe(selected)}`,...(plane?[`Plane       ${plane.equation}`]:[])]);
}
async function checkXR(){const availability=await xrAvailability(navigator.xr,isSecureContext);$('xr').disabled=!availability.supported;$('xr').textContent=availability.supported?'Enter VR':'VR unavailable here';$('xr-status').textContent=availability.message;}
$('xr').onclick=async()=>{if(startingXR||session)return;startingXR=true;$('xr').disabled=true;savedView=captureView(camera,controls);try{session=await navigator.xr.requestSession('immersive-vr',{optionalFeatures:['local-floor']});await renderer.xr.setSession(session);controls.enabled=false;xrPanel.visible=true;document.body.classList.add('immersive');renderer.setAnimationLoop(render);}catch{await session?.end().catch(()=>{});session=null;$('status').textContent='VR entry was cancelled or unavailable. The browser scene remains usable.';checkXR();}finally{startingXR=false;}};
renderer.xr.addEventListener('sessionend',()=>{session=null;hoverQueries.reset();for(const aim of aims){aim.target=null;aim.line.visible=aim.ring.visible=false;}controls.enabled=!inhabited;xrPanel.visible=false;document.body.classList.remove('immersive');renderer.setAnimationLoop(null);if(savedView)restoreView(savedView,camera,controls);savedView=null;resize();checkXR();});
renderer.domElement.addEventListener('webglcontextlost',e=>{e.preventDefault();hoverQueries.reset();$('fatal').hidden=false;$('fatal').textContent='3D graphics paused. Waiting for the browser to restore the graphics context; reload if it does not recover.';controls.enabled=false;$('xr').disabled=true;session?.end().catch(()=>{});});
renderer.domElement.addEventListener('webglcontextrestored',()=>{$('fatal').hidden=true;controls.enabled=!session&&!inhabited;resize();update();checkXR();});
for(const option of $('radius').querySelectorAll('optgroup option'))option.textContent=`${option.value} · ${ballCount(Number(option.value)).toLocaleString()} points`;
rebuild();resetView();resize();update();checkXR();
