// SPDX-License-Identifier: GPL-3.0-or-later
// Test-only instrumentation for an already-served loopback build.
async page => {
  if(!['127.0.0.1','localhost'].includes(new URL(page.url()).hostname))throw Error('Use loopback');
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.route('**/starscape.js*',async route=>{
    const response=await route.fetch();
    await route.fulfill({response,body:await response.text()+`\nwindow.__pair={snapshot:()=>({selected:[...selected],second:secondSelection&&[...secondSelection],plane:secondSelection&&pairPlane(selected,secondSelection),camera:camera.position.toArray(),quaternion:camera.quaternion.toArray(),inhabited,members:pairGlyphs[0]?.mesh.count??0,vertices:Array.from(focus.getObjectByName('pair-plane')?.geometry.attributes.position.array??[]),geometries:renderer.info.memory.geometries,calls:renderer.info.render.calls}),screen:p=>{const r=renderer.domElement.getBoundingClientRect(),v=world.localToWorld(physical(vector(p))).project(camera);return {x:r.x+(v.x+1)*r.width/2,y:r.y+(1-v.y)*r.height/2};}};`});
  });
  await page.reload();await page.waitForFunction(()=>window.__pair);
  await page.setViewportSize({width:1280,height:900});
  const ensure=(condition,message)=>{if(!condition)throw Error(message);};
  const same=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
  const snapshot=()=>page.evaluate(()=>__pair.snapshot());
  const enter=async (point,pair=false)=>{
    await page.locator('#coefficient').fill(point.join(','));
    await page.locator(pair?'#pair-add':'#coefficient-form button').click();
  };
  await enter([1,0,1]);const original=await snapshot();
  const position=await page.evaluate(()=>__pair.screen([1,1,1]));
  await page.keyboard.down('Shift');await page.mouse.click(position.x,position.y);await page.keyboard.up('Shift');
  const paired=await snapshot();
  ensure(same(paired.selected,[1,0,1])&&same(paired.second,[1,1,1]),'Shift-click did not preserve primary and select secondary');
  ensure(same(paired.camera,original.camera)&&same(paired.quaternion,original.quaternion),'Pair selection moved the camera');
  ensure(same(paired.plane.normal,[1,0,-1])&&paired.members>2,'Audited plane or necklace missing');
  ensure((await page.locator('#pair-endpoints').innerText()).includes('-1 and 1'),'Wrong endpoint labels');
  for(let i=2;i<paired.vertices.length;i+=3)ensure(Math.abs(paired.vertices[i])<1e-7,'Rendered vertices leave the a=c plane');
  await page.screenshot({path:'output/playwright/pair/overview-plane.png'});
  await enter([2,0,2],true);
  ensure(same((await snapshot()).second,paired.second),'Same direction replaced valid pair');
  ensure((await page.locator('#pair-status').innerText()).includes('same primitive'),'Missing duplicate-direction explanation');
  ensure(await page.locator('#coefficient').inputValue()==='2,0,2','Invalid pair entry was discarded');
  await enter([1,2,1],true);ensure(same((await snapshot()).second,paired.second),'Boundary point replaced valid pair');
  await enter([2,2,2],true);ensure(same((await snapshot()).plane.normal,paired.plane.normal),'Nonprimitive direction changed plane');
  await page.locator('#projection').check();ensure((await snapshot()).calls<24,'Pair geometry exceeds draw-call budget');
  await page.locator('#radius').selectOption('12');ensure(same((await snapshot()).second,[2,2,2]),'Radius change lost pair');
  await page.locator('#radius').selectOption('6');
  await page.locator('#pair-clear').click();ensure(!(await snapshot()).second&&same((await snapshot()).selected,[1,0,1]),'Clear pair changed primary');
  ensure(await page.locator('#pair-add').evaluate(e=>e===document.activeElement),'Clear pair lost keyboard focus');
  const baseline=await snapshot();
  for(let i=0;i<16;i++){await enter([1,1,1],true);await page.locator('#pair-clear').click();}
  ensure((await snapshot()).geometries<=baseline.geometries+1,'Pair geometry grows across repeated clear');
  await page.locator('#inhabit').click();const inside=await snapshot();
  await enter([1,1,1],true);ensure(same((await snapshot()).camera,inside.camera),'Pairing moved inhabited eye');
  await page.screenshot({path:'output/playwright/pair/inside-plane.png'});
  await page.locator('#inhabit').click();
  await page.locator('#pair-clear').click();await enter([1,0,4],true);
  ensure((await page.locator('#pair-endpoints').innerText()).includes('0 and ∞'),'Infinity endpoint missing');
  await enter([-1,-1,-1],true);await page.locator('#whole').uncheck();
  ensure((await page.locator('#pair-count').innerText()).includes('hidden by this filter'),'Hidden secondary not disclosed');
  await page.locator('#next').click();ensure(!(await snapshot()).second,'Next point retained stale pair');
  await page.locator('#reset').click();await enter([1,0,1]);
  await page.setViewportSize({width:390,height:844});await enter([1,1,1],true);
  ensure(!(await page.locator('#pair-details').isHidden()),'Mobile button pairing failed');
  await page.screenshot({path:'output/playwright/pair/phone-plane.png'});
  await page.locator('#reset').click();ensure(!(await snapshot()).second,'Reset retained pair');
  ensure(!errors.length,errors.join('\n'));
  await page.setViewportSize({width:1280,height:900});
  return {passed:true,paired:{...paired,vertices:paired.vertices.length/3},repeatGeometryCount:(await snapshot()).geometries,errors,actualXRSession:false};
}
