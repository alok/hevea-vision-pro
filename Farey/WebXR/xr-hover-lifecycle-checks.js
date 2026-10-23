// SPDX-License-Identifier: GPL-3.0-or-later
// Test-only instrumentation for an already-served loopback build. It MOCKS WebXR: navigator.xr is replaced by a
// stub whose requestSession stays pending until the test cancels it, and session end is a dispatched 'sessionend'
// event on renderer.xr. No immersive session or headset rendering exists here; run real XR separately.
// Checks that desktop hover is cleared on XR entry by keyboard activation while the mouse rests on a hovered point,
// stays hidden while entry is pending, recovers after cancellation, and is cleared again by session end.
async page => {
  if(!['127.0.0.1','localhost'].includes(new URL(page.url()).hostname))throw Error('Use loopback');
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.addInitScript(()=>{
    Object.defineProperty(navigator,'xr',{configurable:true,value:{
      isSessionSupported:async()=>true,
      requestSession:()=>new Promise((_resolve,reject)=>{window.__mockXR={requests:(window.__mockXR?.requests??0)+1,cancel:()=>reject(Error('mock cancel'))};}),
      addEventListener(){},removeEventListener(){},
    }});
  });
  await page.route('**/starscape.js*',async route=>{
    const response=await route.fetch();
    await route.fulfill({response,body:await response.text()+`
window.__life={
  label:()=>$('hover-label').hidden?null:$('hover-label').dataset.point,
  pointer:()=>hoverPointer&&[hoverPointer.x,hoverPointer.y],
  screen:p=>{const r=renderer.domElement.getBoundingClientRect(),v=world.localToWorld(physical(vector(p))).project(camera);return {x:r.x+(v.x+1)*r.width/2,y:r.y+(1-v.y)*r.height/2};},
  // MOCK session end: a stand-in session object, then the event Three.js would forward from the real session.
  mockSessionEnd:()=>{session={end:async()=>{}};renderer.xr.dispatchEvent({type:'sessionend'});},
  session:()=>!!session,
};`});
  });
  await page.reload();await page.waitForFunction(()=>window.__life);
  await page.setViewportSize({width:1280,height:900});
  const ensure=(condition,message)=>{if(!condition)throw Error(message);};
  const settle=()=>page.evaluate(()=>new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r))));
  await settle();await settle();
  await page.waitForFunction(()=>!document.getElementById('xr').disabled,null,{timeout:10000});
  const report={mock:true};
  const hover=async()=>{const s=await page.evaluate(()=>__life.screen([1,0,1]));await page.mouse.move(s.x,s.y);await settle();return s;};
  const at=await hover();
  ensure(await page.evaluate(()=>__life.label())==='1,0,1','No hover label before XR entry');
  // Keyboard activation: the mouse never leaves the canvas, so no pointerleave fires.
  await page.locator('#xr').focus();await page.keyboard.press('Enter');
  ensure(await page.evaluate(()=>window.__mockXR?.requests)===1,'Enter VR did not request a session');
  ensure(await page.evaluate(()=>__life.label())===null,'Label survived keyboard XR entry');
  ensure(await page.evaluate(()=>__life.pointer())===null,'Hover kept the pointer through XR entry');
  // While entry is pending, moving over the canvas must not re-show a label.
  await page.mouse.move(at.x+1,at.y);await page.mouse.move(at.x,at.y);await settle();await settle();
  ensure(await page.evaluate(()=>__life.label())===null,'Label shown while XR entry was pending');
  report.pending='hidden';
  await page.evaluate(()=>__mockXR.cancel());
  await page.waitForFunction(()=>!document.getElementById('xr').disabled,null,{timeout:10000});
  ensure((await page.locator('#status').textContent()).includes('cancelled'),'Cancellation not reported');
  await page.mouse.move(at.x+1,at.y);await page.mouse.move(at.x,at.y);await settle();
  ensure(await page.evaluate(()=>__life.label())==='1,0,1','Hover did not recover after cancelled entry');
  report.afterCancel='1,0,1';
  await page.evaluate(()=>__life.mockSessionEnd());
  ensure(!(await page.evaluate(()=>__life.session())),'Mock session end did not clear the session');
  ensure(await page.evaluate(()=>__life.label())===null&&await page.evaluate(()=>__life.pointer())===null,'Label or pointer survived session end');
  await settle();
  ensure(await page.evaluate(()=>__life.label())===null,'Label re-shown after session end without a pointer move');
  await page.mouse.move(at.x+1,at.y);await page.mouse.move(at.x,at.y);await settle();
  report.afterSessionEnd=await page.evaluate(()=>__life.label());
  ensure(report.afterSessionEnd==='1,0,1','Hover did not resume after session end');
  ensure(!errors.length,errors.join('; '));
  return report;
}
