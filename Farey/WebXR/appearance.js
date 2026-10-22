// SPDX-License-Identifier: GPL-3.0-or-later
import { discriminant, kind } from './starscape-core.js';

// Upper-interior color follows Stange's viewer: t = log(|Δ|/3) / log(240/3), interpolated in OKLab
// through her six anchors. The range is fixed, so a given Δ has one color at every crop radius.
export const anchors = ['#F06A6A','#E99456','#D6BD69','#7AB89B','#70A6D8','#AD92D0'];
export const paletteRange = [3, 240];
// 'reference' keeps the v0.9 category colors (her viewer derives its own from OKLCH lightness and
// chroma; those hues are not verified here), whose null gold is also an interior anchor.
// 'contrast' is our choice: every category lies at least 0.1 in OKLab from the interior ramp.
export const categoryPalettes = {
  contrast: { null: '#f2e9d0', exterior: '#3b78ad', lower: '#64717d' },
  reference: { null: '#d6bd69', exterior: '#448abb', lower: '#64717d' },
};

const clamp = (x,lo,hi) => Math.max(lo,Math.min(hi,x));
export const decode = hex => [1,3,5].map(i=>parseInt(hex.slice(i,i+2),16)/255);
const linear = x => x<=0.04045?x/12.92:((x+0.055)/1.055)**2.4;
const gamma = x => x<=0.0031308?12.92*x:1.055*x**(1/2.4)-0.055;
export function oklab(rgb) {
  const [r,g,b]=rgb.map(linear);
  const l=Math.cbrt(0.4122214708*r+0.5363325363*g+0.0514459929*b);
  const m=Math.cbrt(0.2119034982*r+0.6806995451*g+0.1073969566*b);
  const s=Math.cbrt(0.0883024619*r+0.2817188376*g+0.6299787005*b);
  return [0.2104542553*l+0.7936177850*m-0.0040720468*s, 1.9779984951*l-2.4285922050*m+0.4505937099*s, 0.0259040371*l+0.7827717662*m-0.8086757660*s];
}
function fromOklab([L,A,B]) {
  const l=(L+0.3963377774*A+0.2158037573*B)**3, m=(L-0.1055613458*A-0.0638541728*B)**3, s=(L-0.0894841775*A-1.2914855480*B)**3;
  return [4.0767416621*l-3.3077115913*m+0.2309699292*s, -1.2684380046*l+2.6097574011*m-0.3413193965*s, -0.0041960863*l-0.7034186147*m+1.7076147010*s]
    .map(x=>clamp(gamma(clamp(x,0,1)),0,1));
}
const anchorLab = anchors.map(hex=>oklab(decode(hex)));

export const palettePosition = magnitude => clamp(Math.log(magnitude/paletteRange[0])/Math.log(paletteRange[1]/paletteRange[0]),0,1);
export function paletteSample(t) {
  const x=clamp(t,0,1)*(anchorLab.length-1), i=Math.min(anchorLab.length-2,Math.floor(x)), f=x-i;
  return fromOklab(anchorLab[i].map((a,j)=>a*(1-f)+anchorLab[i+1][j]*f));
}
// Colors use the actual Δ of the triple; a nonprimitive multiple k·p has Δ scaled by k².
export function coefficientColor(point, symmetric=false, categories='contrast') {
  const type=kind(point);
  if(type!=='upper'&&!(type==='lower'&&symmetric))return decode(categoryPalettes[categories][type]);
  return paletteSample(palettePosition(-discriminant(point)));
}
export function gradientCSS() {
  const stops=Array.from({length:17},(_,i)=>`rgb(${paletteSample(i/16).map(x=>Math.round(x*255)).join(' ')}) ${i*100/16}%`);
  return `linear-gradient(to right,${stops.join(',')})`;
}

// Glyphs are drawn as flat discs whose on-screen radius stays within these CSS-pixel bounds:
// near points stop growing (point-like), far points stay large enough to show their color.
// Centers never move; only the drawn radius changes.
export const glyphRadius = 0.013;
export const glyphPixels = { min: 1.25, max: 3 };
export const outlinePixels = 1.25;
export function glyphScale(depth, viewportHeight, fovDegrees, zoom=1, extraPixels=0) {
  if(!(depth>0)||!(viewportHeight>0))return 1;
  const pixels=glyphRadius*viewportHeight*zoom/(2*depth*Math.tan(fovDegrees*Math.PI/360));
  return (clamp(pixels,glyphPixels.min,glyphPixels.max)+extraPixels)/pixels;
}
