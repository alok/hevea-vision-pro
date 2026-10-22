// SPDX-License-Identifier: GPL-3.0-or-later
// Test-only instrumentation for an already-served loopback build. It MOCKS XR input: no XRSession exists here.
// Each controller gets a fake XRInputSource ({handedness, gamepad: null}) and a pose written into the controller
// group's own matrix (XR controller groups have matrixAutoUpdate = false, so the mock updates that matrix itself;
// app code never does). updateAims() is called directly, as the XR animation loop would. Run real IWE separately.
async page => {
  if(!['127.0.0.1','localhost'].includes(new URL(page.url()).hostname))throw Error('Use loopback');
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.route('**/starscape.js*',async route=>{
    const response=await route.fetch();
    await route.fulfill({response,body:await response.text()+`
window.__aim={
  world:p=>new THREE.Vector3(...vector(p)).applyMatrix4(cloudMesh.matrixWorld).toArray(),
  // MOCK: point controller k at a world position (its target ray is local −Z).
  mockPose:(k,from,to)=>{const c=aims[k].controller,f=new THREE.Vector3().fromArray(from);
    c.position.copy(f);c.updateMatrix();c.updateMatrixWorld(true);
    c.lookAt(f.clone().multiplyScalar(2).sub(new THREE.Vector3().fromArray(to)));c.updateMatrix();c.updateMatrixWorld(true);},
  mockRotate:(k,angle)=>{const c=aims[k].controller;c.rotateX(angle);c.updateMatrix();c.updateMatrixWorld(true);},
  mockConnect:k=>{aims[k].source={handedness:k?'right':'left',gamepad:null};aims[k].next=0;xrPanel.visible=true;xrPanel.updateMatrixWorld(true);},
  frame:()=>{cloudMesh.updateMatrixWorld();updateAims();
    return {aims:aims.map(a=>({ring:a.ring.visible?a.ring.position.toArray():null,ringRadius:a.ring.scale.x,line:a.line.scale.z,
      shown:a.shown?.button?a.shown.button.userData.label:a.shown?tripleAt(lattice,a.shown.index):null,deferredMs:a.next-performance.now()})),
      lines:readoutText.split(String.fromCharCode(10)),selected:[...selected],buttonColors:xrTargets.map(b=>b.material.color.r)};},
  defer:k=>{aims[k].next=performance.now()+1e6;},
  freshPick:k=>{controllerRay(aims[k].controller,raycaster);const i=pickIndex(raycaster.ray,aimAngle);return i<0?null:tripleAt(lattice,i);},
  trigger:k=>{aims[k].controller.dispatchEvent({type:'select'});return [...selected];},
  buttonWorld:i=>{xrPanel.updateMatrixWorld(true);return new THREE.Vector3().setFromMatrixPosition(xrTargets[i].matrixWorld).toArray();},
  generationOk:k=>aims[k].generation===latticeGeneration,
  endSession:()=>{renderer.xr.dispatchEvent({type:'sessionend'});return aims.map(a=>a.line.visible||a.ring.visible);}};`});
  });
  await page.reload();await page.waitForFunction(()=>window.__aim);
  const call=(name,...args)=>page.evaluate(([n,a])=>window.__aim[n](...a),[name,args]);
  const near=(a,b,e=1e-6)=>a.every((x,i)=>Math.abs(x-b[i])<e);
  const out={};
  const left=[0.4,1.6,0.6], right=[-0.4,1.6,0.6];

  // One hand: the preview ring sits on the point the trigger then selects; hover never changes the selection.
  await call('mockConnect',0);
  const target=await call('world',[2,1,1]);
  await call('mockPose',0,left,target);
  const hover=await call('frame'), distance=Math.hypot(...target.map((v,i)=>v-left[i]));
  if(hover.aims[0].shown?.join()!=='2,1,1'||!near(hover.aims[0].ring,target))throw Error('hover target '+JSON.stringify(hover.aims[0]));
  if(Math.abs(hover.aims[0].line-distance)>1e-6||Math.abs(hover.aims[0].ringRadius-distance*Math.tan(0.02))>1e-9)throw Error('ray or ring size');
  if(hover.selected.join()==='2,1,1'||hover.lines[0]!=='Left aim  (2, 1, 1) · Δ = -7')throw Error('hover readout '+JSON.stringify(hover.lines));
  out.oneHand={readout:hover.lines,selected:await call('trigger',0)};
  if(out.oneHand.selected.join()!=='2,1,1')throw Error('trigger did not select the previewed point');

  // A button preview must not outlive its ray: with the next scan deferred, moving away clears the highlight.
  const button=await call('buttonWorld',0);
  await call('mockPose',0,[button[0],button[1],button[2]+0.6],button);
  const onButton=await call('frame');
  if(onButton.aims[0].shown!=='Next'||onButton.buttonColors[0]<=1||onButton.buttonColors[1]!==1)throw Error('button hover '+JSON.stringify(onButton.buttonColors));
  await call('defer',0);await call('mockRotate',0,0.2);
  const movedOff=await call('frame');
  if(movedOff.buttonColors[0]!==1||movedOff.lines[0]!=='Left aim  —')throw Error('stale button highlight '+JSON.stringify(movedOff));
  out.button={hover:onButton.lines[0],afterMove:movedOff.lines[0]};

  // Dense crop: scans back off by their own cost; after the ray moves the stale ring hides and the trigger uses the current ray.
  await page.locator('#radius').selectOption('96');
  await call('mockPose',0,left,await call('world',[2,1,1]));
  const dense=await call('frame');
  await call('mockRotate',0,0.005);
  const nudged=await call('frame'), fresh=await call('freshPick',0);
  if(dense.aims[0].shown?.join()!=='2,1,1'||!(dense.aims[0].deferredMs>0&&dense.aims[0].deferredMs<1e5))throw Error('dense scan did not run and back off '+JSON.stringify(dense.aims[0]));
  if(!(nudged.aims[0].deferredMs>0)||nudged.aims[0].ring)throw Error('dense stale preview '+JSON.stringify(nudged.aims[0]));
  const denseSelected=await call('trigger',0);
  if(denseSelected.join()!==fresh?.join())throw Error('trigger did not recompute on the current ray');
  out.dense={previewed:dense.aims[0].shown,backoffMs:+dense.aims[0].deferredMs.toFixed(1),selectedAfterMove:denseSelected};

  // Reset rebuilds the lattice (R96 to R6) while a dense hover is cached; the cached index must not be reused.
  await call('defer',0);
  await page.locator('#reset').click();
  const afterReset=await call('frame');
  if(!(await call('generationOk',0))||(afterReset.aims[0].ring&&!near(afterReset.aims[0].ring,await call('world',afterReset.aims[0].shown))))throw Error('stale lattice target after reset');
  out.reset={shownAfterReset:afterReset.aims[0].shown};

  // Two hands aim at different points: the readout names each hand, and each trigger selects its own target.
  await call('mockConnect',1);
  await call('mockPose',0,left,await call('world',[1,0,1]));
  await call('mockPose',1,right,await call('world',[2,1,1]));
  const both=await call('frame');
  if(both.lines[0]!=='Left aim  (1, 0, 1) · Δ = -4'||both.lines[1]!=='Right aim (2, 1, 1) · Δ = -7')throw Error('hand readout '+JSON.stringify(both.lines));
  const rightSelected=await call('trigger',1), leftSelected=await call('trigger',0);
  if(rightSelected.join()!=='2,1,1'||leftSelected.join()!=='1,0,1')throw Error('hand selection');
  out.twoHands={readout:both.lines.slice(0,3),rightSelected,leftSelected};

  if((await call('endSession')).some(Boolean))throw Error('aim visuals survive session end');
  if(errors.length)throw Error(errors.join('\n'));
  await page.unrouteAll();await page.reload();
  return {passed:true,mocked:'XR input and poses are mocked; no XRSession',...out};
}
