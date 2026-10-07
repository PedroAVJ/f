import {test,expect} from 'bun:test';
import {mkdtemp,writeFile,readFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createHash} from 'node:crypto';
import {McpQueries} from './backend.ts';

test('worker bridge restores authenticated read tools and forwards original mutations unchanged',async()=>{
 const dir=await mkdtemp(join(tmpdir(),'worker-bridge-'));const requests:{path:string;login:string|null}[]=[];
 const frontFile=join(dir,'front.json'),workerFile=join(dir,'worker.json'),factsFile=join(dir,'facts.json');
 const requestId='front-fixture',receiptId=(workerId='original')=>'claude-front:'+createHash('sha256').update(requestId+(workerId==='original'?'':'\nworker:'+workerId)).digest('hex');
 const front={version:1,selectedThreadId:'front-thread',threads:[{id:'front-thread',messages:[]}],requests:[{id:requestId,threadId:'front-thread',provider:'codex',speaker:true,phase:'completed'}]};
 const lastText='discarded prefix'+String.fromCodePoint(0x10400).repeat(4000);
 const messages=[{role:'assistant',text:'Older excluded message one'},{role:'user',text:'Older excluded message two'},...Array.from({length:7},(_,i)=>({role:'assistant',text:'Recent '+i})),{role:'assistant',provider:'claude',text:lastText}];
 const facts={camera:{status:'verified',evidence:'fixture-only'}};
 await writeFile(frontFile,JSON.stringify(front));
 await writeFile(workerFile,JSON.stringify({version:1,selectedThreadId:'thread-fixture',threads:[{id:'thread-fixture',status:'working',messages}],requests:['original','second'].map(id=>({id:receiptId(id),phase:'completed'}))}));
 await writeFile(factsFile,JSON.stringify(facts));
 let healthStatus=200;
 const worker=Bun.serve({hostname:'127.0.0.1',port:0,fetch:req=>{const path=new URL(req.url).pathname;requests.push({path,login:req.headers.get('tailscale-user-login')});return path==='/health'?Response.json({status:'ok',provider:'codex'},{status:healthStatus}):new Response('Session must be read from its registered file.',{status:500});}});
 const manager=Bun.serve({hostname:'127.0.0.1',port:0,fetch:req=>{requests.push({path:new URL(req.url).pathname,login:req.headers.get('tailscale-user-login')});return Response.json({workers:[...['original','second'].map(id=>({id,origin:worker.url.origin,sessionFile:workerFile,workspace:dir,lifecycle:'running'})),{id:'outside',origin:'https://example.invalid'}]});}});
 const original=join(dir,'original.mjs'),config=join(dir,'config.json');
 await writeFile(config,JSON.stringify({login:'fixture-login',managerOrigin:manager.url.origin,sessionFile:frontFile,workerFile,factsFile,requestId}));
 await writeFile(original,`import {createInterface} from 'node:readline';for await(const line of createInterface({input:process.stdin})){const m=JSON.parse(line);if(m.id===undefined)continue;const result=m.method==='initialize'?{protocolVersion:'2025-06-18',capabilities:{tools:{}},serverInfo:{name:'fixture',version:'1'}}:m.method==='tools/list'?{tools:[{name:'worker_submit',inputSchema:{type:'object'}}]}:{content:[{type:'text',text:JSON.stringify({forwarded:m.params,env:process.env.FIXTURE_BRIDGE_ENV})}]};process.stdout.write(JSON.stringify({jsonrpc:'2.0',id:m.id,result})+'\\n');}`);
 const binding={command:process.execPath,args:[original,config],cwd:dir,env:{FIXTURE_BRIDGE_ENV:'retained'}};
 const bridge=new McpQueries(process.execPath,[join(import.meta.dir,'worker-tools.ts'),JSON.stringify(binding)],dir);
 try{
  const tools=(await bridge.listTools()).tools;expect(tools.map((x:any)=>x.name)).toEqual(['worker_submit','worker_list','worker_status']);
  const list=await bridge.call('worker_list',{});expect(JSON.parse(list.content[0].text).workers.length).toBe(3);
  const status=JSON.parse((await bridge.call('worker_status',{})).content[0].text);
  expect(status).toMatchObject({workerId:'original',workspace:dir,live:true,provider:'codex',status:'working',contextOnly:true,currentRequest:{id:receiptId(),phase:'completed'},verifiedFacts:facts});
  expect(status.statusScope).toBe('Global worker activity, not the delivery status or prerequisites of any individual feature.');
  expect(status.messages).toHaveLength(8);expect(JSON.stringify(status)).not.toContain('Older excluded');
  expect(status.messages[0]).toEqual({role:'assistant',provider:'codex',text:'Recent 0'});
  expect(status.messages[7]).toEqual({role:'assistant',provider:'claude',text:Array.from(lastText).slice(-4000).join('')});expect(Array.from(status.messages[7].text)).toHaveLength(4000);
  const second=JSON.parse((await bridge.call('worker_status',{workerId:'second'})).content[0].text);expect(second.currentRequest).toEqual({id:receiptId('second'),phase:'completed'});
  await writeFile(factsFile,'not json');const malformedFacts=JSON.parse((await bridge.call('worker_status',{})).content[0].text);expect(malformedFacts).not.toHaveProperty('verifiedFacts');
  await rm(factsFile);const withoutFacts=JSON.parse((await bridge.call('worker_status',{})).content[0].text);expect(withoutFacts).not.toHaveProperty('verifiedFacts');
  for(const invalid of [{...front,version:2},{...front,selectedThreadId:'missing'},{...front,requests:[]},{...front,requests:[{...front.requests[0],threadId:'wrong-thread'}]},{...front,requests:[{...front.requests[0],speaker:false}]}]){
   await writeFile(frontFile,JSON.stringify(invalid));const beforeGate=requests.length;await expect(bridge.call('worker_list',{})).rejects.toThrow();await expect(bridge.call('worker_status',{})).rejects.toThrow();expect(requests.length).toBe(beforeGate);
  }
  await writeFile(frontFile,JSON.stringify({...front,requests:[{...front.requests[0],provider:'claude',speaker:false}]}));expect(JSON.parse((await bridge.call('worker_list',{})).content[0].text).workers).toHaveLength(3);
  await writeFile(frontFile,JSON.stringify(front));
  healthStatus=503;const unavailable=JSON.parse((await bridge.call('worker_status',{})).content[0].text);expect(unavailable).toEqual({workerId:'original',live:false,status:'unavailable',error:'The selected worker did not pass its live health check. No task was submitted or replayed.'});healthStatus=200;
  expect(requests.every(x=>x.login==='fixture-login')).toBe(true);
  const before=requests.length;await expect(bridge.call('worker_status',{workerId:'../escape'})).rejects.toThrow();expect(requests.length).toBe(before);
  await expect(bridge.call('worker_status',{workerId:'outside'})).rejects.toThrow('loopback HTTP');
  const args={workerId:'fixture',assignment:'Mock only; no worker execution'};
  const forwarded=JSON.parse((await bridge.call('worker_submit',args)).content[0].text);expect(forwarded).toEqual({forwarded:{name:'worker_submit',arguments:args},env:'retained'});
 }finally{bridge.close();worker.stop(true);manager.stop(true);await rm(dir,{recursive:true,force:true});}
});

