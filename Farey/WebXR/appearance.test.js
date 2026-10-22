// SPDX-License-Identifier: GPL-3.0-or-later
import test from 'node:test';
import assert from 'node:assert/strict';
import { anchors, categoryPalettes, coefficientColor, decode, drawnPixels, glyphRadius, glyphScale, oklab, outlinePixels, palettePosition, paletteRange, paletteSample, pixelsPerWorld, sizePixels, sourceRadiusFactor } from './appearance.js';
import { vector } from './starscape-core.js';
import { viridis } from './viridis.js';
const distance = (p,q) => Math.hypot(...oklab(p).map((v,i)=>v-oklab(q)[i]));

test('interior position uses Stange\'s fixed logarithmic |Δ| range',()=>{
  assert.deepEqual(paletteRange,[3,240]);
  assert.equal(palettePosition(3),0);assert.equal(palettePosition(240),1);assert.equal(palettePosition(1000),1);
  assert.ok(palettePosition(28)>palettePosition(7));
});
const nearestRamp=(hex,palette)=>Math.min(...Array.from({length:241},(_,i)=>distance(paletteSample(i/240,palette),decode(hex))));
test('Viridis interior is canonical Viridis over [0.2, 1] on the fixed log range',()=>{
  assert.equal(viridis.length,256);
  assert.deepEqual(paletteSample(1),viridis[255]);
  const start=0.2*255,i=Math.floor(start),f=start-i;
  paletteSample(0).forEach((x,j)=>assert.ok(Math.abs(x-(viridis[i][j]*(1-f)+viridis[i+1][j]*f))<1e-12));
  let previous=-1;for(let k=0;k<=64;k++){const L=oklab(paletteSample(k/64))[0];assert.ok(L>previous);previous=L;}
  assert.ok(oklab(paletteSample(0))[0]>0.4,'darkest interior color stays visible on black');
});
test('Viridis categories stay apart from the ramp and each other, including protan/deutan simulation',()=>{
  const sims={normal:null,protan:[[0.152286,1.052583,-0.204868],[0.114503,0.786281,0.099216],[-0.003882,-0.048116,1.051998]],
    deutan:[[0.367322,0.860646,-0.227968],[0.280085,0.672501,0.047413],[-0.011820,0.042940,0.968881]]};
  const lin=x=>x<=0.04045?x/12.92:((x+0.055)/1.055)**2.4, gam=x=>x<=0.0031308?12.92*x:1.055*x**(1/2.4)-0.055;
  const sim=(rgb,m)=>m?m.map(r=>gam(Math.min(1,Math.max(0,r[0]*lin(rgb[0])+r[1]*lin(rgb[1])+r[2]*lin(rgb[2]))))):rgb;
  const colors=Object.values(categoryPalettes.viridis).map(decode);
  for(const [name,m] of Object.entries(sims)) {
    for(const c of colors) {
      const nearest=Math.min(...Array.from({length:241},(_,i)=>distance(sim(paletteSample(i/240),m),sim(c,m))));
      assert.ok(nearest>=0.1,`${name}: ${nearest.toFixed(3)}`);
    }
    for(let i=0;i<colors.length;i++)for(let j=i+1;j<colors.length;j++)assert.ok(distance(sim(colors[i],m),sim(colors[j],m))>=0.1);
  }
});
test('Stange original keeps her anchors; its gold category coincides with an interior anchor',()=>{
  anchors.forEach((hex,i)=>assert.ok(distance(paletteSample(i/5,'reference'),decode(hex))<1e-3,hex));
  assert.ok(nearestRamp(categoryPalettes.reference.null,'reference')<1e-3);
});
test('coloring uses the actual discriminant, not the primitive one',()=>{
  assert.notDeepEqual(coefficientColor([1,-1,2]),coefficientColor([2,-2,4]));
  assert.deepEqual(coefficientColor([1,-1,2]),coefficientColor([-1,1,-2],true));
  for(const mode of ['viridis','reference']) {
    const colors=categoryPalettes[mode];
    assert.deepEqual(coefficientColor([-1,1,-2],false,mode),decode(colors.lower));
    assert.deepEqual(coefficientColor([1,2,1],false,mode),decode(colors.null));
    assert.deepEqual(coefficientColor([1,3,1],false,mode),decode(colors.exterior));
  }
});
test('source radius factors match the constants in Stange\'s viewer',()=>{
  assert.equal(sourceRadiusFactor([1,-1,2]),1);
  assert.equal(sourceRadiusFactor([2,-2,4]),0.72);
  assert.equal(sourceRadiusFactor([1,-1,2],{onPlane:true}),1.35);
  for(const offCone of [[1,2,1],[1,3,1],[-1,1,-2],[2,6,2]])assert.equal(sourceRadiusFactor(offCone),1);
  assert.equal(sourceRadiusFactor([-2,2,-4],{symmetric:true}),0.72);
  assert.equal(sourceRadiusFactor([1,3,1],{origin:true}),1);
  assert.equal(sourceRadiusFactor([-1,1,-2],{origin:true}),sourceRadiusFactor([1,-1,2],{origin:true}));
});
test('from the origin, apparent radius along a ray follows 1/sqrt|Δ| of the primitive form',()=>{
  const apparent=p=>sourceRadiusFactor(p,{origin:true})/Math.hypot(...vector(p));
  // multiples share a ray: k·p looks k times smaller, i.e. 1/sqrt of its |Δ| = k²|Δ₀|
  for(const k of [2,3])assert.ok(Math.abs(apparent([k,-k,2*k])*k-apparent([1,-1,2]))<1e-12);
  // x²+1: 0.4·|Δ|^¼/√(a+c) with |Δ|=4, a+c=2
  assert.ok(Math.abs(sourceRadiusFactor([1,0,1],{origin:true})-0.4*4**0.25/Math.sqrt(2))<1e-12);
});
test('drawn radius: faithful below the knee, cube-root and capped above, dimmed below the minimum',()=>{
  assert.deepEqual(drawnPixels(2),{px:2,dim:1});
  assert.equal(drawnPixels(0.5).px,sizePixels.min);assert.equal(drawnPixels(0.5).dim,0.25);
  assert.ok(Math.abs(drawnPixels(20).px-sizePixels.knee*2)<1e-12);
  assert.equal(drawnPixels(1e6).px,sizePixels.cap);
  let previous=0;for(let px=0.1;px<400;px*=1.1){const d=drawnPixels(px).px;assert.ok(d>=previous);previous=d;}
  const ratio=drawnPixels(40).px/drawnPixels(20).px;assert.ok(ratio>1.25&&ratio<1.27);
});
test('glyph scale reproduces drawnPixels and adds outline pixels',()=>{
  for(const depth of [0.1,0.5,2,6,20]) for(const factor of [0.5,1,1.35]) {
    const base=glyphRadius*pixelsPerWorld(depth,900,45);
    assert.ok(Math.abs(glyphScale(depth,900,45,1,0,factor)*base-drawnPixels(base*factor).px)<1e-9);
    assert.ok(Math.abs(glyphScale(depth,900,45,1,outlinePixels,factor)*base-drawnPixels(base*factor).px-outlinePixels)<1e-9);
  }
});
