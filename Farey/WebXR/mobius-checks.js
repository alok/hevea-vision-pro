// SPDX-License-Identifier: GPL-3.0-or-later
// Test-only instrumentation for an already-served loopback build: the roots-pane Möbius drag and its 3D lift through
// actual pointer input. Checks the drag invariant (the point under the pointer follows it), exact base identities,
// 3D positions J·ρ(g)·(a,b,c), hover and picking under g, Shift-pan, click selection, Identity, Snap absorption,
// generator buttons, the eye-at-origin drag, dense worker hover after a drag, and Reset.
async page => {
  if(!['127.0.0.1','localhost'].includes(new URL(page.url()).hostname))throw Error('Use loopback');
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.route('**/starscape.js*',async route=>{
    const response=await route.fetch();
    await route.fulfill({response,body:await response.text()+`
window.__mobius={
  state:()=>({g:[...group],selected:[...selected],second:secondSelection&&[...secondSelection],generation:latticeGeneration,camera:camera.position.toArray(),
    count:lattice.count,label:$('hover-label').hidden?null:$('hover-label').dataset.point,groupText:$('group-state').textContent,view:{...rootsPane.ensureView()}}),
  // Where the pane draws a base form's root under g, in page pixels.
  rootScreen:p=>{const r=upperRoot(positiveRepresentative(p)),z=act(group,{x:r[0],y:r[1]}),[x,y]=rootsPane.toScreen(z),b=rootsPane.canvas.getBoundingClientRect();return {x:b.left+x,y:b.top+y};},
  // A base form's drawn 3D position, and its expected value J·ρ(g)·(a,b,c).
  drawn:p=>{for(let i=0;i<lattice.count;i++)if(lattice.abc[3*i]===p[0]&&lattice.abc[3*i+1]===p[1]&&lattice.abc[3*i+2]===p[2])return [...lattice.xyz.subarray(3*i,3*i+3)];return null;},
  expected:p=>viewVector(p),
  screen:p=>{const r=renderer.domElement.getBoundingClientRect(),v=world.localToWorld(physical(viewVector(p))).project(camera);return {x:r.x+(v.x+1)*r.width/2,y:r.y+(1-v.y)*r.height/2};},
  oracle:(x,y)=>{const {ray,angle}=pointerRay(x,y),i=pickIndex(ray,angle);return i<0?null:tripleAt(lattice,i).join();},
  maxBaseError:()=>{let e=0;for(let i=0;i<3*lattice.count;i++)e=Math.max(e,Math.abs(lattice.xyz[i]-baseXyz[i]));return e;},
  timings:()=>({...timings}),
};`});
  });
  await page.reload();await page.waitForFunction(()=>window.__mobius);
  await page.setViewportSize({width:1440,height:1000});
  const settle=()=>page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
  await settle();await settle();
  const ensure=(condition,message)=>{if(!condition)throw Error(message);};
  const same=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
  const state=()=>page.evaluate(()=>__mobius.state());
  const near=(a,b,tol)=>Math.hypot(a.x-b.x,a.y-b.y)<=tol;
  const drag=async(from,to,{shift=false,steps=12}={})=>{
    await page.mouse.move(from.x,from.y);if(shift)await page.keyboard.down('Shift');
    await page.mouse.down();await page.mouse.move(to.x,to.y,{steps});await page.mouse.up();
    if(shift)await page.keyboard.up('Shift');await settle();
  };
  const report={};
  const s0=await state();
  ensure(same(s0.g,[1,0,0,1])&&s0.groupText==='g = identity','Not at the identity initially');

  // (1) Drag the selected root by (+110, −45) px: it ends under the pointer; identities and camera are unchanged.
  const start=await page.evaluate(()=>__mobius.rootScreen([1,-1,2])), end={x:start.x+110,y:start.y-45};
  await drag(start,end);
  const s1=await state(), after=await page.evaluate(()=>__mobius.rootScreen([1,-1,2]));
  ensure(!same(s1.g,s0.g),'The drag did not change g');
  ensure(near(after,end,1),`The dragged root is at ${after.x},${after.y}, not under the pointer ${end.x},${end.y}`);
  ensure(same(s1.selected,[1,-1,2])&&same(s1.camera,s0.camera),'The drag changed the selection or the camera');
  ensure(Math.abs(s1.g[0]*s1.g[3]-s1.g[1]*s1.g[2]-1)<1e-12,'g left SL₂(ℝ)');
  ensure(s1.groupText.includes('off SL₂(ℤ)'),'Readout does not mark a non-integer g');
  // The 3D lift: every checked point is drawn at J·ρ(g)·(a,b,c) (Float32), and Δ is preserved.
  for(const p of [[1,-1,2],[1,0,1],[2,1,1],[-1,1,-2],[1,3,1],[0,1,0]]){
    const [d,e]=await page.evaluate(q=>[__mobius.drawn(q),__mobius.expected(q)],p);
    ensure(d&&d.every((x,i)=>Math.abs(x-e[i])<=1e-5*Math.max(1,Math.abs(e[i]))),`3D position of ${p} is not the transformed one`);
    const delta=d[0]*d[0]+d[2]*d[2]-d[1]*d[1], base=p[1]*p[1]-4*p[0]*p[2];
    ensure(Math.abs(delta-base)<1e-3*Math.max(1,Math.abs(base)),`Δ of ${p} changed under g`);
  }
  report.drag={g:s1.g,rootEnd:after,pointerEnd:end};
  await page.screenshot({path:'output/mobius-after-drag.png'});

  // (2) 3D hover after the drag names the click-rule point on the transformed geometry.
  const target=await page.evaluate(()=>__mobius.screen([1,0,1]));
  await page.mouse.move(target.x,target.y);await settle();
  const hovered=(await state()).label, oracle=await page.evaluate(([x,y])=>__mobius.oracle(x,y),[target.x,target.y]);
  ensure(hovered&&hovered===oracle,`3D hover ${hovered} differs from the click oracle ${oracle} under g`);
  report.hoverUnderG={hovered};

  // (3) Shift-drag pans the roots pane only.
  const pan0=await page.evaluate(()=>__mobius.rootScreen([1,-1,2]));
  await drag(pan0,{x:pan0.x+40,y:pan0.y+25},{shift:true});
  const s3=await state();
  ensure(same(s3.g,s1.g)&&!same(s3.view,s1.view),'Shift-drag changed g or did not pan');

  // (4) A click (no movement) on a root in the pane selects that base form.
  const click=await page.evaluate(()=>__mobius.rootScreen([1,0,1]));
  await page.mouse.click(click.x,click.y);await settle();
  ensure(same((await state()).selected,[1,0,1]),'Clicking a root did not select its form');

  // (5) Identity restores g = 1 and the exact base positions; the selection stays.
  await page.locator('#g-identity').click();await settle();
  const s5=await state();
  ensure(same(s5.g,[1,0,0,1])&&same(s5.selected,[1,0,1]),'Identity did not return to g = 1');
  ensure(await page.evaluate(()=>__mobius.maxBaseError())===0,'Identity did not restore the exact positions');

  // (6) Snap: drag the root of x² + 1 from i to about i + 1; release absorbs γ = T into the selection, g returns to 1.
  await page.locator('#snap').check();await settle();
  const i0=await page.evaluate(()=>__mobius.rootScreen([1,0,1])), unit=(await state()).view.scale;
  await drag(i0,{x:i0.x+unit*0.97,y:i0.y});
  const s6=await state();
  ensure(same(s6.g,[1,0,0,1]),`Snap left g = ${s6.g}`);
  ensure(same(s6.selected,[1,-2,2]),`Snap absorbed into ${s6.selected}, not T·(1,0,1) = (1,-2,2)`);
  await page.locator('#g-identity').click();await settle();
  ensure(same((await state()).selected,[1,-2,2]),'Identity undid the absorption');
  report.snap={selected:s6.selected};
  await page.locator('#snap').uncheck();

  // (7) The T button composes T and absorbs it: (1,-2,2) becomes (1,-4,5).
  await page.locator('#g-t').click();await settle();
  ensure(same((await state()).selected,[1,-4,5])&&same((await state()).g,[1,0,0,1]),'T did not relabel the selection by T');
  await page.locator('#coefficient').fill('1,0,1');await page.locator('#coefficient-form button').click();await settle();

  // (8) Eye at the origin: a 3D drag moves the sky by g, carrying the dragged point with the pointer.
  await page.locator('#origin').click();await settle();await settle();
  const sky0=await page.evaluate(()=>__mobius.screen([1,0,1])), cam0=(await state()).camera;
  const skyEnd={x:sky0.x+65,y:sky0.y+25};
  await drag(sky0,skyEnd);
  const s8=await state(), sky1=await page.evaluate(()=>__mobius.screen([1,0,1]));
  ensure(!same(s8.g,[1,0,0,1]),'The origin drag did not change g');
  ensure(near(sky1,skyEnd,1.5),`At the origin the dragged point is at ${sky1.x},${sky1.y}, not ${skyEnd.x},${skyEnd.y}`);
  ensure(same(s8.camera,cam0)&&same(s8.selected,[1,0,1]),'The origin drag moved the camera or changed the selection');
  report.originDrag={g:s8.g};
  await page.screenshot({path:'output/mobius-origin-drag.png'});
  await page.locator('#inhabit').click();await page.locator('#g-identity').click();await settle();

  // (9) Dense R48: after a pane drag, worker hover still names the click-rule point.
  await page.selectOption('#radius','48');
  await page.waitForFunction(()=>__mobius.state().count>100000,null,{timeout:60000});await settle();
  const d0=await page.evaluate(()=>__mobius.rootScreen([1,-1,2]));
  await drag(d0,{x:d0.x+60,y:d0.y+20},{steps:6});
  const box=await page.locator('#viewport canvas').boundingBox(), probe={x:Math.round(box.x+box.width*0.5),y:Math.round(box.y+box.height*0.42)};
  await page.mouse.move(probe.x,probe.y);
  await page.waitForFunction(()=>__mobius.state().label!==null,null,{timeout:20000});
  const denseLabel=(await state()).label, denseOracle=await page.evaluate(([x,y])=>__mobius.oracle(x,y),[probe.x,probe.y]);
  ensure(denseLabel===denseOracle,`Dense hover ${denseLabel} differs from the click oracle ${denseOracle} under g`);
  report.dense={count:(await state()).count,label:denseLabel,groupMs:(await page.evaluate(()=>__mobius.timings())).group};
  await page.screenshot({path:'output/mobius-dense-r48.png'});

  // (10) Reset returns to the default selection, radius and g = 1.
  await page.locator('#reset').click();await settle();
  const s10=await state();
  ensure(same(s10.g,[1,0,0,1])&&same(s10.selected,[1,-1,2])&&s10.count===480,'Reset did not restore the defaults');
  ensure(!errors.length,errors.join('; '));
  return report;
}
