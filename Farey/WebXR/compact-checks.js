// SPDX-License-Identifier: GPL-3.0-or-later
// Test-only instrumentation for an already-served loopback build: the compact 3D | Roots switch below 1000 px, with
// real touch input (CDP touch events, which the page receives as touch pointer events) at 390×844 and 844×390.
async page => {
  if(!['127.0.0.1','localhost'].includes(new URL(page.url()).hostname))throw Error('Use loopback');
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.route('**/starscape.js*',async route=>{
    const response=await route.fetch();
    await route.fulfill({response,body:await response.text()+`
window.__compact={
  state:()=>({g:[...group],selected:[...selected],camera:camera.position.toArray(),quaternion:camera.quaternion.toArray(),compact:compactRoots,inhabited,
    pane:getComputedStyle($('roots-pane')).display,paneRect:$('roots-pane').getBoundingClientRect().toJSON(),viewRect:$('viewport').getBoundingClientRect().toJSON(),
    controlsRect:document.querySelector('.controls').getBoundingClientRect().toJSON(),switchRect:$('view-switch').getBoundingClientRect().toJSON(),
    overflow:document.documentElement.scrollWidth-innerWidth,viewHidden:getComputedStyle($('viewport')).visibility==='hidden'}),
  rootScreen:p=>{const r=upperRoot(positiveRepresentative(p)),z=act(group,{x:r[0],y:r[1]}),[x,y]=rootsPane.toScreen(z),b=rootsPane.canvas.getBoundingClientRect();return {x:b.left+x,y:b.top+y};},
  screen:p=>{const r=renderer.domElement.getBoundingClientRect(),v=world.localToWorld(physical(viewVector(p))).project(camera);return {x:r.x+(v.x+1)*r.width/2,y:r.y+(1-v.y)*r.height/2};},
};`});
  });
  await page.reload();await page.waitForFunction(()=>window.__compact);
  const settle=()=>page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
  const cdp=await page.context().newCDPSession(page);
  // Each gesture gets its own touch identifier, as separate finger contacts do.
  let touchId=0;
  const touch=async(type,points)=>cdp.send('Input.dispatchTouchEvent',{type,touchPoints:points.map(p=>({x:p.x,y:p.y,id:touchId}))});
  const touchDrag=async(from,to,steps=8,{cancel=false}={})=>{
    touchId++;
    await touch('touchStart',[from]);
    // One frame between moves, as a real finger delivers them; back-to-back moves can coalesce.
    for(let i=1;i<=steps;i++){await touch('touchMove',[{x:from.x+(to.x-from.x)*i/steps,y:from.y+(to.y-from.y)*i/steps}]);await settle();}
    await touch(cancel?'touchCancel':'touchEnd',[]);
    // A lift straight after movement starts the browser's fling handling, which consumes the next touch start;
    // a person pauses between gestures, and so does this check.
    await page.waitForTimeout(400);
  };
  const ensure=(condition,message)=>{if(!condition)throw Error(message);};
  const same=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
  const state=()=>page.evaluate(()=>__compact.state());
  const inside=(inner,outer,tol=1)=>inner.left>=outer.left-tol&&inner.top>=outer.top-tol&&inner.right<=outer.right+tol&&inner.bottom<=outer.bottom+tol;
  const overlap=(a,b)=>Math.max(0,Math.min(a.right,b.right)-Math.max(a.left,b.left))*Math.max(0,Math.min(a.bottom,b.bottom)-Math.max(a.top,b.top));
  const report={};
  for(const size of [{width:390,height:844},{width:844,height:390}]){
    const tag=`${size.width}x${size.height}`;
    await page.setViewportSize(size);await settle();await settle();
    let s=await state();
    ensure(s.overflow<=0,`${tag}: horizontal page overflow ${s.overflow}px`);
    ensure(s.pane==='none'&&!s.compact&&inside(s.switchRect,s.viewRect),`${tag}: the 3D view should show first, with the switch over it`);
    const camera0=s.camera, quaternion0=s.quaternion;
    // Roots: the pane takes the 3D view's place; the 3D view is hidden, not resized; the controls do not cover it.
    await page.locator('#show-roots').click();await settle();
    s=await state();
    ensure(s.pane==='block'&&s.viewHidden&&same(s.paneRect,s.viewRect),`${tag}: the roots pane does not replace the 3D view`);
    ensure(overlap(s.paneRect,s.controlsRect)<1,`${tag}: the controls cover the roots pane`);
    ensure(s.overflow<=0,`${tag}: overflow with the roots pane`);
    // A cancelled touch keeps the motion made so far and neither snaps nor selects.
    const c0=await page.evaluate(()=>__compact.rootScreen(__compact.state().selected));
    await page.evaluate(()=>{window.__log=[];const c=document.getElementById('roots-pane');for(const t of ['pointerdown','pointermove','pointerup','pointercancel'])c.addEventListener(t,e=>__log.push(`${t}:${Math.round(e.clientX)},${Math.round(e.clientY)}`));});
    await touchDrag(c0,{x:c0.x-20,y:c0.y+15},4,{cancel:true});await settle();
    s=await state();
    ensure(!same(s.g,[1,0,0,1])&&Math.abs(s.g[0]*s.g[3]-s.g[1]*s.g[2]-1)<1e-12,`${tag}: cancelled touch did not keep its motion: g ${s.g} vs identity; start ${JSON.stringify(c0)} log ${await page.evaluate(()=>__log.join(' '))} hit ${await page.evaluate(([x,y])=>{const e=document.elementFromPoint(x,y);return (e?.id||e?.tagName)+' scroll '+scrollX+','+scrollY+' vv '+visualViewport.offsetLeft+','+visualViewport.offsetTop+','+visualViewport.scale;},[c0.x,c0.y])}`);
    // Touch drag of the selected root: it ends under the finger; identities and the 3D camera are unchanged.
    await page.locator('#g-identity').click();await settle();
    const from=await page.evaluate(()=>__compact.rootScreen(__compact.state().selected)), to={x:from.x+50,y:from.y-30};
    ensure(inside({left:from.x,top:from.y,right:from.x,bottom:from.y},s.paneRect),`${tag}: the selected root is off the pane`);
    await touchDrag(from,to);await settle();
    s=await state();
    const after=await page.evaluate(()=>__compact.rootScreen(__compact.state().selected));
    ensure(!same(s.g,[1,0,0,1])&&Math.hypot(after.x-to.x,after.y-to.y)<1,`${tag}: touch drag did not carry the root (${after.x},${after.y} vs ${to.x},${to.y})`);
    ensure(same(s.camera,camera0)&&same(s.quaternion,quaternion0),`${tag}: a roots drag moved the 3D camera`);
    const g1=s.g;
    // A touch tap selects the tapped root's form.
    const tap=await page.evaluate(()=>__compact.rootScreen([1,0,1]));
    if(inside({left:tap.x,top:tap.y,right:tap.x,bottom:tap.y},s.paneRect,-8)){
      await page.evaluate(()=>{window.__tapLog=[];const c=document.getElementById('roots-pane');for(const t of ['pointerdown','pointermove','pointerup','pointercancel','click'])c.addEventListener(t,e=>__tapLog.push(`${t}:${e.pointerType}:${Math.round(e.clientX)},${Math.round(e.clientY)}`));});
      touchId++;await touch('touchStart',[tap]);await touch('touchEnd',[]);await settle();
      ensure(same((await state()).selected,[1,0,1]),`${tag}: touch tap did not select (1,0,1): selected ${(await state()).selected} at ${JSON.stringify(tap)} log ${await page.evaluate(()=>__tapLog.join(' '))}`);
    }
    const gRoots=(await state()).g, selectedRoots=(await state()).selected;
    // Back to 3D: same g, selection and camera.
    await page.locator('#show-3d').click();await settle();
    s=await state();
    ensure(s.pane==='none'&&!s.viewHidden&&same(s.g,gRoots)&&same(s.selected,selectedRoots)&&same(s.camera,camera0),`${tag}: switching back lost state`);
    await page.screenshot({path:`output/compact-${tag}-3d.png`});
    // Origin in the compact 3D view: a touch drag moves the sky by g; Return restores the overview camera.
    await page.locator('#origin').click();await settle();await settle();
    const sky=await page.evaluate(()=>__compact.screen([1,0,1])), gSky=(await state()).g;
    if(inside({left:sky.x,top:sky.y,right:sky.x,bottom:sky.y},(await state()).viewRect,-20)){
      await touchDrag(sky,{x:sky.x+30,y:sky.y+12});await settle();
      ensure(!same((await state()).g,gSky),`${tag}: the origin touch drag did not move the sky`);
    }
    await page.locator('#inhabit').click();await settle();
    s=await state();
    ensure(!s.inhabited&&s.camera.every((x,i)=>Math.abs(x-camera0[i])<1e-9),`${tag}: Return did not restore the overview camera: ${s.camera} vs ${camera0}, inhabited ${s.inhabited}`);
    await page.locator('#show-roots').click();await settle();
    await page.screenshot({path:`output/compact-${tag}-roots.png`});
    await page.locator('#reset').click();await settle();
    s=await state();
    ensure(same(s.g,[1,0,0,1])&&same(s.selected,[1,-1,2]),`${tag}: Reset did not restore g and the selection`);
    await page.locator('#show-3d').click();await settle();
    report[tag]={g:gRoots,selected:selectedRoots,switchRect:s.switchRect};
  }
  ensure(!errors.length,errors.join('; '));
  return report;
}
