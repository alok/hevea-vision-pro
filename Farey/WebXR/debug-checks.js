// Run with playwright-cli run-code --filename debug-checks.js on the served coefficient page.
async page => {
  const check=(ok,message)=>{if(!ok)throw Error(message);};
  await page.reload();
  check(await page.locator('#debug').isHidden(),'Debug must start closed');
  await page.setViewportSize({width:390,height:844});
  await page.locator('#debug-toggle').click();
  const phone=await page.locator('#debug').boundingBox();
  check(phone.x>=0&&phone.x+phone.width<=390,'Debug clips beyond the phone viewport');
  await page.locator('#debug-close').click();
  await page.setViewportSize({width:1280,height:900});
  await page.locator('#debug-toggle').click();
  await page.evaluate(()=>{
    window.closedDebugUpdates=0;
    window.debugObserver=new MutationObserver(()=>{if(document.getElementById('debug').hidden)window.closedDebugUpdates++;});
    window.debugObserver.observe(document.getElementById('debug-rows'),{childList:true});
  });
  await page.locator('#debug-frames').click();
  check(await page.locator('#debug-frames').isDisabled(),'A measurement must prevent duplicate runs');
  await page.locator('#debug-close').click();
  await page.waitForTimeout(1300);
  const closedUpdates=await page.evaluate(()=>window.closedDebugUpdates);
  check(closedUpdates===0,'Measurement updated the closed overlay');
  await page.locator('#debug-toggle').click();
  check(await page.locator('#debug-frames').isEnabled(),'A cancelled measurement must be restartable');
  await page.locator('#debug-close').click();
  await page.locator('#inhabit').click();
  await page.locator('#debug-toggle').click();
  await page.keyboard.press('Escape');
  check(await page.locator('#debug').isHidden(),'Escape must close Debug');
  check(await page.locator('#navigation').isVisible(),'Closing Debug must preserve Inhabit');
  await page.locator('#inhabit').click();
  await page.locator('#debug-toggle').click();
  await page.locator('#debug-frames').click();
  await page.waitForFunction(()=>!document.getElementById('debug-frames').disabled);
  const rows=await page.locator('#debug-rows').innerText();
  check(rows.includes('median')&&rows.includes('vsync-capped'),'Completed interval must be labelled');
  await page.locator('#debug-close').click();
  await page.evaluate(()=>window.debugObserver.disconnect());
  return {passed:true,phone,closedUpdates,measurementCompleted:true,escapePreservesView:true};
}
