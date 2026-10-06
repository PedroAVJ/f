#!/usr/bin/env node
// Fixed-scope Apple signing operations for the HyperTUI Apple page.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';
import child from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { files as projectFiles } from './project.js';

const here = fileURLToPath(import.meta.url);
const home = os.homedir();
const bundles = ['com.pedroavj.opendot.ios', 'com.pedroavj.opendot.ios.share'];
const group = 'group.com.pedroavj.opendot';
const empty = {type:'object', properties:{}, additionalProperties:false};
const op = {type:'object', properties:{operationId:{type:'string', pattern:'^[a-f0-9]{32}$'}}, required:['operationId'], additionalProperties:false};
export const tools = [
  {name:'apple_signing_status', description:'Inspect local Dot and share-extension signing readiness. Does not contact Apple, provision, build, install, or launch an app.', inputSchema:empty, annotations:{readOnlyHint:true}},
  {name:'apple_share_prepare', description:'Prepare an opaque operation for the fixed Dot App Group and two bundle identifiers. No Apple changes, build, or installation.', inputSchema:empty, annotations:{readOnlyHint:false, destructiveHint:false}},
  {name:'apple_share_provision', description:'Execute a prepared Dot signing operation with the existing local App Store Connect key. If authentication is available, Apple command-line provisioning may create or update the fixed App Group, bundle capabilities, and development profiles. Never signs into Xcode UI or installs/launches an app. Inspect operation status afterward. App Group provisioning is not yet verified for this account.', inputSchema:op, annotations:{readOnlyHint:false, destructiveHint:false}},
  {name:'apple_operation_status', description:'Read the sanitized state of one prepared Apple provisioning operation.', inputSchema:op, annotations:{readOnlyHint:true}},
];
const now = () => new Date().toISOString();
const idValid = id => typeof id === 'string' && /^[a-f0-9]{32}$/.test(id);
const run = (cmd, args, options={}) => child.spawnSync(cmd,args,{encoding:'utf8', timeout:20000, maxBuffer:4*1024*1024,...options});
const pause = ms => new Promise(resolve=>setTimeout(resolve,ms));

