# SPDX-License-Identifier: GPL-3.0-or-later
from pathlib import Path
import subprocess,tempfile,json,hashlib,os,math,shutil
repo=Path(__file__).resolve().parents[2]  # Farey/evidence/parity-0110/crosscheck.py
out=Path(tempfile.mkdtemp(prefix='farey-plane-crosscheck-'))
files=['Starscape.swift','CoefficientBall.swift','CoefficientPalette.swift','Viridis.swift','CuttingPlane.swift']
for f in files:(out/f).write_bytes((repo/'Packages/FareyCore/Sources/FareyCore'/f).read_bytes())
(out/'main.swift').write_text('''import Foundation
let points = CoefficientBall.points(radius: 6)
let interiors = points.filter { $0.discriminant < 0 }
func key(_ p: CoefficientPoint) -> String { "\\(p.a),\\(p.b),\\(p.c)" }
var rows: [String: Any] = [:]
var planes: [String: CuttingPlane] = [:]
func record(_ result: Result<CuttingPlane,CuttingPlaneError>, _ k: String) {
  switch result {
  case .failure: rows[k] = ["error": true]
  case .success(let p):
    let n=p.normal
    rows[k] = ["normal":[n.a,n.b,n.c],"equation":p.equation,"endpoints":p.endpoints.map(\\.label)]
    planes[key(n)]=p
  }
}
for i in interiors.indices { for j in i..<interiors.count { record(CuttingPlane.pair(interiors[i],interiors[j]),"p:"+key(interiors[i])+"|"+key(interiors[j])) } }
for p in points { record(CuttingPlane.fromNormal(p), "n:"+key(p)) }
var shapes: [String: Any] = [:]
for (k,p) in planes {
  let section=p.section(radius:6)
  shapes[k] = ["directions": p.coneDirections.map { [$0.x,$0.y,$0.z] }, "section":section.map{[$0.x,$0.y,$0.z]},"members":points.filter{p.contains($0)}.map(key).sorted()]
}
var sizes: [String: Double] = [:]
for r in CoefficientBall.radii { for p in CoefficientBall.points(radius:r) { sizes[key(p)] = CoefficientPalette.originRadiusFactor(for:p) } }
let value: [String:Any] = ["rows":rows,"shapes":shapes,"sizes":sizes]
FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys]))
''')
js='''import {coefficientLattice,discriminant} from './starscape-core.js';
import {pairPlane,planeFromNormal,coneDirections,planeSection,inPairPlane} from './pair-plane.js';
import {sourceRadiusFactor} from './appearance.js';
const points=coefficientLattice(6), interiors=points.filter(p=>discriminant(p)<0),key=p=>p.join(',');
const rows={},planes={};function record(p,k){if(p.error){rows[k]={error:true};return;}rows[k]={normal:p.normal,equation:p.equation,endpoints:p.endpoints.map(e=>e.label)};planes[key(p.normal)]=p;}
for(let i=0;i<interiors.length;i++)for(let j=i;j<interiors.length;j++)record(pairPlane(interiors[i],interiors[j]),'p:'+key(interiors[i])+'|'+key(interiors[j]));
for(const p of points)record(planeFromNormal(p),'n:'+key(p));
const shapes={};for(const[k,p]of Object.entries(planes))shapes[k]={directions:coneDirections(p),section:planeSection(p.normal,6),members:points.filter(q=>inPairPlane(p.normal,q)).map(key).sort()};
const sizes={};for(const r of[4,6,8,10,12])for(const p of coefficientLattice(r))sizes[key(p)]=sourceRadiusFactor(p,{origin:true});
console.log(JSON.stringify({rows,shapes,sizes}));
'''
# Import the frozen authored modules under their original relative names.
for f in ['starscape-core.js','pair-plane.js','appearance.js','viridis.js']:(out/f).write_bytes((repo/'WebXR'/f).read_bytes())
(out/'package.json').write_text('{"type":"module"}')
(out/'probe.mjs').write_text(js)
env=dict(os.environ,CLANG_MODULE_CACHE_PATH=str(out/'clang-cache'),SWIFT_MODULECACHE_PATH=str(out/'swift-cache'))
build=subprocess.run(['/usr/bin/swiftc','-module-cache-path',str(out/'swift-cache')]+[str(out/f)for f in files]+[str(out/'main.swift'),'-o',str(out/'probe')],capture_output=True,text=True,env=env)
(out/'compile.log').write_text(build.stdout+build.stderr);build.check_returncode()
a=json.loads(subprocess.check_output([str(out/'probe')],env=env));b=json.loads(subprocess.check_output([shutil.which('node') or '/opt/homebrew/bin/node',str(out/'probe.mjs')]))
(out/'native.json').write_text(json.dumps(a));(out/'browser.json').write_text(json.dumps(b))
def canonical(rows):
 result={}
 for k,v in rows.items():
  if k.startswith('p:'):k='p:'+'|'.join(sorted(k[2:].split('|')))
  result[k]=v
 return result
assert canonical(a['rows'])==canonical(b['rows']),'Exact plane normal/equation/endpoint label mismatch'
assert a['shapes'].keys()==b['shapes'].keys()
maxerr=0
for k,sa in a['shapes'].items():
 sb=b['shapes'][k];assert sa['members']==sb['members'],('membership',k)
 for name in ['directions','section']:
  assert len(sa[name])==len(sb[name])
  for va,vb in zip(sa[name],sb[name]):
   for x,y in zip(va,vb):maxerr=max(maxerr,abs(x-y));assert abs(x-y)<3e-12,(k,name,x,y)
assert a['sizes'].keys()==b['sizes'].keys()
sizeerr=max(abs(a['sizes'][k]-b['sizes'][k])for k in a['sizes']);assert sizeerr<1e-12
res={'passed':True,'cases':len(a['rows']),'uniquePlanes':len(a['shapes']),'exactNormalsEquationsEndpoints':'equal','exactPlaneMemberships':'equal','maximumDirectionOrSectionError':maxerr,'originSizePointsR4ThroughR12':len(a['sizes']),'maximumOriginSizeError':sizeerr,'sourceSHA256':{f:hashlib.sha256((out/f).read_bytes()).hexdigest()for f in files+['pair-plane.js','appearance.js','starscape-core.js']},'scope':'Frozen authored native core vs browser source data and rendered section inputs, not a screenshot, UI or XR test.'}
(out/'result.json').write_text(json.dumps(res,indent=2)+'\n');print(json.dumps({'directory':str(out),**res},indent=2))
