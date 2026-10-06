import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import {EventEmitter} from 'node:events';
import test from 'node:test';
import {createOperations,plist,token,tools} from './main.js';

function fixture(t,extra={}) {
  const directory=fs.mkdtempSync(path.join(os.tmpdir(),'dot-apple-test-'));
  t.after(()=>fs.rmSync(directory,{recursive:true,force:true}));
  let launches=0;
  const operations=createOperations({stateDirectory:directory,signingStatus:()=>({shareSigningReady:false}),credentials:()=>({key:'/fixture/private-path',keyId:'fixture-key',issuer:null}),apiProbe:async()=>401,spawn:()=>{launches++;const worker=new EventEmitter();worker.unref=()=>{};queueMicrotask(()=>worker.emit('spawn'));return worker;},...extra});
  return {operations,directory,launches:()=>launches};
}
test('fixed scope, opaque identity, and private records',async t=>{
  const f=fixture(t),result=await f.operations.call('apple_share_prepare',{});
  assert.match(result.operationId,/^[a-f0-9]{32}$/);
  assert.deepEqual(result.scope.bundleIdentifiers,['com.pedroavj.opendot.ios','com.pedroavj.opendot.ios.share']);
  assert.equal(result.scope.install,false);
  assert.equal(fs.statSync(path.join(f.directory,result.operationId+'.json')).mode&0o777,0o600);
});
test('concurrent exact submits launch one worker',async t=>{
  const f=fixture(t),result=await f.operations.call('apple_share_prepare',{}),args={operationId:result.operationId};
  const results=await Promise.all([f.operations.call('apple_share_provision',args),f.operations.call('apple_share_provision',args)]);
  assert.deepEqual(results[0],results[1]);assert.equal(f.launches(),1);
});
test('rejects path traversal, credential arguments, and scope changes',async t=>{
  const f=fixture(t),result=await f.operations.call('apple_share_prepare',{});
  for(const args of [{operationId:'../x'},{operationId:result.operationId,issuer:'secret'},{operationId:result.operationId,bundleId:'other.app'}])await assert.rejects(f.operations.call('apple_share_provision',args));
  assert.equal(f.launches(),0);
});
test('401 cannot reach Apple mutations and does not reveal credentials',async t=>{
  const f=fixture(t),operation=await f.operations.call('apple_share_prepare',{});
  await f.operations.call('apple_share_provision',{operationId:operation.operationId});
  const result=await f.operations.provision(operation.operationId);
  assert.equal(result.state,'blocked');assert.equal(result.apiHttpStatus,401);assert.equal(result.mutationAttempted,false);assert.equal(f.launches(),1);
  assert.doesNotMatch(JSON.stringify(result),/fixture-key|\/fixture\/private-path/);
});
test('network and signing failures are sanitized',async t=>{
  const f=fixture(t,{apiProbe:async()=>{throw Error('sensitive fixture data');}}),operation=await f.operations.call('apple_share_prepare',{});
  await f.operations.call('apple_share_provision',{operationId:operation.operationId});
  const result=await f.operations.provision(operation.operationId);
  assert.equal(result.state,'blocked');assert.doesNotMatch(JSON.stringify(result),/sensitive fixture data/);
});
test('terminal operations are not submitted again',async t=>{
  const f=fixture(t),operation=await f.operations.call('apple_share_prepare',{});
  f.operations.finish(operation,'blocked','fixture');
  const result=await f.operations.call('apple_share_provision',{operationId:operation.operationId});
  assert.equal(result.state,'blocked');assert.equal(f.launches(),0);
});
test('Apple XML plist decodes data, dates, and escaped text',()=>{
  const parsed=plist('<?xml version="1.0"?><!DOCTYPE plist PUBLIC "plist"><plist version="1.0"><dict><key>cert</key><data>AQID</data><key>expires</key><date>2027-01-01T00:00:00Z</date><key>values</key><array><true/><integer>2</integer><string>A &amp; B</string></array></dict></plist>');
  assert.deepEqual(parsed.cert,Buffer.from([1,2,3]));assert.deepEqual(parsed.values,[true,2,'A & B']);assert.equal(parsed.expires,'2027-01-01T00:00:00Z');
});
test('JWT uses valid P256 P1363 signatures without issuer invention',t=>{
  const f=fixture(t),keys=crypto.generateKeyPairSync('ec',{namedCurve:'prime256v1'}),keyPath=path.join(f.directory,'fixture.p8');
  fs.writeFileSync(keyPath,keys.privateKey.export({format:'pem',type:'pkcs8'}),{mode:0o600});
  const jwt=token({key:keyPath,keyId:'fixture',issuer:null}),parts=jwt.split('.'),claims=JSON.parse(Buffer.from(parts[1],'base64url'));
  assert.equal(claims.sub,'user');assert.equal(claims.iss,undefined);
  assert.equal(crypto.verify('sha256',Buffer.from(parts.slice(0,2).join('.')),{key:keys.publicKey,dsaEncoding:'ieee-p1363'},Buffer.from(parts[2],'base64url')),true);
});
test('schemas expose no credential, command, or path arguments',()=>{
  for(const tool of tools)assert.deepEqual(Object.keys(tool.inputSchema.properties),tool.name==='apple_share_provision'||tool.name==='apple_operation_status'?['operationId']:[]);
});
