// SPDX-License-Identifier: GPL-3.0-or-later
// Run with playwright-cli run-code; receives its current page.
async (page) => {
  const assert = {
    equal(a,b) { if(a !== b) throw Error(`Expected ${b}; got ${a}`); },
    ok(value) { if(!value) throw Error('Assertion failed'); },
    match(value,pattern) { if(!pattern.test(value)) throw Error(`Unexpected value: ${value}`); },
    deepEqual(a,b) { if(JSON.stringify(a)!==JSON.stringify(b)) throw Error('Values differ'); }
  };
  const errors=[];
  page.on('pageerror', error=>errors.push(error.message));
  await page.reload();
  await page.setViewportSize({width:390,height:844});
  const button=name=>page.getByRole('button',{name,exact:true});
  await button('Reset').click();
  assert.equal(await page.locator('canvas').getAttribute('role'),'img');
  assert.equal(await page.locator('canvas').getAttribute('tabindex'),'0');
  assert.equal(await button('L').getAttribute('aria-describedby'),'left-help');
  const canvas = page.locator('canvas');
  await canvas.focus();
  let frame = await canvas.screenshot();
  for (const key of ['ArrowRight', 'Shift+ArrowUp', '+']) {
    await canvas.press(key);
    const next = await canvas.screenshot();
    assert.ok(!frame.equals(next)); frame = next;
  }
  await canvas.press('Home');
  assert.equal(await page.locator('#fraction').textContent(),'0/1 < 1/1 < ∞');
  await page.locator('#rational').focus(); frame = await canvas.screenshot();
  await page.keyboard.press('ArrowRight');
  assert.ok(frame.equals(await canvas.screenshot()));
  await button('Learn a move').click();
  await button('2/3').focus(); await page.keyboard.press('Space');
  assert.equal(await page.evaluate(()=>document.activeElement.textContent),'2/3');
  await page.keyboard.press('Tab'); await page.keyboard.press('Tab');
  assert.equal(await page.evaluate(()=>document.activeElement.textContent),'Apply L');
  await page.keyboard.press('Enter');
  assert.equal(await page.locator('#fraction').textContent(),'1/2 < 2/3 < 1/1');
  assert.equal(await page.evaluate(()=>document.activeElement.textContent),'Predict R next');
  await page.keyboard.press('Enter'); await page.keyboard.press('Tab'); await page.keyboard.press('Space');
  await page.keyboard.press('Tab'); await page.keyboard.press('Tab'); await page.keyboard.press('Enter');
  assert.equal(await page.locator('#fraction').textContent(),'1/2 < 3/5 < 2/3');
  assert.match(await page.locator('#geometry-description').textContent(),/Selected fraction 3 over 5/);
  assert.equal(await page.evaluate(()=>document.activeElement.textContent),'Close lesson');
  const layout=await page.evaluate(()=>({scene:document.getElementById('viewport').getBoundingClientRect().toJSON(),controls:document.querySelector('.controls').getBoundingClientRect().toJSON()}));
  assert.ok(layout.scene.height>200); assert.ok(layout.scene.bottom<=layout.controls.top);
  await page.keyboard.press('Enter');
  assert.equal(await page.evaluate(()=>document.activeElement.textContent),'Learn a move');
  await button('Undo').click();
  assert.equal(await page.locator('#fraction').textContent(),'1/2 < 2/3 < 1/1');
  await button('Reset').click();
  assert.equal(await page.locator('#fraction').textContent(),'0/1 < 1/1 < ∞');
  for(let i=0;i<24;i++)await button(i%2?'R':'L').click();
  assert.ok(await button('L').isDisabled());assert.ok(await button('R').isDisabled());
  assert.match(await page.locator('#matrix').textContent(),/det M = 1/);
  assert.ok(await page.evaluate(()=>document.querySelector('.controls').scrollWidth<=document.querySelector('.controls').clientWidth));
  await button('Undo').click();assert.ok(await button('L').isEnabled());
  await button('Reset').click(); await page.locator('#bound').selectOption('14');
  assert.match(await page.locator('#receipt').textContent(),/^224 lattice points/);
  await page.locator('#rational').fill('6/10'); await button('Select').click();
  assert.equal(await page.locator('#fraction').textContent(),'1/2 < 3/5 < 2/3');
  assert.equal(await page.locator('#rational').inputValue(),'3/5');
  await page.locator('#rational').fill('1/1000'); await button('Select').click();
  assert.equal(await page.locator('#fraction').textContent(),'1/2 < 3/5 < 2/3');
  assert.match(await page.locator('#receipt').textContent(),/Choose positive integers/);
  for(const size of [{width:844,height:390},{width:1440,height:1000},{width:390,height:844}]) {
    await page.setViewportSize(size);await button('Reset').click();
    assert.equal(await page.locator('#fraction').textContent(),'0/1 < 1/1 < ∞');
    assert.ok(await page.evaluate(()=>document.getElementById('viewport').clientHeight>0));
    if(size.height < 500) assert.ok(await page.evaluate(()=>document.getElementById('viewport').getBoundingClientRect().left>document.querySelector('.controls').getBoundingClientRect().right));
  }
  assert.deepEqual(errors,[]);
  return {passed:true,keyboardScene:true,keyboardLesson:true,layout,limitAndRecovery:true,reducibleSelection:true,invalidSelectionRejected:true,portraitLandscapeReset:true,pageErrors:errors};
}
