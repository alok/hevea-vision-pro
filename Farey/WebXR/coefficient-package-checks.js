// SPDX-License-Identifier: GPL-3.0-or-later
// Exercise the packaged primary page, with all non-loopback requests blocked.
async page => {
  const url=new URL(page.url());
  if(!['127.0.0.1','localhost'].includes(url.hostname))throw Error('Use loopback');
  url.pathname=url.pathname.replace(/[^/]*$/,'');url.search='';
  const browser=page.context().browser(),contexts=[],external=[],errors=[];
  const check=(ok,message)=>{if(!ok)throw Error(message);};
  const fresh=async options=>{
    const context=await browser.newContext({viewport:{width:1280,height:900},serviceWorkers:'block',...options});contexts.push(context);
    await context.route('**/*',route=>{
      if(new URL(route.request().url()).origin!==url.origin){external.push(route.request().url());return route.abort();}
      return route.continue();
    });
    return {context,tab:await context.newPage()};
  };
  const ready=async tab=>{
    await tab.locator('#xr').filter({hasText:/VR unavailable here|Enter VR/}).waitFor();
    check(await tab.locator('canvas').count()===1,'No coefficient canvas');
    check(await tab.locator('#fatal').isHidden(),'Unexpected graphics error');
  };
  try{
    const {context,tab}=await fresh();tab.on('pageerror',e=>errors.push(e.message));
    await tab.goto(url.href);await ready(tab);
    check((await tab.locator('#point-state').innerText()).includes('(1, -1, 2)'),'Wrong fresh coefficient');
    check(await tab.locator('#palette').inputValue()==='viridis','Wrong fresh palette');
    check(await tab.locator('#debug').isHidden(),'Debug starts open');
    check(await tab.locator('#radius').inputValue()==='6','Wrong fresh crop');
    await context.setOffline(true);
    await tab.locator('#origin').click();
    check(await tab.locator('#origin-note').isVisible(),'Origin did not work offline');
    await tab.locator('[data-look="down"]').click();
    await tab.locator('#inhabit').click();
    check(await tab.locator('#navigation').isHidden(),'Overview did not return');
    await tab.locator('#coefficient').fill('1,0,1');await tab.locator('#coefficient-form button').click();
    await tab.locator('#coefficient').fill('1,1,1');await tab.locator('#pair-add').click();
    check((await tab.locator('#pair-equation').innerText()).includes('2a'),'No pair plane offline');
    await tab.locator('#plane-focus').check();
    await tab.locator('#reset').click();
    await context.setOffline(false);
    await tab.reload();await ready(tab);
    check(await tab.locator('#radius').inputValue()==='6'&&await tab.locator('#pair-details').isHidden(),'Fresh coefficient scene inherited temporary state');
    const layouts=[];
    for(const size of [{width:390,height:844},{width:844,height:390}]){
      await tab.setViewportSize(size);
      const layout=await tab.evaluate(()=>{const r=document.getElementById('viewport').getBoundingClientRect();return {width:innerWidth,height:innerHeight,scrollWidth:document.documentElement.scrollWidth,sceneWidth:r.width,sceneHeight:r.height};});
      check(layout.scrollWidth<=layout.width&&layout.sceneWidth>80&&layout.sceneHeight>60,'Coefficient scene clips or overflows');layouts.push(layout);
    }
    const blocked=await fresh();await blocked.tab.route('**/starscape.js*',r=>r.abort());
    await blocked.tab.goto(url.href);await blocked.tab.locator('#fatal').waitFor({state:'visible'});
    check((await blocked.tab.locator('#fatal').innerText()).includes('spatial view could not load'),'Module failure unexplained');
    check(await blocked.tab.locator('.controls button:not([disabled])').count()===0,'Module failure leaves active-looking controls');
    check(await blocked.tab.locator('#debug-toggle').isDisabled(),'Failed module leaves Debug active');
    const noGL=await fresh();const expected=[];noGL.tab.on('pageerror',e=>expected.push(e.message));
    await noGL.context.addInitScript(()=>{const original=HTMLCanvasElement.prototype.getContext;HTMLCanvasElement.prototype.getContext=function(type,...args){return /webgl/.test(type)?null:original.call(this,type,...args);};});
    await noGL.tab.goto(url.href);await noGL.tab.locator('#fatal').waitFor({state:'visible'});
    check((await noGL.tab.locator('#fatal').innerText()).includes('WebGL is unavailable'),'No WebGL explanation');
    check(expected.every(e=>e.includes('WebGL unavailable')),'Unexpected no-WebGL error');
    const noJS=await fresh({javaScriptEnabled:false});await noJS.tab.goto(url.href);
    check(await noJS.tab.locator('.startup-error').isVisible()&&await noJS.tab.locator('.controls').isHidden(),'No-JS fallback has unusable controls');
    check(external.length===0&&errors.length===0,'External request or unexpected page error');
    return {passed:true,browser:browser.version(),primaryLoadedPageWorksOffline:true,moduleFailureExplained:true,webGLFailure:'mocked context creation failure',noJSExplained:true,temporaryCoefficientStateNotPersisted:true,layouts,externalRequests:external,errors,actualXRSession:false};
  }finally{for(const context of contexts.reverse())await context.close();}
}
