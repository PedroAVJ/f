import {test,expect} from 'bun:test';
import {mkdtemp,writeFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {QueryGateway} from './gateway.ts';
test('HTTP program authenticates without URI secrets and enforces scoped typed actions',async()=>{
 const dir=await mkdtemp(join(tmpdir(),'hyper-http-'));let saved='',calls=0;
 const server=Bun.serve({port:0,fetch:async(req)=>{
  calls++;if(req.headers.get('x-test-key')!=='fixture')return new Response(null,{status:401});
  if(req.method==='POST'){saved=(await req.json()).text;return Response.json({redirect:new URL('/hypertui?saved=1',req.url).href});}
  return Response.json({version:1,markdown:'# Remote fixture\n\nSaved: '+saved,actions:[{name:'save',description:'Save fixture',href:'/hypertui',inputSchema:{type:'object',properties:{text:{type:'string'}},required:['text'],additionalProperties:false}}]});
 }});
 const origin=server.url.origin,headersFile=join(dir,'headers.json');await writeFile(headersFile,JSON.stringify({'x-test-key':'fixture'}));
 const gateway=new QueryGateway([],dir,'unused','unused',undefined,{remoteOnly:true,mutations:true,httpPrograms:{[origin]:{pathPrefix:'/hypertui',headersFile}}});
 try {
  const uri=origin+'/hypertui',page=await gateway.open(uri);expect(JSON.stringify(page)).not.toContain('x-test-key');
  await expect(gateway.act(uri,'save',{text:3})).rejects.toThrow();expect(calls).toBe(1);
  const result=await gateway.act(uri,'save',{text:'confirmed'});expect(saved).toBe('confirmed');
  const next=JSON.stringify(result).match(/hypertui:\/\/results\/[^>]+/)![0];
  expect(JSON.stringify(await gateway.open(next))).toContain('/hypertui?saved=1');
  expect(JSON.stringify(await gateway.open(origin+'/hypertui?saved=1'))).toContain('Saved: confirmed');
  await expect(gateway.open(origin+'/api/private')).rejects.toThrow('outside');
 }finally{gateway.close();server.stop(true);await rm(dir,{recursive:true,force:true});}
});
