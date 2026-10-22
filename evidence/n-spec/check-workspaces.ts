import {readFileSync,writeFileSync} from 'node:fs';
import {homedir} from 'node:os';
import {createHash,randomUUID,sign} from 'node:crypto';
const base=homedir()+'/Library/Application Support/';
const config=JSON.parse(readFileSync(base+'HyperTUI/runtime.json','utf8'));
const origin='http://127.0.0.1:17693';
const identity=config.identities.find((x:any)=>x.origin===origin);
const results=[];
for(const id of ['aff08f07-9122-4958-afb8-f480c9c84d85','d2906914-375f-42b1-8e14-261ebbf6529e']){
 const address=origin+'/n?ws='+encodeURIComponent(origin+'/workspaces/'+id);
 const at=new Date().toISOString(),nonce=randomUUID();
 const payload=`HyperTUI/1\nGET\n${address}\n${at}\n${nonce}\n${createHash('sha256').update('').digest('hex')}`;
 const res=await fetch(address,{headers:{'x-hypertui-key':identity.keyId,'x-hypertui-time':at,'x-hypertui-nonce':nonce,'x-hypertui-signature':sign(null,Buffer.from(payload),readFileSync(identity.keyPath)).toString('base64url')}});
 const body=await res.json();
 results.push({id,status:res.status,error:body.error,actions:body.actions?.map((x:any)=>x.name),preview:body.markdown?.slice(0,400)});
}
console.log(JSON.stringify(results,null,2));
writeFileSync(import.meta.dir+'/workspace-http.json',JSON.stringify(results,null,2));
