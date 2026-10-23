// SPDX-License-Identifier: GPL-3.0-or-later
// Test-only instrumentation for an already-served loopback build: desktop pointer hover names the exact signed
// polynomial of the point a click there would select, without selecting it or moving the camera, and a dense crop
// is answered by the worker with no UI-thread scan per pointer move.
async page => {
  if(!['127.0.0.1','localhost'].includes(new URL(page.url()).hostname))throw Error('Use loopback');
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.route('**/starscape.js*',async route=>{
    const response=await route.fetch();
    await route.fulfill({response,body:await response.text()+`
const __pick=pickIndex;let __picks=0;pickIndex=(...args)=>{__picks++;return __pick(...args);};
window.__hover={
  snapshot:()=>({selected:[...selected],camera:camera.position.toArray(),quaternion:camera.quaternion.toArray(),count:lattice.count,generation:latticeGeneration,label:$('hover-label').hidden?null:{point:$('hover-label').dataset.point,text:$('hover-text').textContent},inspector:$('polynomial-state').textContent,picks:__picks,workerMs:hoverQueries.lastQueryMs,worker:lattice.count>=hoverWorkerPoints&&hoverQueries.available,failed:hoverQueries.failed,busy:hoverQueries.busy(pointerSlot)}),
  screen:p=>{const r=renderer.domElement.getBoundingClientRect(),v=world.localToWorld(physical(vector(p))).project(camera);return {x:r.x+(v.x+1)*r.width/2,y:r.y+(1-v.y)*r.height/2};},
  // The click rule on the current camera, scanned directly (test oracle; not counted as a UI pick).
  oracle:(x,y)=>{const {ray,angle}=pointerRay(x,y),i=__pick(ray,angle);return i<0?null:tripleAt(lattice,i).join();},
  // Pixel distance from p's center to the nearest other drawn center: projected neighbors can make a hover
  // legitimately name a different point than the one aimed at.
  isolation:p=>{const r=renderer.domElement.getBoundingClientRect(),s=window.__hover.screen(p),v=new THREE.Vector3();let best=Infinity;
    for(let i=0;i<lattice.count;i++){const q=tripleAt(lattice,i);if(q.join()===p.join())continue;v.fromArray(lattice.xyz,3*i).applyMatrix4(cloudMesh.matrixWorld).project(camera);best=Math.min(best,Math.hypot(r.x+(v.x+1)*r.width/2-s.x,r.y+(1-v.y)*r.height/2-s.y));}return best;},
  // A pixel x,y where the click rule differs dx CSS pixels to the right, below the XR 1 mrad tolerance, scanning a grid (test-only scans).
  split:(x0,y0,w,h,step,dx)=>{const o=window.__hover.oracle;for(let y=y0;y<y0+h;y+=step)for(let x=x0;x<x0+w;x+=step){const a=o(x,y),b=o(x+dx,y);
    if(a&&b&&a!==b){const da=pointerRay(x,y).ray.direction.clone(),db=pointerRay(x+dx,y).ray.direction.clone();if(da.angleTo(db)<0.001)return {x,y,a,b,angle:da.angleTo(db)};}}return null;},
  // Every animation frame for ms: the pointer position hover last saw and the label it showed.
  watch:ms=>new Promise(done=>{const seen=[],t0=performance.now();(function frame(){seen.push([hoverPointer?.x??null,$('hover-label').hidden?null:$('hover-label').dataset.point]);if(performance.now()-t0<ms)requestAnimationFrame(frame);else done(seen);})();}),
  bounds:()=>{const t=$('hover-text').getBoundingClientRect(),g=document.querySelector('.hover-ring').getBoundingClientRect(),c=renderer.domElement.getBoundingClientRect();return {text:[t.left,t.top,t.right,t.bottom],ring:[(g.left+g.right)/2,(g.top+g.bottom)/2],canvas:[c.left,c.top,c.right,c.bottom]};},
  // The drawn point nearest the canvas's right or top edge, at least 6 pixels inside it.
  extreme:(side)=>{const r=renderer.domElement.getBoundingClientRect(),v=new THREE.Vector3();let best=null,score=-Infinity;for(let i=0;i<lattice.count;i++){v.fromArray(lattice.xyz,3*i).applyMatrix4(cloudMesh.matrixWorld).project(camera);if(v.z>=1)continue;const x=r.x+(v.x+1)*r.width/2,y=r.y+(1-v.y)*r.height/2;if(x<r.left+6||x>r.right-6||y<r.top+6||y>r.bottom-6)continue;const s=side==='right'?x:-y;if(s>score){score=s;best=tripleAt(lattice,i);}}return best;},
  polynomial,describe,
};`});
  });
  await page.reload();await page.waitForFunction(()=>window.__hover);
  await page.setViewportSize({width:1280,height:900});
  const ensure=(condition,message)=>{if(!condition)throw Error(message);};
  const same=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
  const snapshot=()=>page.evaluate(()=>__hover.snapshot());
  const settle=()=>page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
  const report={cases:[]};
  await settle();await settle(); // the resize must reach the camera before screen positions are computed
  const before=await snapshot();
  ensure(before.inspector==='f(x) = x² − x + 2','Inspector does not name the selected polynomial');
  ensure(before.count===480&&!before.label,'Unexpected default state');

  // Each case: hover its center; the label must equal the click oracle there. Aimed exactly at a center, that
  // center's angle is zero, so unless another center projects within a pixel it must be named exactly (signed,
  // unreduced).
  const cases=[[[1,0,1],'x² + 1'],[[2,0,2],'2x² + 2'],[[1,1,1],'x² + x + 1'],[[-1,1,-2],'−x² + x − 2'],[[1,-2,1],'x² − 2x + 1'],[[1,0,-1],'x² − 1'],[[0,1,0],'x'],[[0,0,-3],'−3']];
  for(const [point,text] of cases){
    const s=await page.evaluate(p=>__hover.screen(p),point), isolation=await page.evaluate(p=>__hover.isolation(p),point);
    await page.mouse.move(s.x,s.y);await settle();
    const after=await snapshot(), oracle=await page.evaluate(([x,y])=>__hover.oracle(x,y),[s.x,s.y]);
    ensure(after.label&&after.label.point===oracle,`Hover ${after.label?.point} differs from the click oracle ${oracle} at ${point}`);
    ensure(after.label.text===await page.evaluate(p=>__hover.polynomial(p.split(',').map(Number)),after.label.point),'Label is not the hovered point\'s exact polynomial');
    if(isolation>1)ensure(after.label.point===point.join()&&after.label.text===text,`Isolated ${point} hovered as ${after.label.point} "${after.label.text}"`);
    ensure(same(after.selected,before.selected)&&same(after.camera,before.camera)&&same(after.quaternion,before.quaternion)&&after.generation===before.generation,'Hover changed selection, camera or lattice');
    report.cases.push({point:point.join(),isolationPx:Math.round(isolation*10)/10,hovered:after.label.point,text:after.label.text});
  }
  await page.screenshot({path:'output/hover-polynomial.png'});

  // A click at the hovered place selects exactly the hovered point; the inspector keeps its signed form.
  const multiple=await page.evaluate(()=>__hover.screen([2,0,2]));
  await page.mouse.move(multiple.x,multiple.y);await settle();
  const hoveredMultiple=(await snapshot()).label.point;
  await page.mouse.click(multiple.x,multiple.y);await settle();
  const clicked=await snapshot();
  ensure(clicked.selected.join()===hoveredMultiple,'Click selected a different point than the hover named');
  if(hoveredMultiple==='2,0,2')ensure(clicked.inspector==='f(x) = 2x² + 2','Inspector reduced a multiple');
  report.click={hovered:hoveredMultiple,inspector:clicked.inspector};

  // Leaving the canvas, a press-and-drag, a rebuild and Reset each hide the label.
  await page.mouse.move(5,5);await settle();
  ensure(!(await snapshot()).label,'Label survived leaving the canvas');
  const center=await page.evaluate(()=>__hover.screen([1,0,1]));
  await page.mouse.move(center.x,center.y);await settle();ensure((await snapshot()).label,'No hover before drag');
  await page.mouse.down();await page.mouse.move(center.x+60,center.y+20,{steps:6});
  ensure(!(await snapshot()).label,'Label shown during a drag');
  await page.mouse.up();await settle();
  const dragged=await snapshot();
  ensure(!same(dragged.camera,clicked.camera),'Drag did not orbit');
  if(dragged.label)ensure(dragged.label.point===await page.evaluate(([x,y])=>__hover.oracle(x,y),[center.x+60,center.y+20]),'Post-drag hover is stale');
  // A rebuild drops the old answer; with the pointer still over the canvas it is recomputed on the new lattice.
  await page.selectOption('#radius','8');await settle();
  const rebuilt=await snapshot();
  ensure(rebuilt.generation>dragged.generation&&rebuilt.count===1060,'Radius change did not rebuild');
  if(rebuilt.label)ensure(rebuilt.label.point===await page.evaluate(([x,y])=>__hover.oracle(x,y),[center.x+60,center.y+20]),'Label after rebuild is stale');
  report.rebuild={hovered:rebuilt.label?.point??null};
  await page.locator('#reset').click();await settle();
  ensure(!(await snapshot()).label&&(await snapshot()).inspector==='f(x) = x² − x + 2','Reset left a hover label or wrong inspector');

  // Dense R96 (about 1.85M points): pointer moves ask the worker only; the shown answer matches the click rule.
  await page.selectOption('#radius','96');
  await page.waitForFunction(()=>__hover.snapshot().count>1e6,null,{timeout:120000});
  await settle();
  const dense0=await snapshot();
  ensure(dense0.worker,'Dense crop is not using the hover worker');
  const box=await page.locator('#viewport canvas').boundingBox();
  const target={x:box.x+box.width*0.55,y:box.y+box.height*0.45};
  for(let i=0;i<20;i++)await page.mouse.move(target.x-20+i,target.y);
  await page.waitForFunction(()=>__hover.snapshot().label!==null,null,{timeout:20000});
  const dense=await snapshot();
  ensure(dense.picks===dense0.picks,`Dense hover ran ${dense.picks-dense0.picks} UI-thread scans`);
  const denseOracle=await page.evaluate(([x,y])=>__hover.oracle(x,y),[target.x-1,target.y]);
  ensure(dense.label.point===denseOracle,`Dense hover ${dense.label.point} differs from the click oracle ${denseOracle}`);
  await page.screenshot({path:'output/hover-polynomial-r96.png'});
  report.dense={count:dense.count,hovered:dense.label.point,text:dense.label.text,workerMs:dense.workerMs,uiScans:dense.picks-dense0.picks};
  // (A) Below the XR staleness tolerance the click rule can still change: hold on one side of a split, move half a
  // CSS pixel (then, separately, one whole pixel) across it, hold. Every frame after the move must show nothing or
  // the current click oracle's point, judged at the pointer position hover actually received.
  report.splits=[];
  // Our canvas sits beside the panel, so a whole pixel exceeds 1 mrad at 900 px tall; the 1-pixel case uses a
  // taller window, where one pixel is below the XR tolerance as in the full-window reproduction.
  for(const [dx,size] of [[0.5,{width:1280,height:900}],[1,{width:1280,height:1150}]]){
    await page.setViewportSize(size);await settle();await settle();
    const area=await page.locator('#viewport canvas').boundingBox();
    const split=await page.evaluate(([x,y,w,h,dx])=>__hover.split(x,y,w,h,7,dx),[...[area.x+area.width*0.35,area.y+area.height*0.3,area.width*0.3,area.height*0.3].map(Math.round),dx]);
    ensure(split,`No ${dx}-pixel split found at R96`);
    await page.mouse.move(split.x,split.y);
    await page.waitForFunction(a=>__hover.snapshot().label?.point===a,split.a,{timeout:20000});
    const held=await snapshot(), watching=page.evaluate(()=>__hover.watch(1500));
    await page.mouse.move(split.x+dx,split.y);
    const seen=await watching, afterMove=seen.filter(([x])=>x===split.x+dx);
    ensure(afterMove.length,'Pointer never reported the moved position');
    const wrong=afterMove.filter(([,p])=>p!==null&&p!==split.b);
    ensure(!wrong.length,`After a ${split.angle.toExponential(2)} rad move the label kept naming ${wrong[0]?.[1]} instead of ${split.b} in ${wrong.length} of ${afterMove.length} frames`);
    await page.waitForFunction(b=>__hover.snapshot().label?.point===b,split.b,{timeout:20000});
    const moved=await snapshot();
    ensure(same(moved.selected,held.selected)&&same(moved.camera,held.camera)&&moved.picks===held.picks,'Split hover changed state or scanned on the UI thread');
    report.splits.push({dx,canvasHeight:Math.round(area.height),...split,framesAfterMove:afterMove.length,hiddenFrames:afterMove.filter(([,p])=>p===null).length});
  }
  await page.setViewportSize({width:1280,height:900});await settle();
  const split=report.splits[0];
  // (B) A cancelled pointer drops its hover even if the worker answers afterwards.
  // The move starts a worker query; cancelling before it returns must keep the label hidden after it does.
  await page.mouse.move(split.x-40,split.y+30);
  ensure((await snapshot()).busy,'No worker query outstanding at cancel');
  await page.evaluate(()=>document.querySelector('#viewport canvas').dispatchEvent(new PointerEvent('pointercancel',{pointerId:1,bubbles:true})));
  const cancelled=await page.evaluate(()=>__hover.watch(1200));
  ensure(cancelled.every(([,p])=>p===null),'A label appeared after pointercancel');
  report.xrReadout=await page.evaluate(()=>[__hover.describe([2,-2,4]),__hover.describe([-1,1,-2]),__hover.describe([0,1,0])]);
  ensure(report.xrReadout[0]==='(2, -2, 4) · 2x² − 2x + 4 · Δ = -28','XR readout does not name the signed polynomial');
  // (C) Labels for the right-most and top-most drawn points stay inside the canvas; the ring stays on the center.
  report.edges=[];
  await page.locator('#reset').click();
  for(const size of [{width:1280,height:900},{width:844,height:390}]){
    await page.setViewportSize(size);await settle();
    // Zoom in until the cloud overflows the canvas, so the chosen points sit at its edges.
    const zoomBox=await page.locator('#viewport canvas').boundingBox();
    await page.mouse.move(zoomBox.x+zoomBox.width/2,zoomBox.y+zoomBox.height/2);
    for(let i=0;i<6;i++){await page.mouse.wheel(0,-300);await settle();}
    await page.waitForTimeout(600);await settle();
    for(const side of ['right','top']){
      const point=await page.evaluate(s=>__hover.extreme(s),side), s=await page.evaluate(p=>__hover.screen(p),point);
      await page.mouse.move(s.x,s.y);await settle();
      const shown=await snapshot();if(!shown.label){report.edges.push({size,side,point:point.join(),label:null});continue;}
      const b=await page.evaluate(()=>__hover.bounds()), target=await page.evaluate(p=>__hover.screen(p.split(',').map(Number)),shown.label.point);
      ensure(b.text[0]>=b.canvas[0]-0.5&&b.text[1]>=b.canvas[1]-0.5&&b.text[2]<=b.canvas[2]+0.5&&b.text[3]<=b.canvas[3]+0.5,`${side} label leaves the canvas at ${size.width}×${size.height}: ${b.text.map(Math.round)} vs ${b.canvas.map(Math.round)}`);
      ensure(Math.hypot(b.ring[0]-target.x,b.ring[1]-target.y)<1,'Ring moved off the hovered center');
      // The text flips left exactly when the default placement (9 px right) would leave the canvas; vertically it
      // only clamps, which the bounds check above covers.
      const w=b.text[2]-b.text[0], needed=side==='right'&&b.ring[0]+9+w>b.canvas[2]-4;
      const flipped=b.text[2]<=b.ring[0];
      ensure(flipped===needed,`${side} label flip ${flipped}, needed ${needed} at ${size.width}×${size.height}`);
      report.edges.push({size,side,point:shown.label.point,flipped,ring:b.ring.map(Math.round),text:b.text.map(Math.round),canvas:b.canvas.map(Math.round)});
    }
    await page.screenshot({path:`output/hover-edges-${size.width}x${size.height}.png`});
    await page.locator('#reset').click();await settle();
  }
  ensure(report.edges.some(e=>e.side==='right'&&e.flipped),'No edge case exercised the flip');
  await page.setViewportSize({width:1280,height:900});
  // (D) The worker fails while the pointer waits for its first answer: hover falls back without another move.
  await page.route('**/aim-worker.js*',route=>route.fulfill({contentType:'text/javascript',body:"self.onmessage=({data})=>{if(data.type==='query')throw Error('injected worker failure');};"}));
  await page.reload();await page.waitForFunction(()=>window.__hover);
  await page.selectOption('#radius','48');
  await page.waitForFunction(()=>__hover.snapshot().count>=50000,null,{timeout:60000});await settle();
  const failBox=await page.locator('#viewport canvas').boundingBox();
  await page.mouse.move(failBox.x+failBox.width*0.5,failBox.y+failBox.height*0.45);
  await page.waitForFunction(()=>__hover.snapshot().failed,null,{timeout:20000});
  await page.waitForFunction(()=>__hover.snapshot().label!==null,null,{timeout:10000});
  const fallback=await snapshot(), fallbackOracle=await page.evaluate(([x,y])=>__hover.oracle(x,y),[failBox.x+failBox.width*0.5,failBox.y+failBox.height*0.45]);
  ensure(fallback.label.point===fallbackOracle,'Fallback hover differs from the click oracle');
  report.workerFailure={count:fallback.count,hovered:fallback.label.point};
  await page.unroute('**/aim-worker.js*');
  ensure(!errors.length,errors.join('; '));
  return report;
}
