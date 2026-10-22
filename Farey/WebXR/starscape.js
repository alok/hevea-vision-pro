// SPDX-License-Identifier: GPL-3.0-or-later
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { stars, examples, vector, project, upperRoot, discriminant, height } from './starscape-core.js';
import { xrAvailability, controllerRay, captureView, restoreView } from './xr-support.js';
import { TapSelection, visibleIntersections } from './input.js';
const $ = id => document.getElementById(id);
const points = stars();
let selected = examples[0], projectionVisible = true, session = null, savedView = null, startingXR = false;
let renderer;
try { renderer = new THREE.WebGLRenderer({ antialias: true }); }
catch {
  $('fatal').hidden = false;
  $('fatal').textContent = 'WebGL is unavailable. The source links and mathematical explanation remain available.';
  document.querySelectorAll('.controls button, .controls input').forEach(control => { control.disabled = true; });
  $('xr').textContent = 'VR unavailable without WebGL';
  throw Error('WebGL unavailable');
}
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
renderer.xr.enabled = true; renderer.xr.setReferenceSpaceType('local-floor');
$('viewport').append(renderer.domElement);
renderer.domElement.tabIndex = 0;
renderer.domElement.setAttribute('role', 'img');
renderer.domElement.setAttribute('aria-label', 'Coefficient points at distinct depths inside a cone, with a radial projection disk');
const scene = new THREE.Scene(); scene.background = new THREE.Color(0);
scene.add(new THREE.HemisphereLight(0xc9e8ff, 0x31404a, 2.3));
const light = new THREE.DirectionalLight(0xffffff, 3); light.position.set(-2, 4, 3); scene.add(light);
const camera = new THREE.PerspectiveCamera(45, 1, 0.05, 60);
const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = false; controls.minDistance = 1; controls.maxDistance = 14; controls.listenToKeyEvents(renderer.domElement);
const world = new THREE.Group(); world.position.set(0, 0.45, -3.1); scene.add(world);
const scale = 0.23;
const physical = p => new THREE.Vector3(...p).multiplyScalar(scale);
const cloud = new THREE.Group(), disk = new THREE.Group(), focus = new THREE.Group(); world.add(cloud,disk,focus);
const sphere = new THREE.SphereGeometry(0.027, 12, 8);
const dots = [];
const orange = new THREE.MeshStandardMaterial({color: 0xffa140, roughness: 0.35});
const white = new THREE.MeshBasicMaterial({color: 0xffffff});
const imageMaterial = new THREE.MeshBasicMaterial({color: 0x54e9f5});
for (const point of points) {
  const material = new THREE.MeshStandardMaterial({color:new THREE.Color().setHSL(0.52+0.25*(-discriminant(point))/64,0.65,0.6),roughness:0.35});
  const dot = new THREE.Mesh(sphere,material); dot.position.copy(physical(vector(point)));
  dot.userData.point = point; dot.userData.baseMaterial = material; cloud.add(dot); dots.push(dot);
  const image = new THREE.Mesh(sphere,imageMaterial); image.scale.setScalar(0.42); image.position.copy(physical(project(point))); disk.add(image);
}
function lines(paths,color,opacity=1) {
  const vertices=[];
  for(const path of paths) for(let i=1;i<path.length;i++) vertices.push(...path[i-1],...path[i]);
  const geometry=new THREE.BufferGeometry(); geometry.setAttribute('position',new THREE.Float32BufferAttribute(vertices,3));
  return new THREE.LineSegments(geometry,new THREE.LineBasicMaterial({color,transparent:opacity<1,opacity}));
}
function circle(h) { return Array.from({length:65},(_,i)=>[scale*h*Math.cos(i*Math.PI/32),scale*h,scale*h*Math.sin(i*Math.PI/32)]); }
function surface(h,opacity) {
  const vertices=[],ring=circle(h);
  for(let i=0;i<64;i++) vertices.push(0,h===height?h*scale:0,0,...ring[i],...ring[i+1]);
  const geometry=new THREE.BufferGeometry(); geometry.setAttribute('position',new THREE.Float32BufferAttribute(vertices,3));
  return new THREE.Mesh(geometry,new THREE.MeshBasicMaterial({color:0x54e9f5,transparent:true,opacity,side:THREE.DoubleSide,depthWrite:false}));
}
world.add(surface(8,0.035)); disk.add(surface(height,0.11));
world.add(lines([circle(8),...Array.from({length:8},(_,i)=>[[0,0,0],circle(8)[i*8]])],0x54e9f5,0.35));
disk.add(lines([circle(height)],0x54e9f5,0.9));
const origin = new THREE.Mesh(sphere,white); origin.scale.setScalar(1.5); world.add(origin);
function clearFocus() {
  for(const object of [...focus.children]) { focus.remove(object); if(object.geometry!==sphere) object.geometry.dispose(); if(object.material!==white) object.material.dispose(); }
}
function update() {
  for(const dot of dots) { const active=dot.userData.point.every((x,i)=>x===selected[i]); dot.material=active?orange:dot.userData.baseMaterial; dot.scale.setScalar(active?1.8:1); }
  clearFocus(); disk.visible=projectionVisible;
  focus.add(lines([[ [0,0,0],physical(vector(selected)).toArray() ]],0xffa140));
  if(projectionVisible) {
    const image=physical(project(selected)); focus.add(lines([[[0,0,0],image.toArray()]],0xffffff));
    const marker=new THREE.Mesh(sphere,white); marker.position.copy(image); marker.scale.setScalar(1.5); focus.add(marker);
  }
  const root=upperRoot(selected);
  $('point-state').textContent=`(a,b,c) = (${selected.join(', ')}) · Δ = ${discriminant(selected)}`;
  $('root-state').textContent=`Upper root: ${root[0].toFixed(3)} + ${root[1].toFixed(3)}i`;
  $('coefficient').value=selected.join(','); $('projection').checked=projectionVisible;
  $('status').textContent=`${points.length} coefficient points · a+c≤8 · stationary until you move the view`;
  renderer.domElement.setAttribute('aria-description',`Selected coefficient point ${selected.join(', ')}. Discriminant ${discriminant(selected)}. Projection ${projectionVisible?'shown':'hidden'}.`);
  render();
}
function render() { if(!renderer.getContext().isContextLost()) renderer.render(scene,camera); }
function resetView() { controls.target.set(0,1.35,-3.1); camera.position.set(2.4,2.8,1.0); controls.update(); }
function resize() { if(session)return; const rect=$('viewport').getBoundingClientRect(); if(rect.width<=0||rect.height<=0)return; camera.aspect=rect.width/rect.height; camera.updateProjectionMatrix(); renderer.setSize(rect.width,rect.height); render(); }
$('next').onclick=()=>{ const index=examples.findIndex(p=>p.every((x,i)=>x===selected[i])); selected=examples[(index+1)%examples.length]; update(); };
$('projection').onchange=()=>{projectionVisible=$('projection').checked;update();};
$('view').onclick=()=>{camera.position.sub(controls.target).applyAxisAngle(new THREE.Vector3(0,1,0),Math.PI/3).add(controls.target);controls.update();};
$('reset').onclick=()=>{selected=examples[0];projectionVisible=true;resetView();update();};
$('coefficient-form').onsubmit=event=>{event.preventDefault();const parts=$('coefficient').value.split(',').map(s=>s.trim());const next=parts.map(Number);if(parts.length!==3||parts.some(s=>!/^[-+]?\d+$/.test(s))||!points.some(p=>p.every((x,i)=>x===next[i]))){$('status').textContent='Choose a displayed integer triple: a,c≥1, a+c≤8 and b²<4ac. The current selection is unchanged.';return;}selected=next;update();};
const raycaster=new THREE.Raycaster(), pointer=new THREE.Vector2(), tap=new TapSelection();
function selectAt(event) { const rect=renderer.domElement.getBoundingClientRect(); pointer.set(2*(event.clientX-rect.left)/rect.width-1,1-2*(event.clientY-rect.top)/rect.height);raycaster.setFromCamera(pointer,camera);const hit=visibleIntersections(raycaster,dots)[0];if(hit){selected=hit.object.userData.point;update();} }
renderer.domElement.addEventListener('pointerdown',e=>tap.begin(e)); renderer.domElement.addEventListener('pointermove',e=>tap.move(e));renderer.domElement.addEventListener('pointerup',e=>{if(tap.end(e)&&!session)selectAt(e);});renderer.domElement.addEventListener('pointercancel',e=>tap.cancel(e));
renderer.domElement.addEventListener('keydown',e=>{if(e.key==='Home'){e.preventDefault();resetView();}if(['+','=','-'].includes(e.key)){e.preventDefault();const distance=camera.position.distanceTo(controls.target),next=THREE.MathUtils.clamp(distance*(e.key==='-'?1.1:1/1.1),1,14);camera.position.sub(controls.target).multiplyScalar(next/distance).add(controls.target);controls.update();}});
controls.addEventListener('change',render);window.addEventListener('resize',resize);
new ResizeObserver(resize).observe($('viewport'));
const xrPanel=new THREE.Group();xrPanel.position.set(0,1,-1.15);xrPanel.visible=false;scene.add(xrPanel);const xrTargets=[];
for(const [i,label] of ['Next','Projection','Reset','Exit'].entries()) {
  const canvas=document.createElement('canvas');canvas.width=256;canvas.height=128;const ctx=canvas.getContext('2d');ctx.fillStyle='#142b38';ctx.fillRect(0,0,256,128);ctx.fillStyle='#fff';ctx.font='32px system-ui';ctx.textAlign='center';ctx.fillText(label,128,76);
  const button=new THREE.Mesh(new THREE.PlaneGeometry(0.22,0.11),new THREE.MeshBasicMaterial({map:new THREE.CanvasTexture(canvas)}));button.position.x=(i-1.5)*0.24;button.userData.action=()=>{if(i===3)session?.end();else $(['next','projection','reset'][i]).click();};xrTargets.push(button);xrPanel.add(button);
}
for(let i=0;i<2;i++){const controller=renderer.xr.getController(i);scene.add(controller);controller.addEventListener('select',()=>{controllerRay(controller,raycaster);const hit=visibleIntersections(raycaster,[...xrTargets,...dots])[0];if(hit?.object.userData.action)hit.object.userData.action();else if(hit){selected=hit.object.userData.point;update();}});}
async function checkXR(){const availability=await xrAvailability(navigator.xr,isSecureContext);$('xr').disabled=!availability.supported;$('xr').textContent=availability.supported?'Enter VR':'VR unavailable here';$('xr-status').textContent=availability.message;}
$('xr').onclick=async()=>{if(startingXR||session)return;startingXR=true;$('xr').disabled=true;savedView=captureView(camera,controls);try{session=await navigator.xr.requestSession('immersive-vr',{optionalFeatures:['local-floor']});await renderer.xr.setSession(session);controls.enabled=false;xrPanel.visible=true;document.body.classList.add('immersive');renderer.setAnimationLoop(render);}catch{await session?.end().catch(()=>{});session=null;$('status').textContent='VR entry was cancelled or unavailable. The browser scene remains usable.';checkXR();}finally{startingXR=false;}};
renderer.xr.addEventListener('sessionend',()=>{session=null;controls.enabled=true;xrPanel.visible=false;document.body.classList.remove('immersive');renderer.setAnimationLoop(null);if(savedView)restoreView(savedView,camera,controls);savedView=null;resize();checkXR();});
renderer.domElement.addEventListener('webglcontextlost',e=>{e.preventDefault();$('fatal').hidden=false;$('fatal').textContent='3D graphics paused. Waiting for the browser to restore the graphics context; reload if it does not recover.';controls.enabled=false;$('xr').disabled=true;session?.end().catch(()=>{});});
renderer.domElement.addEventListener('webglcontextrestored',()=>{$('fatal').hidden=true;controls.enabled=!session;resize();update();checkXR();});
resetView();resize();update();checkXR();
