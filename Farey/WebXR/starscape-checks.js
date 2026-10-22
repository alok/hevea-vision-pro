// SPDX-License-Identifier: GPL-3.0-or-later
// Test-only response instrumentation, used by Playwright CLI against a local preview.
async page => {
  if (!['localhost','127.0.0.1','[::1]'].includes(new URL(page.url()).hostname)) throw Error('Use a loopback preview.');
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  const url=page.url();
  await page.route('**/starscape.js*',async route=>{
    const response=await route.fetch();
    await route.fulfill({response,body:await response.text()+`\nconst lossExtension=renderer.getContext().getExtension('WEBGL_lose_context');window.__spatialTest={snapshot:()=>({selected:[...selected],image:project(selected),source:vector(selected),world:world.matrixWorld.elements.slice(),positions:dots.filter(d=>[[1,0,1],[1,1,1],[1,0,2],[2,0,2]].some(p=>p.every((x,i)=>x===d.userData.point[i]))).map(d=>({coefficient:d.userData.point,world:d.getWorldPosition(new THREE.Vector3()).toArray()})),camera:camera.position.toArray(),pointCount:points.length,projection:disk.visible,triangles:renderer.info.render.triangles,drawCalls:renderer.info.render.calls}),pickable:()=>{const r=renderer.domElement.getBoundingClientRect();for(const d of dots){if(d.userData.point.every((x,i)=>x===selected[i]))continue;const p=d.getWorldPosition(new THREE.Vector3()).project(camera);if(Math.abs(p.x)>.8||Math.abs(p.y)>.8)continue;const caster=new THREE.Raycaster();caster.setFromCamera(new THREE.Vector2(p.x,p.y),camera);if(caster.intersectObjects(dots)[0]?.object===d)return {point:d.userData.point,x:r.left+(p.x+1)*r.width/2,y:r.top+(1-p.y)*r.height/2};}return null;},lose:()=>lossExtension};`});
  });
  await page.reload(); await page.waitForFunction(()=>window.__spatialTest);
  const snapshots=[];
  snapshots.push(await page.evaluate(()=>__spatialTest.snapshot()));
  await page.screenshot({path:'output/playwright/coefficient-cone/oblique.png'});
  await page.locator('#view').click();
  snapshots.push(await page.evaluate(()=>__spatialTest.snapshot()));
  if(JSON.stringify(snapshots[0].camera)===JSON.stringify(snapshots[1].camera))throw Error('View did not change');
  await page.screenshot({path:'output/playwright/coefficient-cone/other-side.png'});
  await page.locator('#next').click();
  const multiple=await page.evaluate(()=>__spatialTest.snapshot());
  if(JSON.stringify(multiple.image)!==JSON.stringify(snapshots[0].image))throw Error('Multiples projected differently');
  if(JSON.stringify(multiple.source)===JSON.stringify(snapshots[0].source))throw Error('Multiples lost depth');
  await page.locator('#projection').uncheck();
  if((await page.evaluate(()=>__spatialTest.snapshot())).projection)throw Error('Projection stayed visible');
  await page.screenshot({path:'output/playwright/coefficient-cone/cloud.png'});
  await page.locator('#coefficient').fill('1,2,1');await page.locator('#coefficient-form button').click();
  if(!(await page.locator('#status').innerText()).includes('unchanged'))throw Error('Invalid input lacks feedback');
  if(JSON.stringify((await page.evaluate(()=>__spatialTest.snapshot())).selected)!==JSON.stringify(multiple.selected))throw Error('Invalid input changed selection');
  await page.locator('#coefficient').fill('2,1,1');await page.locator('#coefficient-form button').click();
  if(!(await page.locator('#point-state').innerText()).includes('(2, 1, 1)'))throw Error('Valid input failed');
  const pick=await page.evaluate(()=>__spatialTest.pickable());
  if(!pick)throw Error('No exposed source point found for pointer check');
  await page.mouse.click(pick.x,pick.y);
  if(JSON.stringify((await page.evaluate(()=>__spatialTest.snapshot())).selected)!==JSON.stringify(pick.point))throw Error('Actual sphere click did not select its coefficient point');
  await page.locator('#reset').click();
  await page.context().setOffline(true);
  await page.locator('#next').click();
  if(!(await page.locator('#point-state').innerText()).includes('(2, -2, 4)'))throw Error('Offline interaction failed');
  await page.context().setOffline(false);
  await page.evaluate(()=>__spatialTest.lose().loseContext());
  await page.waitForFunction(()=>!document.querySelector('#fatal').hidden);
  await page.evaluate(()=>__spatialTest.lose().restoreContext());
  await page.waitForFunction(()=>document.querySelector('#fatal').hidden);
  if(!(await page.locator('#point-state').innerText()).includes('(2, -2, 4)'))throw Error('Restore changed selection');
  await page.locator('#reset').click();
  await page.setViewportSize({width:390,height:844});await page.waitForTimeout(100);
  await page.screenshot({path:'output/playwright/coefficient-cone/phone.png'});
  const phone=await page.locator('#viewport').boundingBox();if(phone.height<200||phone.width<300)throw Error('Phone scene is clipped');
  await page.setViewportSize({width:844,height:390});await page.waitForTimeout(100);
  await page.screenshot({path:'output/playwright/coefficient-cone/landscape.png'});
  await page.setViewportSize({width:1280,height:900});await page.reload();await page.waitForFunction(()=>window.__spatialTest);
  const fresh=await page.evaluate(()=>__spatialTest.snapshot());
  if(JSON.stringify(fresh.selected)!=='[1,-1,2]')throw Error('Fresh load mismatch');
  const fallback = await page.context().browser().newContext();
  let fallbackResult;
  try {
    await fallback.addInitScript(() => {
      const getContext=HTMLCanvasElement.prototype.getContext;
      HTMLCanvasElement.prototype.getContext=function(type,...args){return /webgl/i.test(type)?null:getContext.call(this,type,...args);};
    });
    const blank=await fallback.newPage(); await blank.goto(url);
    await blank.waitForFunction(()=>!document.querySelector('#fatal').hidden);
    fallbackResult=await blank.evaluate(()=>({message:document.querySelector('#fatal').textContent,disabled:[...document.querySelectorAll('.controls button,.controls input')].every(control=>control.disabled)}));
    if(!fallbackResult.disabled)throw Error('Unsupported graphics controls remained active');
  } finally { await fallback.close(); }
  if(errors.length)throw Error(errors.join('\n'));
  return{passed:true,url,snapshots,multiple,fresh,phone,pick,fallbackResult,errors,actualXRSession:false};
}
