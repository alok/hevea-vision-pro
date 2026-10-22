// SPDX-License-Identifier: GPL-3.0-or-later
// Real browser input; instrumentation only exposes the existing renderer matrices.
async (page) => {
  const ensure = (ok, message) => { if (!ok) throw Error(message); };
  await page.route('**/app.js*', async route => {
    const response = await route.fetch();
    await route.fulfill({ response, body: await response.text() + '\nwindow.__pickAudit={camera,renderer,activate,vrPickPanel,get points(){return points}};\n' });
  });
  await page.reload(); await page.setViewportSize({width:1440,height:1000});
  const b = name => page.getByRole('button',{name,exact:true});
  const snapshot = async () => JSON.stringify(await page.locator('#word, #point-equation, #lesson-question').allTextContents());
  const pixelFrame = () => page.screenshot({clip:{x:700,y:150,width:600,height:400}});
  const coordinate = async (p,q) => page.evaluate(({p,q}) => {
    const {camera,points}=__pickAudit, mesh=points.find(x=>x.userData.point.p===p&&x.userData.point.q===q);
    const point=mesh.getWorldPosition(mesh.position.clone()).project(camera), rect=document.querySelector('canvas').getBoundingClientRect();
    return {x:rect.left+(point.x+1)*rect.width/2,y:rect.top+(1-point.y)*rect.height/2};
  },{p,q});
  const preview = async () => (await page.locator('#projected-preview').textContent()).split(': ')[1];
  const choose = async (p,q) => {
    for(let count=0;count<130;count++) {
      const [a,d]=(await preview()).split('/').map(Number);
      if(a===p&&d===q) return count;
      await b(a*q>p*d?'Previous fraction':'Next fraction').click();
    }
    throw Error('Preview navigation failed to reach target');
  };
  const cases=[];
  for(const [view,zoom] of [['default',1],['front',1],['front',2]]) for(const dx of [-4,-2,0,2,4]) {
    if(await page.locator('#construction').isVisible()) await b('Done').click();
    await b('Reset').click();await page.locator('#bound').selectOption('14');await b('Construct this direction').click();
    if(view==='front')await b('Front view').click();
    if(zoom===2){await page.locator('canvas').focus();for(let i=0;i<7;i++)await page.locator('canvas').press('+');}
    const before=await snapshot(), frame=await pixelFrame(), at=await coordinate(3,5);
    ensure(await page.evaluate(p=>document.elementFromPoint(p.x,p.y)?.tagName==='CANVAS',{x:at.x+dx,y:at.y}),'Test point is covered by controls');
    await page.mouse.click(at.x+dx,at.y);
    ensure(await page.locator('#projected-choice').isVisible(),'Projected hit did not open a preview');
    const firstPreview=await preview();
    ensure(await snapshot()===before,'Opening preview changed mathematical state');
    ensure(frame.equals(await pixelFrame()),'Opening preview moved or changed the scene');
    const moves=await choose(3,5);
    ensure(await snapshot()===before,'Preview navigation changed mathematical state');
    await b('Select 3/5').click();
    ensure(await page.locator('#rational').inputValue()==='3/5','Explicit selection failed');
    cases.push({view,zoom,dx,firstPreview,moves,selected:'3/5'});
  }
  await b('Done').click();await b('Reset').click();await page.locator('#rational').fill('6/10');await b('Select').click();
  await b('Construct this direction').click();await page.locator('#rational').fill('25/1');
  let at=await coordinate(1,1), before=await snapshot();await page.mouse.click(at.x,at.y);
  await b('Cancel preview').click();ensure(await snapshot()===before,'Cancel changed inspected multiple');
  ensure(await page.locator('#rational').inputValue()==='25/1','Preview lost draft input');
  await b('Done').click();await b('Learn a move').click();await b('2/3').click();await b('Construct this direction').click();
  before=await snapshot();at=await coordinate(1,1);await page.mouse.click(at.x,at.y);await b('Cancel preview').click();
  ensure(await snapshot()===before,'Preview changed lesson prediction');ensure(await b('2/3').getAttribute('aria-pressed')==='true','Prediction not retained');
  await b('Done').click();await b('Close lesson').click();
  const layouts=[];
  const cdp=await page.context().newCDPSession(page);
  await cdp.send('Emulation.setTouchEmulationEnabled',{enabled:true});
  for(const size of [{width:390,height:844},{width:844,height:390}]) {
    await page.setViewportSize(size);await b('Reset').click();await b('Construct this direction').click();at=await coordinate(1,1);
    await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:at.x,y:at.y}]});
    await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
    ensure(await page.locator('#projected-choice').isVisible(),'Emulated touch did not open preview');
    const next=page.locator('#projected-next');await next.focus();await page.keyboard.press('Space');
    ensure(await page.locator('#rational').inputValue()==='1/1','Keyboard preview changed target');
    layouts.push(await page.evaluate(()=>{const c=document.querySelector('.controls');return {width:innerWidth,sceneHeight:document.getElementById('viewport').clientHeight,overflow:c.scrollWidth>c.clientWidth};}));
    ensure(layouts.at(-1).sceneHeight>150&&!layouts.at(-1).overflow,'Preview broke mobile layout');
    await b('Cancel preview').click();await b('Done').click();
  }
  await cdp.send('Emulation.setTouchEmulationEnabled',{enabled:false});await cdp.detach();
  await page.setViewportSize({width:1440,height:1000});await b('Reset').click();await b('Construct this direction').click();
  at=await coordinate(1,1);await page.mouse.click(at.x,at.y);await b('Previous fraction').click();
  const beforeControllerPreview=await snapshot();
  await page.evaluate(()=>__pickAudit.activate([{object:__pickAudit.vrPickPanel.children[2]}]));
  ensure(await snapshot()===beforeControllerPreview,'Controller preview action committed a target');
  ensure(await preview()==='1/1','Controller next action did not update preview');
  await b('Previous fraction').click();
  const memoryBefore=await page.evaluate(()=>({...__pickAudit.renderer.info.memory}));
  for(let i=0;i<40;i++){await b('Previous fraction').click();await b('Next fraction').click();}
  const memoryAfter=await page.evaluate(()=>({...__pickAudit.renderer.info.memory}));
  ensure(JSON.stringify(memoryBefore)===JSON.stringify(memoryAfter),'Preview leaked renderer resources');
  await page.screenshot({path:'output/playwright/projected-preview.png'});
  await page.evaluate(()=>delete window.__pickAudit);
  await page.unroute('**/app.js*');
  return {passed:true,cases,exactSelectionRequired:true,previewAndCancelPreservePointLessonAndCamera:true,mobileTouchAndKeyboard:true,controllerActionWiringOnly:true,memoryBefore,memoryAfter,layouts,actualXRSession:false};
}
