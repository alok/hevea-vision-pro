// SPDX-License-Identifier: GPL-3.0-or-later
async (page) => {
  const ensure = (ok, why) => { if (!ok) throw Error(why); };
  const button = name => page.getByRole('button', { name, exact: true });
  const frame = () => page.screenshot({clip:{x:600,y:150,width:800,height:400}});
  const phase = n => page.locator('#construction-heading').textContent().then(t => t.startsWith(`${n}/4`));
  await page.setViewportSize({width:1440,height:1000}); await page.reload();
  await page.locator('#rational').fill('6/10'); await button('Select').click();
  await page.locator('#cf-summary').click();
  await page.locator('#cf-path li[data-fraction="2/3"] button').click();
  const before = await frame();
  await button('Construct this direction').click(); ensure(await phase(1),'Boundary missing');
  ensure((await page.locator('#receipt').textContent()).includes('92 projected direction dots'),'Projected dots mislabelled as integer points');
  ensure((await page.locator('canvas').getAttribute('aria-label')).includes('Projected rational directions'),'Canvas chart label missing');
  ensure((await page.locator('#point-detail').textContent()).includes('retained integer coordinates'),'Retained point confused with projected position');
  await page.screenshot({path:'output/playwright/construction-boundary.png'});
  await button('Next').click(); ensure(await phase(2),'Ray missing');
  await page.locator('#construction-motion').check(); await button('Next').click();
  ensure(await button('Stop').isEnabled(),'Motion did not start');
  ensure((await page.locator('#receipt').textContent()).includes('illustrative motion'),'Moving markers mislabelled');
  await page.waitForFunction(()=>document.getElementById('construction-stop').disabled);
  ensure((await page.locator('#receipt').textContent()).includes('168 lattice points'),'Natural finish did not restore integer description');
  ensure((await page.locator('#geometry-description').textContent()).includes('plane appears in the next step'),'Hidden plane described as visible');
  ensure((await page.locator('#geometry-hint').textContent()).includes('plane appears in the next step'),'Visible hint describes a hidden plane');
  await button('Back').click(); await button('Next').click();
  await page.waitForTimeout(120); await button('Stop').click();
  ensure(await button('Stop').isDisabled(),'Motion did not stop');
  ensure(await phase(3),'Lattice missing');
  const settled = await frame();
  await button('Back').click(); await button('Next').click();
  await page.waitForTimeout(100);
  await page.evaluate(()=>{
    window.constructionLoss=document.querySelector('canvas').getContext('webgl2').getExtension('WEBGL_lose_context');
    constructionLoss.loseContext();
  });
  await page.locator('#graphics-notice').waitFor({state:'visible'});
  await page.waitForTimeout(200); await page.evaluate(()=>constructionLoss.restoreContext());
  await page.locator('#graphics-notice').waitFor({state:'hidden'});
  ensure(settled.equals(await frame()),'Context restoration left intermediate non-integer positions');
  await page.screenshot({path:'output/playwright/construction-lattice.png'});
  await button('Next').click(); ensure(await phase(4),'Plane missing');
  await button('Done').click();
  ensure(before.equals(await frame()),'Done changed the original view');
  ensure(await page.locator('#word').textContent()==='RLR','Path changed');
  ensure((await page.locator('#point-equation').textContent()).includes('(10, 6)'),'Point identity changed');
  ensure((await page.locator('#spotlight-status').textContent()).includes('Spotlight 2/3'),'Spotlight changed');
  await page.emulateMedia({reducedMotion:'reduce'}); await button('Construct this direction').click();
  ensure(await page.locator('#construction-motion').isDisabled(),'Reduced Motion not enforced');
  await button('Next').click(); await button('Next').click();
  ensure(await button('Stop').isDisabled(),'Reduced Motion animated');
  await button('Restart construction').click(); ensure(await phase(1),'Restart failed');
  await button('Done').click();
  await page.locator('#rational').fill('25/1');
  await page.emulateMedia({reducedMotion:'no-preference'}); await page.waitForTimeout(100);
  ensure(await page.locator('#rational').inputValue()==='25/1','Preference change lost draft input'); await button('Select').click(); await button('Construct this direction').click();
  ensure((await page.locator('#construction-explanation').textContent()).includes('beyond the visible'),'Missing bounds explanation');
  await button('Next').click(); await button('Next').click();
  ensure((await page.locator('#construction-explanation').textContent()).includes('outside grid 12'),'Missing lattice bounds');
  await page.reload();
  ensure(!await page.locator('#construction').isVisible(),'Reload restarted the construction');
  ensure(await page.locator('#word').textContent()==='L'.repeat(24),'Reload lost the mathematical selection');
  await button('Learn a move').click(); await button('2/3').click();
  const question=await page.locator('#lesson-question').textContent();
  await button('Construct this direction').click(); await button('Next').click(); await button('Done').click();
  ensure(await page.locator('#lesson-question').textContent()===question,'Lesson changed');
  ensure(await button('2/3').getAttribute('aria-pressed')==='true','Prediction changed');
  await button('Close lesson').click(); await button('Reset').click();
  for (const size of [{width:390,height:844},{width:844,height:390}]) {
    await page.setViewportSize(size); await button('Construct this direction').click();
    ensure(await page.evaluate(()=>document.getElementById('viewport').clientHeight>150),'Construction hid mobile scene');
    ensure(await page.evaluate(()=>{const c=document.querySelector('.controls');return c.scrollWidth<=c.clientWidth;}),'Construction overflowed mobile controls');
    ensure(await page.evaluate(()=>{
      const c=document.querySelector('.controls').getBoundingClientRect(), b=document.getElementById('construction-next').getBoundingClientRect();
      return b.top>=c.top && b.bottom<=c.bottom;
    }),'Next is below the fold');
    await button('Done').click();
  }
  await page.setViewportSize({width:1440,height:1000});
  return {passed:true,stages:4,restoredPixels:true,preservedTargetPointSpotlightAndLesson:true,
    motionOptInAndStop:true,reducedMotion:true,outsideChartExplained:true,contextLossSettlesAnimation:true,actualXRSession:false};
}