// Apple's security cms output is a standard XML property list. No DTD or
// external entity resolution; only the plist value tags below are accepted.
export function plist(xml) {
  const source=xml.replace(/<\?[^>]*\?>/g,'').replace(/<!DOCTYPE[^>]*>/g,'');
  const tokens=source.match(/<[^>]+>|[^<]+/g)||[];
  let i=0;
  const trim=()=>{while(i<tokens.length && /^\s+$/.test(tokens[i]))i++;};
  const unescape=s=>s.replace(/&(?:amp|lt|gt|quot|apos);/g,x=>({'&amp;':'&','&lt;':'<','&gt;':'>','&quot;':'"','&apos;':"'"}[x])).replace(/&#(x[0-9a-f]+|\d+);/gi,(_,n)=>String.fromCodePoint(n[0]==='x'?parseInt(n.slice(1),16):Number(n)));
  function value() {
    trim(); const tag=tokens[i++];
    if(tag==='<true/>')return true;
    if(tag==='<false/>')return false;
    if(tag==='<dict/>')return {};
    if(tag==='<array/>')return [];
    if(tag==='<dict>') {
      const out={}; trim();
      while(tokens[i]!=='</dict>') {
        if(tokens[i]!=='<key>')throw Error('invalid_plist');
        const key=value(); out[key]=value(); trim();
      }
      i++; return out;
    }
    if(tag==='<array>') {
      const out=[];trim();while(tokens[i]!=='</array>'){out.push(value());trim();}i++;return out;
    }
    const m=/^<(key|string|integer|real|data|date)>$/.exec(tag||'');
    if(!m)throw Error('invalid_plist');
    let text='';while(i<tokens.length && tokens[i]!==`</${m[1]}>`)text+=tokens[i++];
    if(i>=tokens.length)throw Error('invalid_plist');i++;
    if(m[1]==='data')return Buffer.from(text.replace(/\s/g,''),'base64');
    if(m[1]==='integer'||m[1]==='real')return Number(text);
    return unescape(text);
  }
  trim();if(!/^<plist\b/.test(tokens[i++]||''))throw Error('invalid_plist');
  const result=value();trim();if(tokens[i++]!=='</plist>')throw Error('invalid_plist');return result;
}

function credentials() {
  const configPath=path.join(home,'.config/dot-apple/credentials.json');
  const config=fs.existsSync(configPath)?JSON.parse(fs.readFileSync(configPath,'utf8')):{};
  let issuer=process.env.ASC_ISSUER_ID||process.env.APP_STORE_CONNECT_ISSUER_ID||config.issuerId;
  if(typeof issuer!=='string'||! /^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(issuer))issuer=null;
  const directory=path.join(home,'.private_keys');
  const keys=fs.existsSync(directory)?fs.readdirSync(directory).filter(x=>/^AuthKey_[A-Z0-9]*Q9XB\.p8$/.test(x)):[];
  const key=keys.length===1?path.join(directory,keys[0]):null;
  return {key,keyId:key?path.basename(key).slice(8,-3):null,issuer};
}

function signingStatus() {
  const identities=run('security',['find-identity','-v','-p','codesigning']).stdout||'';
  const fingerprints=new Set([...identities.matchAll(/\b([A-F0-9]{40})\b[^\n]*Apple Development/g)].map(x=>x[1]));
  const ready=Object.fromEntries(bundles.map(b=>[b,false]));
  const counts=Object.fromEntries(bundles.map(b=>[b,0]));
  let scanned=0,errors=0;
  for(const relative of ['Library/MobileDevice/Provisioning Profiles','Library/Developer/Xcode/UserData/Provisioning Profiles']) {
    const directory=path.join(home,relative);if(!fs.existsSync(directory))continue;
    for(const name of fs.readdirSync(directory).filter(x=>x.endsWith('.mobileprovision'))) {
      scanned++;
      try {
        const response=run('security',['cms','-D','-i',path.join(directory,name)],{timeout:5000});
        if(response.status!==0)throw Error('decode_failed');
        const p=plist(response.stdout),ent=p.Entitlements||{};
        const usable=ent['get-task-allow']&&new Date(p.ExpirationDate)>new Date()&&p.ProvisionedDevices?.length&&(p.DeveloperCertificates||[]).some(c=>fingerprints.has(crypto.createHash('sha1').update(c).digest('hex').toUpperCase()));
        for(const bundle of bundles)if(usable&&ent['application-identifier']?.endsWith('.'+bundle)) {
          counts[bundle]++;
          if(ent['com.apple.security.application-groups']?.includes(group)&&(bundle!==bundles[0]||ent['aps-environment']==='development'))ready[bundle]=true;
        }
      } catch {errors++;}
    }
  }
  const c=credentials();
  return {checkedAt:now(),appGroup:group,bundles:bundles.map(identifier=>({identifier,usableExplicitProfiles:counts[identifier],appGroupProfileReady:ready[identifier]})),shareSigningReady:bundles.every(b=>ready[b]),availableDevelopmentIdentities:fingerprints.size,profilesInspected:scanned,profileDecodeErrors:errors,localApiKeyAvailable:!!c.key,issuerConfigured:!!c.issuer,deviceCoverageVerified:false};
}

export function token(c) {
  const stamp=Math.floor(Date.now()/1000),claims={iat:stamp,exp:stamp+300,aud:'appstoreconnect-v1',...(c.issuer?{iss:c.issuer}:{sub:'user'})};
  const data=[{alg:'ES256',kid:c.keyId,typ:'JWT'},claims].map(x=>Buffer.from(JSON.stringify(x)).toString('base64url')).join('.');
  const key=crypto.createPrivateKey(fs.readFileSync(c.key));
  if(key.asymmetricKeyType!=='ec'||key.asymmetricKeyDetails.namedCurve!=='prime256v1')throw Error('invalid_key');
  const signature=crypto.sign('sha256',Buffer.from(data),{key,dsaEncoding:'ieee-p1363'});
  return data+'.'+signature.toString('base64url');
}

async function apiProbe(c) {
  const response=await fetch('https://api.appstoreconnect.apple.com/v1/certificates?limit=1',{headers:{Authorization:'Bearer '+token(c)},signal:AbortSignal.timeout(20000),redirect:'error'});
  await response.body?.cancel();
  return response.status;
}

export function createOperations(overrides={}) {
  const stateDirectory=overrides.stateDirectory||path.join(home,'Library/Application Support/OpenDot/apple-provisioning');
  const deps={signingStatus,credentials,apiProbe,spawn:child.spawn,...overrides};
  const ensure=()=>{fs.mkdirSync(stateDirectory,{recursive:true,mode:0o700});fs.chmodSync(stateDirectory,0o700);};
  const read=id=>{if(!idValid(id))throw Error('invalid_operation');return JSON.parse(fs.readFileSync(path.join(stateDirectory,id+'.json'),'utf8'));};
  const save=operation=>{
    ensure();const target=path.join(stateDirectory,operation.operationId+'.json'),tmp=target+'.tmp-'+crypto.randomUUID();
    const fd=fs.openSync(tmp,'wx',0o600);try{fs.writeFileSync(fd,JSON.stringify(operation));fs.fsyncSync(fd);}finally{fs.closeSync(fd);}fs.renameSync(tmp,target);
  };
  const finish=(operation,state,code,fields={})=>{Object.assign(operation,{state,code,updatedAt:now()},fields);save(operation);return operation;};
  async function lock(name,work) {
    ensure();const directory=path.join(stateDirectory,name+'.lock');let owned=false;
    for(let attempt=0;attempt<30&&!owned;attempt++) {
      try{fs.mkdirSync(directory,{mode:0o700});fs.writeFileSync(path.join(directory,'pid'),String(process.pid));owned=true;}
      catch(error){
        if(error.code!=='EEXIST')throw error;
        try{const pid=Number(fs.readFileSync(path.join(directory,'pid'),'utf8'));if(pid>0)process.kill(pid,0);}
        catch(stale){if(stale.code==='ESRCH'){fs.rmSync(directory,{recursive:true});continue;}}
        await pause(50);
      }
    }
    if(!owned)throw Error('operation_busy');
    try{return await work();}finally{fs.rmSync(directory,{recursive:true,force:true});}
  }
  async function provision(id) {
    return lock('provision',async()=>{
      const operation=read(id);if(operation.state!=='queued')return operation;
      finish(operation,'running','checking_authentication');
      try {
        const c=deps.credentials();
        if(!c.key)return finish(operation,'blocked','local_api_key_unavailable',{mutationAttempted:false});
        const auth=await deps.apiProbe(c);
        if(auth!==200)return finish(operation,'blocked',!c.issuer&&auth===401?'issuer_missing_and_individual_key_authentication_rejected':'apple_api_authentication_or_permission_rejected',{apiHttpStatus:auth,issuerConfigured:!!c.issuer,mutationAttempted:false});
        if(!c.issuer)return finish(operation,'blocked','team_key_issuer_required_for_command_line_provisioning',{apiHttpStatus:auth,mutationAttempted:false});
        const project=path.join(stateDirectory,'project');
        for(const [name,contents] of Object.entries(projectFiles)){const full=path.join(project,name);fs.mkdirSync(path.dirname(full),{recursive:true});fs.writeFileSync(full,contents);}
        finish(operation,'running','provisioning_fixed_dot_identifiers',{mutationAttempted:true});
        const args=['xcodebuild','-project',path.join(project,'DotShareProvision.xcodeproj'),'-scheme','DotShareProvision','-configuration','Debug','-sdk','iphoneos','-destination','generic/platform=iOS','-derivedDataPath',path.join(stateDirectory,'derived'),'-jobs','1','-allowProvisioningUpdates','-authenticationKeyPath',c.key,'-authenticationKeyID',c.keyId,'-authenticationKeyIssuerID',c.issuer,'build','CODE_SIGN_IDENTITY=Apple Development'];
        const processChild=deps.spawn('xcrun',args,{stdio:'ignore',detached:true});
        let guardCode=null;
        const started=Date.now();
        const guard=setInterval(()=>{
          const output=run('ps',['-axo','pgid=,rss='],{timeout:5000}).stdout||'';
          const rss=output.trim().split('\n').map(row=>row.trim().split(/\s+/)).filter(row=>Number(row[0])===processChild.pid).reduce((sum,row)=>sum+Number(row[1]||0),0);
          if(rss>3800*1024||Date.now()-started>300000){guardCode=rss>3800*1024?'provisioning_resource_limit_reinspect_before_retry':'provisioning_timed_out_reinspect_before_retry';try{process.kill(-processChild.pid,'SIGKILL');}catch{}}
        },500);
        let exitCode;
        try{exitCode=await new Promise((resolve,reject)=>{processChild.once('error',reject);processChild.once('exit',resolve);});}finally{clearInterval(guard);}
        if(guardCode)return finish(operation,'blocked',guardCode);
        const signing=deps.signingStatus();
        return finish(operation,signing.shareSigningReady?'completed':'blocked',signing.shareSigningReady?'profiles_available_device_coverage_requires_verification':'apple_provisioning_did_not_produce_required_profiles',{buildExitCode:exitCode,signing});
      }catch{return finish(operation,'blocked','local_provisioning_error_reinspect_before_retry');}
    }).catch(()=>{
      const operation=read(id);
      return operation.state==='queued'?finish(operation,'blocked','another_provisioning_operation_running'):operation;
    });
  }
  async function call(name,args) {
    if(!tools.some(t=>t.name===name)||!args||typeof args!=='object'||Array.isArray(args))throw Error('invalid_request');
    const needsId=['apple_share_provision','apple_operation_status'].includes(name);
    if(Object.keys(args).length!==(needsId?1:0)||(needsId&&!idValid(args.operationId)))throw Error('invalid_request');
    if(name==='apple_signing_status')return deps.signingStatus();
    if(name==='apple_share_prepare') {
      const operation={operationId:crypto.randomBytes(16).toString('hex'),state:'prepared',createdAt:now(),updatedAt:now(),scope:{appGroup:group,bundleIdentifiers:bundles,install:false},signing:deps.signingStatus(),mutationAttempted:false};save(operation);return operation;
    }
    if(name==='apple_operation_status')return read(args.operationId);
    return lock('submit',async()=>{
      const operation=read(args.operationId);if(operation.state!=='prepared')return operation;
      finish(operation,'queued','authentication_check_queued');
      try{
        const worker=deps.spawn(process.execPath,[here,'--execute',operation.operationId],{stdio:'ignore',detached:true});
        await new Promise((resolve,reject)=>{worker.once('spawn',resolve);worker.once('error',reject);});worker.unref();
      }catch{return finish(operation,'blocked','operation_launch_failed',{mutationAttempted:false});}
      return operation;
    });
  }
  return {call,provision,read,finish};
}

if(process.argv[1]&&path.resolve(process.argv[1])===here) {
  let result;
  try {
    if(process.argv.length===3&&process.argv[2]==='--schemas')result={tools};
    else if(process.argv.length===4&&process.argv[2]==='--execute'){await createOperations().provision(process.argv[3]);process.exit(0);}
    else if(process.argv.length===2){
      const raw=fs.readFileSync(0,'utf8');if(raw.length>65536)throw Error('invalid_request');const request=JSON.parse(raw);
      if(!request||Object.keys(request).sort().join(',')!=='arguments,name')throw Error('invalid_request');
      result={ok:true,result:await createOperations().call(request.name,request.arguments)};
    }else throw Error('invalid_invocation');
  }catch{result={ok:false,error:'invalid_request_or_local_apple_operation_failed'};}
  console.log(JSON.stringify(result));
}
