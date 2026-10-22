// SPDX-License-Identifier: GPL-3.0-or-later
// Playwright CLI audit; renderer references are exposed only in the test response.
async page => {
  if (!['127.0.0.1', 'localhost', '[::1]'].includes(new URL(page.url()).hostname)) throw Error('Use a loopback demo URL.');
  const ensure=(ok,message)=>{if(!ok)throw Error(message)};
  const hook=async route=>{const response=await route.fetch();await route.fulfill({response,body:await response.text()+'\nwindow.__mathAudit={state,lattice,selection,construction,get points(){return points},get bound(){return bound}};\n'});};
  await page.route('**/app.js*',hook);
  try {
    await page.reload();await page.setViewportSize({width:1440,height:1000});
    await page.locator('#reset').click();await page.locator('#bound').selectOption('14');
    const shape=async()=>page.evaluate(async()=>{
      const {state,lattice,selection,construction,points,bound}=__mathAudit;
      const THREE=await import('three'),phase=construction.stage??3,s=.25/Math.sqrt(2),theta=Math.PI/7;
      let maxCoordinateError=0,visible=0,visibleExpected=0;const mismatches=[];
      const gcd=(a,b)=>{while(b)[a,b]=[b,a%b];return a};
      for(const mesh of points){
        const {p,q}=mesh.userData.point;const projected=phase<2&&q>0;
        const a=projected?p/q:p,b=projected?1:q;
        const expected=[(a-b)*s,0,-(a+b)*s];
        for(let i=0;i<3;i++)maxCoordinateError=Math.max(maxCoordinateError,Math.abs(mesh.position.getComponent(i)-expected[i]));
        const expectedVisible=phase>=2||(q>0&&gcd(p,q)===1);
        if(mesh.visible!==expectedVisible)mismatches.push([p,q,'visibility']);
        if(mesh.visible)visible++;if(expectedVisible)visibleExpected++;
        if(phase>=2){const world=mesh.getWorldPosition(new THREE.Vector3());const expectedWorld=[expected[0],1.8-expected[2]*Math.sin(theta),-2.1+expected[2]*Math.cos(theta)];
          for(let i=0;i<3;i++)maxCoordinateError=Math.max(maxCoordinateError,Math.abs(world.getComponent(i)-expectedWorld[i]));}
      }
      const plane=selection.children.find(x=>x.isMesh&&x.geometry.getAttribute('position').count===4);
      const planePoints=Array.from(plane.geometry.getAttribute('position').array);
      const m=state.mediant,k=bound/Math.max(m.p,m.q),end=[(m.p-m.q)*k*s,0,-(m.p+m.q)*k*s];
      const expectedPlane=[0,0,0,...end,0,.65,0,end[0],.65,end[2]];
      const planeError=Math.max(...planePoints.map((v,i)=>Math.abs(v-expectedPlane[i])));
      const inspected=points.find(x=>state.selectedPoint&&x.userData.point.p===state.selectedPoint.p&&x.userData.point.q===state.selectedPoint.q);
      const primitive=points.find(x=>x.userData.point.p===m.p&&x.userData.point.q===m.q);
      return {word:state.word,target:m,point:state.selectedPoint,phase,visible,visibleExpected,maxCoordinateError,planeError,mismatches,
        planeVisible:selection.visible,inspectionVisible:inspected?.visible??false,inspectionColor:inspected?.material.color.getHex()??null,
        primitiveColor:primitive?.material.color.getHex()??null,
        receipt:document.getElementById('receipt').textContent,constructionActive:construction.stage!==null,explanation:construction.stage!==null?document.getElementById('construction-explanation').textContent:''};
    });
    const cases=[],constructionStages=[];
    for(const value of ['6/10','1/25','25/1','5/3','1000/1000']){
      await page.locator('#rational').fill(value);await page.getByRole('button',{name:'Select',exact:true}).click();
      const before=await shape();if(value==='6/10')ensure(before.inspectionColor===0xffffff&&before.inspectionVisible&&before.primitiveColor===0xffa140,'Inspected multiple not distinguished');ensure(before.maxCoordinateError<1e-12&&before.planeError<3e-7&&!before.mismatches.length,'Incorrect lattice/plane '+value);
      await page.locator('#cf-summary').click();await page.locator('#cf-alternate').check();
      const alternate=await shape();ensure(JSON.stringify(alternate.target)===JSON.stringify(before.target)&&JSON.stringify(alternate.point)===JSON.stringify(before.point)&&alternate.word===before.word,'CF toggle changed exact state');
      await page.locator('#cf-alternate').uncheck();await page.locator('#cf-summary').click();
      await page.locator('#construction-start').click();
      for(let stage=0;stage<4;stage++){
        const current=await shape();ensure(current.phase===stage&&current.maxCoordinateError<1e-12&&current.planeError<3e-7&&!current.mismatches.length,'Incorrect construction '+value+' stage '+stage);
        ensure(JSON.stringify(current.target)===JSON.stringify(before.target)&&JSON.stringify(current.point)===JSON.stringify(before.point)&&current.word===before.word,'Construction changed exact state');
        ensure(current.planeVisible===(stage===3),'Plane visible in wrong construction stage');constructionStages.push({input:value,...current});
        if(value==='25/1')ensure(current.explanation.includes('beyond the visible'),'Missing out-of-chart qualifier');
        if(stage<3)await page.locator('#construction-next').click();
      }
      await page.locator('#construction-close').click();cases.push(before);
    }
    await page.locator('#reset').click();await page.locator('#bound').selectOption('14');
    for(let i=0;i<24;i++)await page.locator(i%2?'#right':'#left').click();
    const deep=await shape();ensure(deep.word==='LR'.repeat(12)&&deep.maxCoordinateError<1e-12&&deep.planeError<3e-7,'Deep state geometry differs');
    ensure(deep.receipt.includes('beyond the finite grid'),'Deep vector silently clipped');
    ensure(await page.locator('#left').isDisabled()&&await page.locator('#right').isDisabled(),'Missing path bound');
    await page.locator('#undo').click();await page.locator('#right').click();ensure((await shape()).word===deep.word,'Deep undo/replay differs');
    await page.locator('#reset').click();await page.locator('#rational').fill('6/10');await page.getByRole('button',{name:'Select',exact:true}).click();
    await page.locator('#bound').selectOption('6');const hidden=await shape();ensure(!hidden.inspectionVisible&&hidden.point.p===6&&hidden.point.q===10,'Off-grid inspection was clamped');
    ensure((await page.locator('#point-detail').textContent()).includes('beyond this finite grid'),'Off-grid point not explained');
    return {passed:true,cases,constructionStages,deep,hidden,instrumentedRendererInspection:true,actualXRSession:false};
  } finally {await page.unroute('**/app.js*',hook);}
}
