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
  snapshot:()=>({selected:[...selected],camera:camera.position.toArray(),quaternion:camera.quaternion.toArray(),count:lattice.count,generation:latticeGeneration,label:$('hover-label').hidden?null:{point:$('hover-label').dataset.point,text:$('hover-text').textContent},inspector:$('polynomial-state').textContent,picks:__picks,workerMs:hoverQueries.lastQueryMs,worker:lattice.count>=hoverWorkerPoints&&hoverQueries.available}),
  screen:p=>{const r=renderer.domElement.getBoundingClientRect(),v=world.localToWorld(physical(vector(p))).project(camera);return {x:r.x+(v.x+1)*r.width/2,y:r.y+(1-v.y)*r.height/2};},
  // The click rule on the current camera, scanned directly (test oracle; not counted as a UI pick).
  oracle:(x,y)=>{const {ray,angle}=pointerRay(x,y),i=__pick(ray,angle);return i<0?null:tripleAt(lattice,i).join();},
  // Pixel distance from p's center to the nearest other drawn center: projected neighbors can make a hover
  // legitimately name a different point than the one aimed at.
  isolation:p=>{const r=renderer.domElement.getBoundingClientRect(),s=window.__hover.screen(p),v=new THREE.Vector3();let best=Infinity;
    for(let i=0;i<lattice.count;i++){const q=tripleAt(lattice,i);if(q.join()===p.join())continue;v.fromArray(lattice.xyz,3*i).applyMatrix4(cloudMesh.matrixWorld).project(camera);best=Math.min(best,Math.hypot(r.x+(v.x+1)*r.width/2-s.x,r.y+(1-v.y)*r.height/2-s.y));}return best;},
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
  const before=await snapshot();
  ensure(before.inspector==='f(x) = x²−x+2','Inspector does not name the selected polynomial');
  ensure(before.count===480&&!before.label,'Unexpected default state');

  // Each case: hover its center; the label must equal the click oracle there. Aimed exactly at a center, that
  // center's angle is zero, so unless another center projects within a pixel it must be named exactly (signed,
  // unreduced).
  const cases=[[[1,0,1],'x²+1'],[[2,0,2],'2x²+2'],[[1,1,1],'x²+x+1'],[[-1,1,-2],'−x²+x−2'],[[1,-2,1],'x²−2x+1'],[[1,0,-1],'x²−1'],[[0,1,0],'x'],[[0,0,-3],'−3']];
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
  if(hoveredMultiple==='2,0,2')ensure(clicked.inspector==='f(x) = 2x²+2','Inspector reduced a multiple');
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
  ensure(!(await snapshot()).label&&(await snapshot()).inspector==='f(x) = x²−x+2','Reset left a hover label or wrong inspector');

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
  report.xrReadout=await page.evaluate(()=>[__hover.describe([2,-2,4]),__hover.describe([-1,1,-2]),__hover.describe([0,1,0])]);
  ensure(report.xrReadout[0]==='(2, -2, 4) · 2x²−2x+4 · Δ = -28','XR readout does not name the signed polynomial');
  ensure(!errors.length,errors.join('; '));
  return report;
}
