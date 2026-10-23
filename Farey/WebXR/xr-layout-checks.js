// SPDX-License-Identifier: GPL-3.0-or-later
// CSS-ONLY layout check for an already-served loopback build: it toggles the page's own `immersive` class, exactly as
// entering and leaving a session does, without any XRSession, frame, pose or permission. It is not XR validation.
async page => {
  if(!['127.0.0.1','localhost'].includes(new URL(page.url()).hostname))throw Error('Use loopback');
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.reload();
  const ensure=(condition,message)=>{if(!condition)throw Error(message);};
  const layout=()=>page.evaluate(()=>{const css=id=>getComputedStyle(document.getElementById(id)),r=document.getElementById('viewport').getBoundingClientRect();
    return {pane:css('roots-pane').display,toggle:css('view-switch').display,debug:css('debug-toggle').display,view:css('viewport').visibility,
      viewRect:[r.left,r.top,r.right,r.bottom],window:[innerWidth,innerHeight],rootsView:document.body.classList.contains('roots-view')};});
  const setImmersive=on=>page.evaluate(v=>{document.body.classList.toggle('immersive',v);},on);
  const report={cssOnly:true};
  for(const [size,roots] of [[{width:1440,height:900},false],[{width:390,height:844},true]]){
    const tag=`${size.width}x${size.height}`;
    await page.setViewportSize(size);await page.waitForTimeout(300);
    if(roots){await page.locator('#show-roots').click();await page.waitForTimeout(200);}
    const before=await layout();
    await setImmersive(true);
    const during=await layout();
    ensure(during.pane==='none'&&during.toggle==='none'&&during.debug==='none',`${tag}: overlays stay visible in immersive mode ${JSON.stringify(during)}`);
    ensure(during.view==='visible'&&during.viewRect[0]===0&&during.viewRect[1]===0&&during.viewRect[2]===size.width&&during.viewRect[3]===size.height,`${tag}: the 3D container is not the whole window ${JSON.stringify(during)}`);
    await setImmersive(false);
    const after=await layout();
    ensure(JSON.stringify(after)===JSON.stringify(before),`${tag}: leaving immersive mode did not restore the layout ${JSON.stringify(after)} vs ${JSON.stringify(before)}`);
    report[tag]={before,during,after};
    if(roots){await page.locator('#show-3d').click();}
  }
  ensure(!errors.length,errors.join('; '));
  return report;
}
