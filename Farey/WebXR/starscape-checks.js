// SPDX-License-Identifier: GPL-3.0-or-later
// Test-only instrumentation against an already-served loopback build.
async page => {
 if(!['127.0.0.1','localhost','[::1]'].includes(new URL(page.url()).hostname))throw Error('Use loopback');
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.route('**/starscape.js*',async route=>{const r=await route.fetch();await route.fulfill({response:r,body:await r.text()+`\nconst loseExtension=renderer.getContext().getExtension('WEBGL_lose_context');window.__double={snapshot:()=>({selected:[...selected],camera:camera.position.toArray(),quaternion:camera.quaternion.toArray(),near:camera.near,inhabited,points:latticePoints().length,screenPoints:latticePoints().slice(0,4).map(p=>world.localToWorld(physical(vector(p))).project(camera).toArray()),visiblePoints:latticePoints().filter(p=>{const v=world.localToWorld(physical(vector(p))).project(camera);return Math.abs(v.x)<1&&Math.abs(v.y)<1&&Math.abs(v.z)<1;}).length,counts:Object.fromEntries(['upper','lower','null','exterior'].map(k=>[k,latticePoints().filter(p=>kind(p)===k).length])),lowerColor:pointColor([-1,1,-2]).getHexString(),upperColor:pointColor([1,-1,2]).getHexString(),disk:disk.visible,cone:cone.visible,calls:renderer.info.render.calls,triangles:renderer.info.render.triangles}),pick:()=>{const rect=renderer.domElement.getBoundingClientRect(),all=latticePoints();for(let i=0;i<all.length;i++){const p=physical(vector(all[i]));world.localToWorld(p);p.project(camera);if(Math.abs(p.x)>.8||Math.abs(p.y)>.8)continue;const ray=new THREE.Raycaster();ray.setFromCamera(new THREE.Vector2(p.x,p.y),camera);if(pickIndex(ray.ray,1e-4)===i)return {point:all[i],x:rect.x+(p.x+1)*rect.width/2,y:rect.y+(1-p.y)*rect.height/2};}return null;},lose:()=>loseExtension};`});});
 await page.reload();await page.waitForFunction(()=>window.__double);
 const initial=await page.evaluate(()=>__double.snapshot());
 if(Object.values(initial.counts).some(n=>n===0)||initial.disk||!initial.cone)throw Error('Bad full double cone default');
 await page.screenshot({path:'output/playwright/double-cone/overview.png'});
 const pick=await page.evaluate(()=>__double.pick());if(!pick)throw Error('No visible sphere for click');await page.mouse.click(pick.x,pick.y);if(JSON.stringify((await page.evaluate(()=>__double.snapshot())).selected)!==JSON.stringify(pick.point))throw Error('Instanced sphere click failed');
 await page.locator('#radius').selectOption('12');const max=await page.evaluate(()=>__double.snapshot());if(max.points>=4000||max.calls>20)throw Error('Geometry budget exceeded');
 await page.locator('#whole').uncheck();const upperOnly=await page.evaluate(()=>__double.snapshot());if(upperOnly.counts.lower||upperOnly.counts.exterior||upperOnly.counts.null)throw Error('Upper-only filter failed');await page.locator('#cone').uncheck();if((await page.evaluate(()=>__double.snapshot())).cone)throw Error('Cone visibility failed');
 await page.locator('#reset').click();await page.locator('#symmetric-color').check();const colored=await page.evaluate(()=>__double.snapshot());if(colored.lowerColor!==colored.upperColor)throw Error('Symmetric extension mismatch');
 await page.locator('#reset').click();await page.locator('#coefficient').fill('-1,1,-2');await page.locator('#coefficient-form button').click();if(!(await page.locator('#root-state').innerText()).includes('0.500 + 1.323i'))throw Error('Negative representative failed');
 await page.locator('#projection').check();if(!(await page.evaluate(()=>__double.snapshot())).disk)throw Error('Projection failed');
 await page.locator('#reset').click();const overview=await page.evaluate(()=>__double.snapshot());
 await page.locator('#inhabit').click();const inside=await page.evaluate(()=>__double.snapshot());if(!inside.inhabited||inside.near!==0.008||inside.visiblePoints<5)throw Error('Inhabit failed');
 await page.screenshot({path:'output/playwright/double-cone/inside.png'});
 await page.keyboard.press('w');const directKey=await page.evaluate(()=>__double.snapshot());if(JSON.stringify(directKey.camera)===JSON.stringify(inside.camera))throw Error('Inhabit did not take keyboard focus');
 await page.locator('#radius').selectOption('4');const changedCrop=await page.evaluate(()=>__double.snapshot());if(JSON.stringify(changedCrop.camera)!==JSON.stringify(directKey.camera))throw Error('Inside crop change moved eye');
 await page.locator('[data-move="forward"]').click();const moved=await page.evaluate(()=>__double.snapshot());if(JSON.stringify(moved.camera)===JSON.stringify(inside.camera)||JSON.stringify(moved.selected)!==JSON.stringify(inside.selected))throw Error('Movement failed');
 if(!moved.screenPoints.some((p,i)=>p.some((x,j)=>Math.abs(x-inside.screenPoints[i][j])>1e-6)))throw Error('No translated-view parallax');
 await page.locator('canvas').first().focus();await page.locator('canvas').first().press('w');
 const keyboard=await page.evaluate(()=>__double.snapshot());if(JSON.stringify(keyboard.camera)===JSON.stringify(moved.camera))throw Error('W navigation failed');
 const box=await page.locator('canvas').first().boundingBox();await page.mouse.move(box.x+box.width/2,box.y+box.height/2);await page.mouse.down();await page.mouse.move(box.x+box.width/2+55,box.y+box.height/2-30,{steps:5});await page.mouse.up();const looked=await page.evaluate(()=>__double.snapshot());if(JSON.stringify(looked.quaternion)===JSON.stringify(moved.quaternion)||JSON.stringify(looked.camera)!==JSON.stringify(keyboard.camera))throw Error('First person look moved eye');
 await page.locator('#inhabit').click();const returned=await page.evaluate(()=>__double.snapshot());if(returned.camera.some((x,i)=>Math.abs(x-overview.camera[i])>1e-8))throw Error('Return lost overview pose');
 await page.context().setOffline(true);await page.locator('#next').click();await page.context().setOffline(false);
 await page.evaluate(()=>__double.lose().loseContext());await page.waitForFunction(()=>!document.querySelector('#fatal').hidden);await page.evaluate(()=>__double.lose().restoreContext());await page.waitForFunction(()=>document.querySelector('#fatal').hidden);
 if(errors.length)throw Error(errors.join('\n'));
 await page.locator('#reset').click();
 await page.setViewportSize({width:390,height:844});await page.screenshot({path:'output/playwright/double-cone/phone.png'});
 await page.setViewportSize({width:844,height:390});await page.screenshot({path:'output/playwright/double-cone/landscape.png'});
 await page.setViewportSize({width:1280,height:900});
 return {passed:true,initial,pick,max,upperOnly,colored,inside,directKey,changedCrop,moved,keyboard,looked,returned,errors,actualXRSession:false};
}
