import {test,expect} from 'bun:test';
import {mkdtemp,writeFile,readFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {McpQueries} from './backend.ts';

test('worker bridge restores authenticated read tools and forwards original mutations unchanged',async()=>{
 const dir=await mkdtemp(join(tmpdir(),'worker-bridge-'));const requests:{path:string;login:string|null}[]=[];
 const worker=Bun.serve({hostname:'127.0.0.1',port:0,fetch:req=>{const path=new URL(req.url).pathname;requests.push({path,login:req.headers.get('tailscale-user-login')});return Response.json(path==='/health'?{healthy:true}:{selectedThreadId:'thread-fixture',threads:[{id:'thread-fixture',title:'Fixture',status:'working',turnId:'turn-fixture',messages:[{text:'Private content must not appear in status'}]}]});}});
 const manager=Bun.serve({hostname:'127.0.0.1',port:0,fetch:req=>{requests.push({path:new URL(req.url).pathname,login:req.headers.get('tailscale-user-login')});return Response.json({workers:[{id:'original',origin:worker.url.origin,lifecycle:'running'},{id:'outside',origin:'https://example.invalid'}]});}});
 const original=join(dir,'original.mjs'),config=join(dir,'config.json');
 await writeFile(config,JSON.stringify({login:'fixture-login',managerOrigin:manager.url.origin}));
 await writeFile(original,`import {createInterface} from 'node:readline';for await(const line of createInterface({input:process.stdin})){const m=JSON.parse(line);if(m.id===undefined)continue;const result=m.method==='initialize'?{protocolVersion:'2025-06-18',capabilities:{tools:{}},serverInfo:{name:'fixture',version:'1'}}:m.method==='tools/list'?{tools:[{name:'worker_submit',inputSchema:{type:'object'}}]}:{content:[{type:'text',text:JSON.stringify({forwarded:m.params,env:process.env.FIXTURE_BRIDGE_ENV})}]};process.stdout.write(JSON.stringify({jsonrpc:'2.0',id:m.id,result})+'\\n');}`);
 const binding={command:process.execPath,args:[original,config],cwd:dir,env:{FIXTURE_BRIDGE_ENV:'retained'}};
 const bridge=new McpQueries(process.execPath,[join(import.meta.dir,'worker-tools.ts'),JSON.stringify(binding)],dir);
 try{
  const tools=(await bridge.listTools()).tools;expect(tools.map((x:any)=>x.name)).toEqual(['worker_submit','worker_list','worker_status']);
  const list=await bridge.call('worker_list',{});expect(JSON.parse(list.content[0].text).workers.length).toBe(2);
  const status=JSON.parse((await bridge.call('worker_status',{})).content[0].text);expect(status.health.healthy).toBe(true);expect(status.threads[0].messageCount).toBe(1);expect(JSON.stringify(status)).not.toContain('Private content');
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
