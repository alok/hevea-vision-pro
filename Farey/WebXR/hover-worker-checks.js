// SPDX-License-Identifier: GPL-3.0-or-later
// Test-only instrumentation for an already-served loopback build. XR input is MOCKED (no XRSession; controller
// poses are written into the controller groups' own matrices), but the hover worker is the REAL module worker
// loaded from the served package. Checks: worker answers equal the main thread's nearestToRayPacked on the same
// rays (R48, R96), the transferred lattice copy size, two hands, reset and session end while a query is in flight,
// and a worker that cannot load (served 404) falling back to the main thread.
async page => {
 if(!['127.0.0.1','localhost'].includes(new URL(page.url()).hostname))throw Error('Use loopback');
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 const hook=`
window.__w={
  sleep:ms=>new Promise(r=>setTimeout(r,ms)),
  pose:(k,from,to)=>{const a=aims[k],c=a.controller,f=new THREE.Vector3().fromArray(from);a.source={handedness:k?'right':'left',gamepad:null};
    c.position.copy(f);c.updateMatrix();c.updateMatrixWorld(true);c.lookAt(f.clone().multiplyScalar(2).sub(new THREE.Vector3().fromArray(to)));c.updateMatrix();c.updateMatrixWorld(true);},
  world:p=>new THREE.Vector3(...vector(p)).applyMatrix4(cloudMesh.matrixWorld).toArray(),
  frame:()=>{cloudMesh.updateMatrixWorld();updateAims();return aims.map(a=>a.shown?.index!==undefined?tripleAt(lattice,a.shown.index):a.shown?.button?a.shown.button.userData.label:null);},
  settle:async(k,frames=120)=>{for(let i=0;i<frames;i++){const s=__w.frame();if(s[k]&&!hoverQueries.busy(k))return s;await new Promise(r=>requestAnimationFrame(r));}return __w.frame();},
  exact:async n=>{let seed=7;const rnd=()=>(seed=(seed*1103515245+12345)%2147483648)/2147483648;let same=0,hits=0;const ms=[];
    cloudMesh.updateMatrixWorld(true);hoverQueries.reset();
    for(let i=0;i<n;i++){const to=new THREE.Vector3(...vector([Math.round(rnd()*8-4),Math.round(rnd()*8-4),Math.round(rnd()*8-4)])).applyMatrix4(cloudMesh.matrixWorld);
      const ray=new THREE.Ray(new THREE.Vector3(0.3*rnd(),1.6,0.6),new THREE.Vector3());ray.direction.copy(to).sub(ray.origin).normalize();
      ray.direction.x+=0.004*(rnd()-0.5);ray.direction.normalize();
      const local=rayInLattice(ray),main=nearestToRayPacked(local.origin,local.direction,lattice.xyz,lattice.count,aimAngle,local.minDistance);
      while(hoverQueries.busy(0))await __w.sleep(2);
      const t=performance.now();hoverQueries.request(0,latticeGeneration,lattice,local.origin,local.direction,aimAngle,local.minDistance,ray);
      while(hoverQueries.busy(0))await __w.sleep(1);ms.push(performance.now()-t);
      const r=hoverQueries.result(0);if(r?.index===main)same++;if(main>=0)hits++;}
    ms.sort((a,b)=>a-b);return {rays:n,sameIndex:same,raysWithAPoint:hits,roundTripMs:{median:+ms[ms.length>>1].toFixed(1),max:+ms.at(-1).toFixed(1)},scanMs:+hoverQueries.lastQueryMs.toFixed(1),copyMs:+hoverQueries.copyMs.toFixed(1),workerBufferBytes:hoverQueries.copyBytes,points:lattice.count};},
  state:()=>({generation:latticeGeneration,result0:hoverQueries.result(0),busy0:hoverQueries.busy(0),failed:hoverQueries.failed,count:lattice.count}),
  trigger:k=>{aims[k].controller.dispatchEvent({type:'select'});return [...selected];},
  // Hold hand 0 at a distance straight in front of (2,1,1); after the worker's preview arrives, translate the hand by
  // shift metres without rotating and keep holding for up to frames animation frames. The refreshed preview is
  // compared with the main thread's exact pick on the current ray (it need not be (2,1,1) again).
  held:async(distance,shift,frames=60)=>{
    xrPanel.visible=false;cloudMesh.updateMatrixWorld(true);
    const a=aims[0],c=a.controller,target=new THREE.Vector3(...vector([2,1,1])).applyMatrix4(cloudMesh.matrixWorld);
    a.source={handedness:'left',gamepad:null};hoverQueries.reset();
    c.position.copy(target).add(new THREE.Vector3(0,0,distance));c.updateMatrix();c.updateMatrixWorld(true);
    c.lookAt(c.position.clone().multiplyScalar(2).sub(target));c.updateMatrix();c.updateMatrixWorld(true);
    const before=(await __w.settle(0))[0], selectedBefore=[...selected], targetDistance=a.target?.distance??null;
    c.position.x+=shift;c.updateMatrix();c.updateMatrixWorld(true);
    let requeried=false,recoveredAt=null,shownEveryFrame=true;
    for(let i=0;i<frames;i++){const shown=__w.frame()[0];if(hoverQueries.busy(0))requeried=true;
      if(!shown)shownEveryFrame=false;else if(recoveredAt===null&&!shownEveryFrame)recoveredAt=i;
      await new Promise(r=>requestAnimationFrame(r));}
    controllerRay(c,raycaster);const result=hoverQueries.result(0),exact=pickIndex(raycaster.ray,aimAngle);
    return {distance,shift,targetDistance,threshold:targetDistance&&aimStale*targetDistance,before,after:__w.frame()[0],exactOnCurrentRay:exact<0?null:tripleAt(lattice,exact),requeried,shownEveryFrame,recoveredAt,busy:hoverQueries.busy(0),
      queryOriginDelta:result?result.ray.origin.distanceTo(raycaster.ray.origin):null,selectedUnchanged:selected.join()===selectedBefore.join()};},
  endSession:()=>{renderer.xr.dispatchEvent({type:'sessionend'});return aims.map(a=>a.line.visible||a.ring.visible);}};`;
 const inject=async(blockWorker=false)=>{await page.unrouteAll();
   await page.route('**/starscape.js*',async route=>{const r=await route.fetch();await route.fulfill({response:r,body:await r.text()+hook});});
   if(blockWorker)await page.route('**/aim-worker.js*',route=>route.fulfill({status:404,body:'not found'}));
   await page.reload();await page.waitForFunction(()=>window.__w);};
 const call=(n,...a)=>page.evaluate(([n,a])=>window.__w[n](...a),[n,a]);
 const out={};
 await inject();
 // Display and worker refresh share one staleness test, scaled by the target's distance (0.2 m here, so 0.2 mm).
 // Translating 0.5 mm (above it) must re-query and show the exact pick for the new ray; 0.1 mm (below it) must keep
 // the same preview without a query. Control from 20 m (outside the 7.68 m R48 ball): whatever is hit first, its
 // distance makes the threshold exceed 0.5 mm, so the same translation keeps that preview without a query.
 await page.locator('#radius').selectOption('48');
 const near=out.nearHeld=await call('held',0.2,0.0005), small=out.nearHeldBelowThreshold=await call('held',0.2,0.0001), far=out.farHeld=await call('held',20,0.0005);
 if(String(near.before)!=='2,1,1'||!near.requeried||near.after===null||String(near.after)!==String(near.exactOnCurrentRay)||near.busy||near.queryOriginDelta>1e-9||!near.selectedUnchanged)throw Error('near held hover did not refresh '+JSON.stringify(near));
 if(!(Math.abs(near.threshold-0.0002)<1e-9))throw Error('unexpected target distance '+JSON.stringify(near));
 if(!far.before||!(far.threshold>0.0005)||far.requeried||!far.shownEveryFrame||String(far.after)!==String(far.before)||!far.selectedUnchanged)throw Error('far control '+JSON.stringify(far));
 if(String(small.before)!=='2,1,1'||small.requeried||!small.shownEveryFrame||String(small.after)!=='2,1,1'||!small.selectedUnchanged)throw Error('below-threshold control '+JSON.stringify(small));
 for(const r of ['48','96']){await page.locator('#radius').selectOption(r);const x=out['exactR'+r]=await call('exact',40);
   if(x.sameIndex!==40)throw Error('worker index differs '+JSON.stringify(x));
   if(x.workerBufferBytes!==12*x.points)throw Error('worker lattice copy is '+x.workerBufferBytes+' bytes');}
 // two hands at R96 through the worker
 const left=[0.4,1.6,0.6],right=[-0.4,1.6,0.6];
 await call('pose',0,left,await call('world',[1,0,1]));await call('pose',1,right,await call('world',[2,1,1]));
 await call('settle',0);const both=await call('settle',1);out.twoHands={shown:both,rightSelects:await call('trigger',1),leftSelects:await call('trigger',0)};
 if(String(both[0])!=='1,0,1'||String(both[1])!=='2,1,1'||out.twoHands.rightSelects.join()!=='2,1,1'||out.twoHands.leftSelects.join()!=='1,0,1')throw Error('two hands '+JSON.stringify(out.twoHands));
 // reset while a dense query is in flight
 await call('pose',0,left,await call('world',[2,-1,1]));await call('frame');
 const inFlight=await call('state');await page.locator('#reset').click();await call('sleep',150);const afterReset=await call('state');const shownAfter=await call('frame');
 out.resetInFlight={wasBusy:inFlight.busy0,countAfter:afterReset.count,resultAfter:afterReset.result0,shownAfter:shownAfter[0]};
 if(!inFlight.busy0||afterReset.result0!==null||afterReset.count!==480)throw Error('reset in flight '+JSON.stringify(out.resetInFlight));
 // session end while a dense query is in flight
 await page.locator('#radius').selectOption('96');await call('pose',0,left,await call('world',[1,0,1]));await call('frame');
 const before=await call('state');const hidden=await call('endSession');await call('sleep',150);const afterEnd=await call('state');
 out.sessionEnd={wasBusy:before.busy0,visualsHidden:!hidden.some(Boolean),resultAfter:afterEnd.result0};
 if(!before.busy0||afterEnd.result0!==null||hidden.some(Boolean))throw Error('session end '+JSON.stringify(out.sessionEnd));
 // real worker load failure: hover falls back to the main thread
 await inject(true);await page.locator('#radius').selectOption('96');await call('pose',0,left,await call('world',[2,1,1]));
 let shown=null;for(let i=0;i<40&&!shown;i++){shown=(await call('frame'))[0];await call('sleep',20);}
 const failState=await call('state');out.workerFailure={failed:failState.failed,fallbackShown:shown,selected:await call('trigger',0)};
 if(!failState.failed||String(shown)!=='2,1,1'||out.workerFailure.selected.join()!=='2,1,1')throw Error('fallback '+JSON.stringify(out.workerFailure));
 await page.unrouteAll();await page.reload();
 if(errors.length)throw Error(errors.join('; '));
 return {passed:true,mocked:'XR input mocked; real module worker',...out};
}
