// SPDX-License-Identifier: GPL-3.0-or-later
import test from 'node:test';
import assert from 'node:assert/strict';
import { Quaternion, Vector3 } from 'three';
import { cameraPlaneAngles } from './camera-planes.js';
const near = (a,b) => assert.ok(Math.abs(a-b)<1e-10, `${a} != ${b}`);
test('positive oriented planes have the stated right-handed signs',()=>{
 for(const [key,axis,start,end] of [
  ['zx',[0,1,0],[0,0,1],[1,0,0]],
  ['yz',[1,0,0],[0,1,0],[0,0,1]],
  ['xy',[0,0,1],[1,0,0],[0,1,0]]
 ]) {
  const q=new Quaternion().setFromAxisAngle(new Vector3(...axis),Math.PI/4);
  near(cameraPlaneAngles(q)[key],Math.PI/4);
  const rotated=new Vector3(...start).applyQuaternion(new Quaternion().setFromAxisAngle(new Vector3(...axis),Math.PI/2));
  rotated.toArray().forEach((v,i)=>near(v,end[i]));
 }
});
test('plane readout reconstructs the ordered camera orientation; factors do not commute',()=>{
 const y=new Quaternion().setFromAxisAngle(new Vector3(0,1,0),0.4);
 const x=new Quaternion().setFromAxisAngle(new Vector3(1,0,0),-0.3);
 const z=new Quaternion().setFromAxisAngle(new Vector3(0,0,1),0.2);
 const q=y.clone().multiply(x).multiply(z), p=cameraPlaneAngles(q);
 near(p.zx,0.4);near(p.yz,-0.3);near(p.xy,0.2);
 assert.ok(Math.abs(y.clone().multiply(x).dot(x.clone().multiply(y)))<0.9999);
 const forward=new Vector3(0,0,-1).applyQuaternion(y);
 near(forward.x,-Math.sin(0.4));near(forward.z,-Math.cos(0.4));
});
