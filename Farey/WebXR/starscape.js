// SPDX-License-Identifier: GPL-3.0-or-later
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { examples, vector, project, upperRoot, discriminant, height, kind, coefficientLattice, positiveRepresentative } from './starscape-core.js';
import { xrAvailability, controllerRay, captureView, restoreView } from './xr-support.js';
import { TapSelection, nearestToRay } from './input.js';
import { cameraPlaneLabel } from './camera-planes.js';
import { coefficientColor, gradientCSS, paletteRange, glyphRadius, glyphScale, outlinePixels, drawnPixels, pixelsPerWorld, sourceRadiusFactor } from './appearance.js';
import { pairPlane, planeSection, coneDirections, necklaceMembers } from './pair-plane.js';
const $ = id => document.getElementById(id);
let radius = 6, whole = true, symmetricColor = false, projectionVisible = false;
let selected = examples[0], points = [], cloudMesh, imageMesh;
let session = null, savedView = null, startingXR = false;
let inhabited=false, overviewView=null, lookDrag=null, look={yaw:0,pitch:0};
const overviewFov=45, originFov=100;
let categories='contrast', glyphKey=null, focusGlyphs=[];
let secondSelection=null, pairMessage='', pairGlyphs=[], planeMembers=new Set(), baseColors=[], originMode=false;
let renderer;
try { renderer = new THREE.WebGLRenderer({ antialias: true }); }
catch {
  $('fatal').hidden = false;
  $('fatal').textContent = 'WebGL is unavailable. The source links and mathematical explanation remain available.';
  document.querySelectorAll('.controls button, .controls input, .controls select').forEach(c => { c.disabled = true; });
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
const cloudMaterial = new THREE.MeshBasicMaterial();
const white = new THREE.MeshBasicMaterial({ color: 0xffffff });
const imageMaterial = new THREE.MeshBasicMaterial({ color: 0x54e9f5 });
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
  points = coefficientLattice(radius).filter(p=>whole || kind(p)==='upper');
  baseColors = points.map(pointColor);
  cloudMesh = new THREE.InstancedMesh(sphere, cloudMaterial, points.length);
  points.forEach((p,i)=>{ cloudMesh.setMatrixAt(i,matrix.makeTranslation(...physical(vector(p)).toArray())); cloudMesh.setColorAt(i,pointColor(p)); });
  cloudMesh.instanceMatrix.needsUpdate=true; cloudMesh.instanceColor.needsUpdate=true;
  cloudMesh.computeBoundingSphere(); cloud.add(cloudMesh);
  const images = points.map(positiveRepresentative).filter(Boolean).map(p=>project(p));
  imageMesh = new THREE.InstancedMesh(sphere,imageMaterial,images.length);
  images.forEach((p,i)=>{ matrix.makeScale(0.4,0.4,0.4); matrix.setPosition(physical(p)); imageMesh.setMatrixAt(i,matrix); });
  imageMesh.instanceMatrix.needsUpdate=true; imageMesh.computeBoundingSphere(); disk.add(imageMesh);
  disk.add(surface(height,true,0.1), lines([circle(height)],0x54e9f5,0.8));
  for(const sign of [-1,1]) {
    const h=radius*sign;
    cone.add(surface(h,false,0.018));
    cone.add(lines([circle(h),...Array.from({length:8},(_,i)=>[[0,0,0],circle(h)[i*8]])],0x7896a8,0.26));
  }
}
const origin = new THREE.Mesh(sphere,white); world.add(origin);
function selectPoint(point,asPair=false) {
  if(asPair) {
    const result=pairPlane(selected,point);
    if(result.error){pairMessage=result.error;$('pair-status').textContent=pairMessage;$('pair-status').hidden=false;return;}
    secondSelection=[...point];
  } else {selected=[...point];secondSelection=null;}
  pairMessage='';update();
  if(asPair)$('pair-details').scrollIntoView({block:'nearest'});
}
function updatePair() {
  $('pair-status').textContent=pairMessage;$('pair-status').hidden=!pairMessage;
  $('pair-details').hidden=!secondSelection;$('pair-clear').hidden=!secondSelection;
  if(!secondSelection)return;
  const plane=pairPlane(selected,secondSelection), members=necklaceMembers(plane,points);
  planeMembers=new Set(members.map(p=>p.join()));
  const root=upperRoot(positiveRepresentative(secondSelection));
  $('pair-second').textContent=`Second point: (${secondSelection.join(', ')}) · Δ = ${discriminant(secondSelection)} · root ${root[0].toFixed(3)} + ${root[1].toFixed(3)}i`;
  $('pair-equation').textContent=`Plane: ${plane.equation}`;
  $('pair-endpoints').textContent=`Geodesic endpoints: ${plane.endpoints.map(p=>p.label).join(' and ')}`;
  const secondVisible=points.some(p=>p.every((x,i)=>x===secondSelection[i]));
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
  if(points.some(p=>p.every((x,i)=>x===secondSelection[i]))) {
    const marker=new THREE.Mesh(sphere,pairMaterial);marker.position.copy(physical(vector(secondSelection)));
    focus.add(marker);focusGlyphs.push({mesh:marker,extra:outlinePixels,point:secondSelection});
  }
  if(projectionVisible)focus.add(lines([directions.map(p=>p.map(x=>height*scale*x))],0xffba6b,0.9));
}
function update() {
  baseColors=points.map(pointColor);planeMembers=new Set();
  disposeChildren(focus);focusGlyphs=[];pairGlyphs=[];glyphKey=null; disk.visible=projectionVisible; cone.visible=$('cone').checked;
  const inCloud=points.some(p=>p.every((x,i)=>x===selected[i]));
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
  $('status').textContent=`${points.length} integer triples · radius ${radius}${inCloud?'':' · selected point hidden by this filter/crop'}`;
  $('inhabit').disabled=!inCloud&&!inhabited;
  updatePair();
  renderer.domElement.setAttribute('aria-description',`Selected coefficient point ${selected.join(', ')}. ${kind(selected)} region. ${points.length} points. Both cone halves ${cone.visible?'shown':'hidden'}.`);
  const [lo,hi]=paletteRange, reach=Math.max(0,...points.map(p=>-discriminant(p)));
  $('palette-bar').style.background=gradientCSS();
  $('palette-label').textContent=`Interior |Δ|, log scale · this crop reaches ${reach}`;
  $('palette-low').textContent=lo;$('palette-high').textContent=hi;
  render();
}
const tempLocal=new THREE.Vector3(),tempWorld=new THREE.Vector3(),tempColor=new THREE.Color();
// Which of her size causes applies: the origin-eye rule in Origin mode, plane emphasis for upper members.
const radiusFactor=p=>sourceRadiusFactor(p,{origin:originMode,onPlane:!originMode&&kind(p)==='upper'&&planeMembers.has(p.join()),symmetric:symmetricColor});
function updateGlyphSizes(){
  if(!cloudMesh)return;
  camera.updateMatrixWorld();world.updateMatrixWorld(true);
  const height=renderer.domElement.clientHeight;
  const key=camera.matrixWorld.elements.join(',')+'|'+height+'|'+camera.zoom+'|'+session+'|'+camera.fov;
  if(key===glyphKey)return;glyphKey=key;
  // Her overview fog: alpha falls by up to 55% between d−0.7R and d+0.9R from the eye (none in eye mode).
  const d=camera.position.distanceTo(controls.target), R=radius*scale, fogNear=Math.max(0.1*scale,d-0.7*R), fogFar=d+0.9*R;
  points.forEach((p,i)=>{
    tempLocal.copy(physical(vector(p)));
    tempWorld.copy(tempLocal).applyMatrix4(world.matrixWorld).applyMatrix4(camera.matrixWorldInverse);
    const depth=-tempWorld.z, factor=radiusFactor(p);
    let size=1, dim=1;
    if(!session&&depth>0){
      const base=glyphRadius*pixelsPerWorld(depth,height,camera.fov,camera.zoom), drawn=drawnPixels(base*factor);
      size=drawn.px/base;dim=drawn.dim*(inhabited?1:1-0.55*THREE.MathUtils.smoothstep(depth,fogNear,fogFar));
    }
    matrix.makeScale(size,size,size);matrix.setPosition(tempLocal);cloudMesh.setMatrixAt(i,matrix);
    cloudMesh.setColorAt(i,tempColor.copy(baseColors[i]).multiplyScalar(dim));
  });
  cloudMesh.instanceMatrix.needsUpdate=true;cloudMesh.instanceColor.needsUpdate=true;
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
function render(){if(!renderer.getContext().isContextLost()){updateGlyphSizes();renderer.render(scene,camera);}}

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
$('origin').onclick=()=>eyeAtOrigin()?leaveInhabit():enterOrigin();
for(const button of document.querySelectorAll('[data-look]'))button.onclick=()=>{look.pitch={up:Math.PI/2,level:0,down:-Math.PI/2}[button.dataset.look];applyLook();renderer.domElement.focus({preventScroll:true});};
for(const button of document.querySelectorAll('[data-move]'))button.onclick=()=>{moveEye(button.dataset.move);renderer.domElement.focus({preventScroll:true});};
function resetView(){controls.target.copy(world.position);camera.position.copy(world.position).add(new THREE.Vector3(2.4,1.5,4.6).multiplyScalar(Math.max(1,radius/8)));controls.update();}
function resize(){if(session)return;const r=$('viewport').getBoundingClientRect();if(r.width<=0||r.height<=0)return;camera.aspect=r.width/r.height;camera.updateProjectionMatrix();renderer.setSize(r.width,r.height);render();}
$('next').onclick=()=>{const sequence=[...examples,[-1,1,-2],[1,2,1],[1,3,1]];const i=sequence.findIndex(p=>p.every((x,j)=>x===selected[j]));selectPoint(sequence[(i+1)%sequence.length]);};
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
  if(parts.length!==3||parts.some(s=>!/^[-+]?\d+$/.test(s))||!coefficientLattice(radius).some(p=>p.every((x,i)=>x===next[i]))) {
    $('status').textContent='Choose a nonzero integer triple inside the current coefficient ball. The current selection is unchanged.';return;
  }
  selectPoint(next,asPair);
}
$('coefficient-form').onsubmit=event=>{event.preventDefault();selectEntered();};
$('pair-add').onclick=()=>selectEntered(true);
$('pair-clear').onclick=()=>{secondSelection=null;pairMessage='';update();$('pair-add').focus({preventScroll:true});};
const raycaster=new THREE.Raycaster(),pointer=new THREE.Vector2(),tap=new TapSelection();
function pickPoint(ray,maxAngle,asPair=false){
  world.updateMatrixWorld(true);
  const centers=points.map(p=>tempLocal.copy(physical(vector(p))).applyMatrix4(world.matrixWorld).toArray());
  const i=nearestToRay(ray.origin.toArray(),ray.direction.toArray(),centers,maxAngle,session?0:camera.near);
  if(i>=0)selectPoint(points[i],asPair);
}
// Desktop clicks select the nearest center within about 10 CSS pixels of the pointer.
function selectAt(event){const r=renderer.domElement.getBoundingClientRect();pointer.set(2*(event.clientX-r.left)/r.width-1,1-2*(event.clientY-r.top)/r.height);raycaster.setFromCamera(pointer,camera);pickPoint(raycaster.ray,10*2*Math.tan(camera.fov*Math.PI/360)/(r.height*camera.zoom),event.shiftKey);}
renderer.domElement.addEventListener('pointerdown',e=>{tap.begin(e);if(inhabited){lookDrag={x:e.clientX,y:e.clientY};renderer.domElement.setPointerCapture(e.pointerId);}});renderer.domElement.addEventListener('pointermove',e=>{
  tap.move(e);if(!inhabited||!lookDrag)return;
  look.yaw-=(e.clientX-lookDrag.x)*0.004;
  look.pitch=THREE.MathUtils.clamp(look.pitch-(e.clientY-lookDrag.y)*0.004,-Math.PI/2,Math.PI/2);
  lookDrag={x:e.clientX,y:e.clientY};applyLook();
});renderer.domElement.addEventListener('pointerup',e=>{lookDrag=null;if(tap.end(e)&&!session)selectAt(e);});renderer.domElement.addEventListener('pointercancel',e=>{lookDrag=null;tap.cancel(e);});
renderer.domElement.addEventListener('keydown',e=>{const move={w:'forward',s:'back',a:'left',d:'right',q:'down',e:'up'}[e.key.toLowerCase()];if(inhabited&&move){e.preventDefault();moveEye(move);return;}if(e.key==='Escape'&&inhabited){leaveInhabit();return;}if(e.key==='Home'){e.preventDefault();leaveInhabit();resetView();}if(['+','=','-'].includes(e.key)){e.preventDefault();if(inhabited){moveEye(e.key==='-'?'back':'forward');return;}const d=camera.position.distanceTo(controls.target),n=THREE.MathUtils.clamp(d*(e.key==='-'?1.1:1/1.1),1,20);camera.position.sub(controls.target).multiplyScalar(n/d).add(controls.target);controls.update();}});
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
rebuild();resetView();resize();update();checkXR();
