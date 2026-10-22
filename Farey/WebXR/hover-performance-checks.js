// SPDX-License-Identifier: GPL-3.0-or-later
// MOCKED XR input (no XRSession): drives the real updateAims() each animation frame with a controller pose that
// rotates 2 mrad per frame. Records main-thread time spent in updateAims and whether a fresh preview was shown.
async page => {
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.route('**/starscape.js*',async route=>{const r=await route.fetch();await route.fulfill({response:r,body:await r.text()+`
window.__bench=(frames,rotation=0.002)=>new Promise(done=>{
  const a=aims[0],c=a.controller;a.source={handedness:'right',gamepad:null};a.next=0;xrPanel.visible=false;
  cloudMesh.updateMatrixWorld(true);const to=new THREE.Vector3(...vector([2,1,1])).applyMatrix4(cloudMesh.matrixWorld);
  c.position.set(0.4,1.6,0.6);c.updateMatrix();c.updateMatrixWorld(true);c.lookAt(c.position.clone().multiplyScalar(2).sub(to));c.updateMatrix();c.updateMatrixWorld(true);
  const longTasks=[];const po=new PerformanceObserver(l=>{for(const e of l.getEntries())longTasks.push(e.duration);});try{po.observe({entryTypes:['longtask']});}catch{}
  const cost=[],gaps=[];let shown=0,k=0,last=performance.now();
  const step=()=>{const now=performance.now();gaps.push(now-last);last=now;
    c.rotateY(rotation);c.updateMatrix();c.updateMatrixWorld(true);
    const t=performance.now();updateAims();cost.push(performance.now()-t);if(a.shown)shown++;
    if(++k<frames)requestAnimationFrame(step);else{po.disconnect();a.source=null;
      const s=x=>{const v=[...x].sort((p,q)=>p-q);return {median:+v[v.length>>1].toFixed(2),p95:+v[Math.floor(v.length*0.95)].toFixed(2),max:+v.at(-1).toFixed(2)};};
      done({points:lattice.count,frames,rotation,updateAimsMs:s(cost),framesOver4ms:cost.filter(x=>x>4).length,totalMainMs:+cost.reduce((p,q)=>p+q,0).toFixed(1),frameGapMs:s(gaps),longTasks:longTasks.map(x=>+x.toFixed(0)),freshPreviewFrames:shown,mainRealmHeapMB:performance.memory?+(performance.memory.usedJSHeapSize/1048576).toFixed(0):null,worker:typeof hoverQueries==='undefined'?null:{used:lattice.count>=hoverWorkerPoints&&!hoverQueries.failed,scanMs:hoverQueries.lastQueryMs&&+hoverQueries.lastQueryMs.toFixed(1),roundTripMs:hoverQueries.lastLatencyMs&&+hoverQueries.lastLatencyMs.toFixed(1),oneTimeCopyMs:hoverQueries.copyMs&&+hoverQueries.copyMs.toFixed(1),ownedBytes:hoverQueries.copyBytes}});}};
  requestAnimationFrame(step);});`});});
 const url=page.url();await page.reload();await page.waitForFunction(()=>window.__bench);
 const out={url};
 for(const r of ['6','96'])for(const step of [0.002,0]){await page.locator('#radius').selectOption(r);await page.waitForTimeout(300);out['R'+r+(step?' moving':' held')]=await page.evaluate(st=>window.__bench(120,st),step);}
 await page.unrouteAll();
 if(errors.length)throw Error(errors.join('; '));
 return out;
}
