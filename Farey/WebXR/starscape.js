// SPDX-License-Identifier: GPL-3.0-or-later
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { examples, vector, project, upperRoot, discriminant, height, kind, coefficientLattice, positiveRepresentative } from './starscape-core.js';
import { xrAvailability, controllerRay, captureView, restoreView } from './xr-support.js';
import { TapSelection } from './input.js';
const $ = id => document.getElementById(id);
let radius = 6, whole = true, symmetricColor = false, projectionVisible = false;
let selected = examples[0], points = [], cloudMesh, imageMesh;
let session = null, savedView = null, startingXR = false;
let inhabited=false, overviewView=null, lookDrag=null;
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
scene.add(new THREE.HemisphereLight(0xc9e8ff, 0x31404a, 2.3));
const light = new THREE.DirectionalLight(0xffffff, 3); light.position.set(-2, 4, 3); scene.add(light);
const camera = new THREE.PerspectiveCamera(45, 1, 0.05, 60);
const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = false; controls.minDistance = 1; controls.maxDistance = 20;
controls.listenToKeyEvents(renderer.domElement);
const world = new THREE.Group(); world.position.set(0, 1.4, -3.1); scene.add(world);
const scale = 0.16, physical = p => new THREE.Vector3(...p).multiplyScalar(scale);
const cloud = new THREE.Group(), disk = new THREE.Group(), cone = new THREE.Group(), focus = new THREE.Group();
world.add(cloud, disk, cone, focus);
const sphere = new THREE.SphereGeometry(0.023, 12, 8);
const cloudMaterial = new THREE.MeshStandardMaterial({ roughness: 0.35 });
const white = new THREE.MeshBasicMaterial({ color: 0xffffff });
const imageMaterial = new THREE.MeshBasicMaterial({ color: 0x54e9f5 });
const palette = ['#F06A6A','#E99456','#D6BD69','#7AB89B','#70A6D8','#AD92D0'].map(c => new THREE.Color(c));
function pointColor(point) {
  const type = kind(point);
  if (type === 'null') return new THREE.Color(0xd6bd69);
  if (type === 'exterior') return new THREE.Color(0x448abb);
  if (type === 'lower' && !symmetricColor) return new THREE.Color(0x64717d);
  const t = THREE.MathUtils.clamp(Math.log(-discriminant(point)/3)/Math.log(80), 0, 1) * (palette.length-1);
  const i = Math.min(palette.length-2, Math.floor(t));
  return palette[i].clone().lerp(palette[i+1],t-i);
}
function disposeChildren(group) {
  for (const object of [...group.children]) {
    group.remove(object);
    if (object.geometry && object.geometry !== sphere) object.geometry.dispose();
    if (object.material && ![white,imageMaterial,cloudMaterial].includes(object.material)) object.material.dispose();
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
  disposeChildren(cloud); disposeChildren(disk); disposeChildren(cone);
  points = coefficientLattice(radius).filter(p=>whole || kind(p)==='upper');
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
    cone.add(surface(h,false,0.035));
    cone.add(lines([circle(h),...Array.from({length:8},(_,i)=>[[0,0,0],circle(h)[i*8]])],0x54e9f5,0.4));
  }
}
const origin = new THREE.Mesh(sphere,white); origin.scale.setScalar(1.3); world.add(origin);
function update() {
  points.forEach((p,i)=>cloudMesh.setColorAt(i,p.every((x,j)=>x===selected[j])?new THREE.Color(0xffa140):pointColor(p)));
  cloudMesh.instanceColor.needsUpdate=true;
  disposeChildren(focus); disk.visible=projectionVisible; cone.visible=$('cone').checked;
  const inCloud=points.some(p=>p.every((x,i)=>x===selected[i]));
  if(inCloud) {
    focus.add(lines([[[0,0,0],physical(vector(selected)).toArray()]],0xffa140));
    const marker=new THREE.Mesh(sphere,new THREE.MeshBasicMaterial({color:0xffa140}));
    marker.position.copy(physical(vector(selected)));marker.scale.setScalar(1.5);focus.add(marker);
  }
  const representative=positiveRepresentative(selected);
  if(projectionVisible && representative && inCloud) {
    const image=physical(project(representative));focus.add(lines([[[0,0,0],image.toArray()]],0xffffff));
    const marker=new THREE.Mesh(sphere,white);marker.position.copy(image);marker.scale.setScalar(1.5);focus.add(marker);
  }
  $('point-state').textContent=`(a,b,c) = (${selected.join(', ')}) · Δ = ${discriminant(selected)}`;
  const root=representative?upperRoot(representative):null;
  $('root-state').textContent=root?`Upper root: ${root[0].toFixed(3)} + ${root[1].toFixed(3)}i${kind(selected)==='lower'?' · sign-flipped representative':''}`:kind(selected)==='null'?(selected[0]===0?'Boundary: double root at infinity':'Boundary: repeated real root'):'Exterior: real roots (outside the Klein disk)';
  $('coefficient').value=selected.join(',');$('projection').checked=projectionVisible;
  $('status').textContent=`${points.length} integer triples · radius ${radius}${inCloud?'':' · selected point hidden by this filter/crop'}`;
  $('inhabit').disabled=!inCloud&&!inhabited;
  renderer.domElement.setAttribute('aria-description',`Selected coefficient point ${selected.join(', ')}. ${kind(selected)} region. ${points.length} points. Both cone halves ${cone.visible?'shown':'hidden'}.`);
  render();
}
function render(){if(!renderer.getContext().isContextLost())renderer.render(scene,camera);}
function showLocation() {
  if(!inhabited)return;
  const p=camera.position.clone().sub(world.position).divideScalar(scale);
  const look=new THREE.Euler().setFromQuaternion(camera.quaternion,'YXZ');
  $('location').textContent=`Eye (x,y,z): ${p.toArray().map(x=>x.toFixed(2)).join(', ')} · yaw ${(look.y*180/Math.PI).toFixed(0)}°, pitch ${(look.x*180/Math.PI).toFixed(0)}° · Euclidean view`;
}
function enterInhabit() {
  overviewView=captureView(camera,controls); inhabited=true; controls.enabled=false;
  camera.position.copy(world.position).add(physical(vector(selected))).add(new THREE.Vector3(0.10,0.12,0.10));
  const aim=world.position.clone();aim.y=camera.position.y;camera.lookAt(aim);
  controls.target.copy(camera.position).add(camera.getWorldDirection(new THREE.Vector3()));
  camera.near=0.008;camera.updateProjectionMatrix();
  $('navigation').hidden=false;$('inhabit').textContent='Return to overview';$('view').disabled=true;
  renderer.domElement.focus({preventScroll:true});
  showLocation();render();
}
function leaveInhabit() {
  if(!inhabited)return;
  inhabited=false;controls.enabled=true;camera.near=0.05;camera.updateProjectionMatrix();
  if(overviewView)restoreView(overviewView,camera,controls);overviewView=null;
  $('navigation').hidden=true;$('inhabit').textContent='Inhabit';$('view').disabled=false;render();
}
function moveEye(direction) {
  if(!inhabited)return;
  const forward=camera.getWorldDirection(new THREE.Vector3());
  const right=new THREE.Vector3().crossVectors(forward,camera.up).normalize();
  const delta=direction==='forward'?forward:direction==='back'?forward.negate():direction==='right'?right:direction==='left'?right.negate():new THREE.Vector3(0,direction==='up'?1:-1,0);
  delta.multiplyScalar(0.12);camera.position.add(delta);controls.target.add(delta);showLocation();render();
}
$('inhabit').onclick=()=>inhabited?leaveInhabit():enterInhabit();
for(const button of document.querySelectorAll('[data-move]'))button.onclick=()=>{moveEye(button.dataset.move);renderer.domElement.focus({preventScroll:true});};
function resetView(){controls.target.copy(world.position);camera.position.copy(world.position).add(new THREE.Vector3(2.4,1.5,4.6).multiplyScalar(Math.max(1,radius/8)));controls.update();}
function resize(){if(session)return;const r=$('viewport').getBoundingClientRect();if(r.width<=0||r.height<=0)return;camera.aspect=r.width/r.height;camera.updateProjectionMatrix();renderer.setSize(r.width,r.height);render();}
$('next').onclick=()=>{const sequence=[...examples,[-1,1,-2],[1,2,1],[1,3,1]];const i=sequence.findIndex(p=>p.every((x,j)=>x===selected[j]));selected=sequence[(i+1)%sequence.length];update();};
$('projection').onchange=()=>{projectionVisible=$('projection').checked;update();};
$('cone').onchange=update;
$('whole').onchange=()=>{whole=$('whole').checked;rebuild();update();};
$('symmetric-color').onchange=()=>{symmetricColor=$('symmetric-color').checked;update();};
$('radius').onchange=()=>{radius=Number($('radius').value);rebuild();if(!inhabited)resetView();update();};
$('view').onclick=()=>{camera.position.sub(controls.target).applyAxisAngle(new THREE.Vector3(0,1,0),Math.PI/3).add(controls.target);controls.update();};
$('reset').onclick=()=>{leaveInhabit();selected=examples[0];radius=6;whole=true;symmetricColor=false;projectionVisible=false;$('radius').value='6';$('whole').checked=true;$('cone').checked=true;$('symmetric-color').checked=false;rebuild();resetView();update();};
$('coefficient-form').onsubmit=event=>{
  event.preventDefault();const parts=$('coefficient').value.split(',').map(s=>s.trim()),next=parts.map(Number);
  if(parts.length!==3||parts.some(s=>!/^[-+]?\d+$/.test(s))||!coefficientLattice(radius).some(p=>p.every((x,i)=>x===next[i]))) {
    $('status').textContent='Choose a nonzero integer triple inside the current coefficient ball. The current selection is unchanged.';return;
  }
  selected=next;update();
};
const raycaster=new THREE.Raycaster(),pointer=new THREE.Vector2(),tap=new TapSelection();
function activate(hit){if(!hit)return;if(hit.object.userData.action)hit.object.userData.action();else if(hit.object===cloudMesh && hit.instanceId!==undefined){selected=points[hit.instanceId];update();}}
function selectAt(event){const r=renderer.domElement.getBoundingClientRect();pointer.set(2*(event.clientX-r.left)/r.width-1,1-2*(event.clientY-r.top)/r.height);raycaster.setFromCamera(pointer,camera);activate(raycaster.intersectObject(cloudMesh)[0]);}
renderer.domElement.addEventListener('pointerdown',e=>{tap.begin(e);if(inhabited){lookDrag={x:e.clientX,y:e.clientY};renderer.domElement.setPointerCapture(e.pointerId);}});renderer.domElement.addEventListener('pointermove',e=>{
  tap.move(e);if(!inhabited||!lookDrag)return;
  const rotation=new THREE.Euler().setFromQuaternion(camera.quaternion,'YXZ');
  rotation.y-=(e.clientX-lookDrag.x)*0.004;
  rotation.x=THREE.MathUtils.clamp(rotation.x-(e.clientY-lookDrag.y)*0.004,-1.45,1.45);
  camera.quaternion.setFromEuler(rotation);
  controls.target.copy(camera.position).add(camera.getWorldDirection(new THREE.Vector3()));
  lookDrag={x:e.clientX,y:e.clientY};showLocation();render();
});renderer.domElement.addEventListener('pointerup',e=>{lookDrag=null;if(tap.end(e)&&!session)selectAt(e);});renderer.domElement.addEventListener('pointercancel',e=>{lookDrag=null;tap.cancel(e);});
renderer.domElement.addEventListener('keydown',e=>{const move={w:'forward',s:'back',a:'left',d:'right',q:'down',e:'up'}[e.key.toLowerCase()];if(inhabited&&move){e.preventDefault();moveEye(move);return;}if(e.key==='Escape'&&inhabited){leaveInhabit();return;}if(e.key==='Home'){e.preventDefault();leaveInhabit();resetView();}if(['+','=','-'].includes(e.key)){e.preventDefault();if(inhabited){moveEye(e.key==='-'?'back':'forward');return;}const d=camera.position.distanceTo(controls.target),n=THREE.MathUtils.clamp(d*(e.key==='-'?1.1:1/1.1),1,20);camera.position.sub(controls.target).multiplyScalar(n/d).add(controls.target);controls.update();}});
controls.addEventListener('change',render);window.addEventListener('resize',resize);new ResizeObserver(resize).observe($('viewport'));
const xrPanel=new THREE.Group();xrPanel.position.set(0,1,-1.15);xrPanel.visible=false;scene.add(xrPanel);const xrTargets=[];
for(const [i,label] of ['Next','Projection','Reset','Exit'].entries()) {
  const canvas=document.createElement('canvas');canvas.width=256;canvas.height=128;const ctx=canvas.getContext('2d');ctx.fillStyle='#142b38';ctx.fillRect(0,0,256,128);ctx.fillStyle='#fff';ctx.font='32px system-ui';ctx.textAlign='center';ctx.fillText(label,128,76);
  const button=new THREE.Mesh(new THREE.PlaneGeometry(0.22,0.11),new THREE.MeshBasicMaterial({map:new THREE.CanvasTexture(canvas)}));button.position.x=(i-1.5)*0.24;button.userData.action=()=>{if(i===3)session?.end();else $(['next','projection','reset'][i]).click();};xrTargets.push(button);xrPanel.add(button);
}
for(let i=0;i<2;i++){const controller=renderer.xr.getController(i);scene.add(controller);controller.addEventListener('select',()=>{controllerRay(controller,raycaster);activate(raycaster.intersectObjects([...xrTargets,cloudMesh])[0]);});}
async function checkXR(){const availability=await xrAvailability(navigator.xr,isSecureContext);$('xr').disabled=!availability.supported;$('xr').textContent=availability.supported?'Enter VR':'VR unavailable here';$('xr-status').textContent=availability.message;}
$('xr').onclick=async()=>{if(startingXR||session)return;startingXR=true;$('xr').disabled=true;savedView=captureView(camera,controls);try{session=await navigator.xr.requestSession('immersive-vr',{optionalFeatures:['local-floor']});await renderer.xr.setSession(session);controls.enabled=false;xrPanel.visible=true;document.body.classList.add('immersive');renderer.setAnimationLoop(render);}catch{await session?.end().catch(()=>{});session=null;$('status').textContent='VR entry was cancelled or unavailable. The browser scene remains usable.';checkXR();}finally{startingXR=false;}};
renderer.xr.addEventListener('sessionend',()=>{session=null;controls.enabled=!inhabited;xrPanel.visible=false;document.body.classList.remove('immersive');renderer.setAnimationLoop(null);if(savedView)restoreView(savedView,camera,controls);savedView=null;resize();checkXR();});
renderer.domElement.addEventListener('webglcontextlost',e=>{e.preventDefault();$('fatal').hidden=false;$('fatal').textContent='3D graphics paused. Waiting for the browser to restore the graphics context; reload if it does not recover.';controls.enabled=false;$('xr').disabled=true;session?.end().catch(()=>{});});
renderer.domElement.addEventListener('webglcontextrestored',()=>{$('fatal').hidden=true;controls.enabled=!session&&!inhabited;resize();update();checkXR();});
rebuild();resetView();resize();update();checkXR();
