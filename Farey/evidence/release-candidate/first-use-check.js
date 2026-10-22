// SPDX-License-Identifier: GPL-3.0-or-later
async page => {
 const require = (value, message) => { if (!value) throw Error(message); };
 await page.evaluate(() => sessionStorage.clear());
 await page.reload();
 await page.locator('#word').filter({hasText:'Start'}).waitFor();
 require((await page.locator('.credit').textContent()).includes('Katherine Stange'),'Missing Stange credit');
 require((await page.locator('#fraction').textContent())==='0/1 < 1/1 < ∞','Incorrect fresh state');
 const states=[];
 for (const id of ['example','left','undo','reset']) {
  await page.locator('#'+id).click(); states.push(await page.locator('#fraction').textContent());
 }
 require(JSON.stringify(states)===JSON.stringify(['1/2 < 3/5 < 2/3','3/5 < 5/8 < 2/3','1/2 < 3/5 < 2/3','0/1 < 1/1 < ∞']),'First-time sequence differs');
 require(!(await page.locator('#precision-notice').isVisible()),'Ordinary selection has a stale notice');
 return {passed:true,states,credit:true,actualXRSession:false};
}