test('Codex launch wraps only the migration binding while retaining env and unrelated flags',async()=>{
 const dir=await mkdtemp(join(tmpdir(),'worker-codex-'));const output=join(dir,'argv.json'),binary=join(dir,'capture'),catalog=join(dir,'catalog.json');
 try{
  await writeFile(catalog,'{"tools":[]}');
  await writeFile(binary,'#!/opt/homebrew/bin/bun\nimport {writeFile} from "node:fs/promises";const a=process.argv.slice(2);if(a[0]==="mcp"){console.log("[]");process.exit(0)}await writeFile('+JSON.stringify(output)+',JSON.stringify(a));',{mode:0o700});
  const config={catalog,workspace:dir,codex:binary,claude:binary,mutations:false};
  for(const migrated of [true,false]){
   const enabled=migrated?'["worker_start", "worker_submit", "worker_stop", "present_ui"]':'["present_ui"]';
   const binding='mcp_servers.codex_worker={command = "original-binary", args = ["server","config.json"], env = {DOT_ALLOWED_TAILSCALE_LOGIN = "fixture"}, enabled = true, enabled_tools = '+enabled+', startup_timeout_sec = 60, tool_timeout_sec = 150}';
   const child=Bun.spawn([process.execPath,join(import.meta.dir,'launch.ts'),JSON.stringify(config),'codex',binary,'app-server','--stdio','-c',binding,'-c','mcp_servers.unrelated.enabled=false'],{stdout:'pipe',stderr:'pipe'});
   expect(await child.exited).toBe(0);const args:string[]=JSON.parse(await readFile(output,'utf8'));const actual=args.find(x=>x.startsWith('mcp_servers.codex_worker='))!;
   expect(actual.includes('worker-tools.ts')).toBe(migrated);expect(actual.includes('"worker_list"')).toBe(migrated);expect(actual).toContain('env = {DOT_ALLOWED_TAILSCALE_LOGIN = "fixture"}');expect(args).toContain('mcp_servers.unrelated.enabled=false');if(!migrated)expect(actual).toBe(binding);
  }
 }finally{await rm(dir,{recursive:true,force:true});}
});
