import {test,expect} from 'bun:test';
import {mkdtemp,writeFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {QueryGateway} from './gateway.ts';
import {RpcProcess} from './backend.ts';

const markdown='# Remote page\n\n[Repository](<https://example.test/repos/one>)\n\nA single body.';
const schema={type:'object',properties:{title:{type:'string',minLength:2,maxLength:12},mode:{type:'string',enum:['draft','ready']}},required:['title','mode'],additionalProperties:false};
async function fixture(){
 const root=await mkdtemp(join(tmpdir(),'hyper-compact-'));
 const path=join(root,'provider.ts');
 await writeFile(path,`import {createInterface} from 'node:readline';
let generation=0;
for await(const line of createInterface({input:process.stdin})){
 const m=JSON.parse(line);if(m.id===undefined)continue;let result;
 if(m.method==='initialize')result={protocolVersion:'2025-06-18',capabilities:{tools:{listChanged:true}},serverInfo:{name:'fixture',version:'1'}};
 else if(m.method==='tools/list')result={tools:[{name:'hyperTUI',inputSchema:{type:'object'}},...(generation?[{name:'p'+generation+'_rename',description:'Rename the current repository.',inputSchema:${JSON.stringify(schema)}}]:[])]};
 else if(m.method==='tools/call'){
  if(m.params.name!=='hyperTUI'&&m.params.name!=='p'+generation+'_rename')throw Error('Stale upstream action');
  generation++;
  const markdown=${JSON.stringify(markdown)};
  result={content:[{type:'text',text:markdown},{type:'image',mimeType:'image/png',data:'aGVsbG8='}],structuredContent:{markdown,uri:'https://example.test/repos',generation,other:'keep this'}};
 }else result={};
 process.stdout.write(JSON.stringify({jsonrpc:'2.0',id:m.id,result})+'\\n');
}`);
 return{root,remote:{command:process.execPath,args:[path]}};
}

test('compact remote pages preserve Markdown, images and nonduplicate metadata once',async()=>{
 const f=await fixture();const gateway=new QueryGateway([],f.root,'unused','unused',undefined,{remote:f.remote,mutations:true,compact:true});
 try{
  const page=await gateway.open('https://example.test/repos');
  expect(page.content[0]).toEqual({type:'text',text:markdown});
  expect(page.content[1]).toEqual({type:'image',mimeType:'image/png',data:'aGVsbG8='});
  expect(page.structuredContent).toEqual({uri:'https://example.test/repos',generation:1,other:'keep this'});
  const text=page.content.filter(v=>v.type==='text').map(v=>v.text).join('\n');
  expect(text.split('A single body.').length-1).toBe(1);
  expect(text.split('[Repository]').length-1).toBe(1);
  expect(text).not.toContain('```');expect(text).not.toContain('inputSchema');
  expect(text).toContain('rename(title: string, mode: "draft"|"ready")');
  const first=gateway.actionTools()[0];expect(first.inputSchema).toEqual(schema);
  await expect(gateway.callActionTool(first.name,{title:'x',mode:'draft'})).rejects.toThrow();
  await gateway.open('https://example.test/repos');
  await expect(gateway.callActionTool(first.name,{title:'valid',mode:'draft'})).rejects.toThrow('Stale');
  const next=gateway.actionTools()[0];const changed=await gateway.callActionTool(next.name,{title:'valid',mode:'ready'});
  expect(gateway.actionTools()).toEqual([]);
  await expect(gateway.callActionTool(next.name,{title:'valid',mode:'ready'})).rejects.toThrow('Stale');
  const redirect=changed.content[0].text.match(/<(hypertui:[^>]+)>/)![1];
  expect((await gateway.open(redirect)).content[0]).toEqual({type:'text',text:markdown});
 }finally{gateway.close();await rm(f.root,{recursive:true,force:true});}
});

test('conversation wrapper exposes exact typed schemas but never appends them to page results',async()=>{
 const f=await fixture();const catalog=join(f.root,'catalog.json'),config=join(f.root,'config.json'),session=join(f.root,'session.json');
 await writeFile(catalog,JSON.stringify({tools:[]}));await writeFile(session,JSON.stringify({selectedThreadId:'a',threads:[{id:'a',messages:[{role:'user',text:'retained fixture'}]}]}));
 await writeFile(config,JSON.stringify({catalog,workspace:f.root,codex:'unused',claude:'unused',mutations:true,remoteOnly:true,remote:f.remote,sessionFile:session}));
 const rpc=new RpcProcess(process.execPath,[join(import.meta.dir,'conversation-gateway.ts'),config]);
 try{
  const init=await rpc.call('initialize',{});expect(init.capabilities.tools.listChanged).toBe(true);
  const initial=await rpc.call('tools/list',{});expect(initial.tools.map((t:any)=>t.name)).toEqual(['hyperTUI','hyperTUI_action']);
  const page=await rpc.call('tools/call',{name:'hyperTUI',arguments:{uri:'https://example.test/repos'}});
  expect(JSON.stringify(page)).not.toContain('inputSchema');expect(page.content[0].text).toBe(markdown);
  const listed=await rpc.call('tools/list',{}),tool=listed.tools.find((t:any)=>t.name==='p1_rename');expect(tool.inputSchema).toEqual(schema);
  const bad=await rpc.call('tools/call',{name:tool.name,arguments:{title:'x',mode:'draft'}});expect(bad.isError).toBe(true);
  const good=await rpc.call('tools/call',{name:'hyperTUI_action',arguments:{uri:'https://example.test/repos',name:'rename',arguments:{title:'valid',mode:'draft'}}});expect(good.isError).toBeUndefined();
  expect((await rpc.call('tools/list',{})).tools.map((t:any)=>t.name)).toEqual(['hyperTUI','hyperTUI_action']);
  const stale=await rpc.call('tools/call',{name:tool.name,arguments:{title:'valid',mode:'draft'}});expect(stale.isError).toBe(true);
  await rpc.call('tools/call',{name:'hyperTUI',arguments:{uri:'https://example.test/repos'}});
  const archived=await rpc.call('tools/call',{name:'hyperTUI',arguments:{uri:'hypertui://conversation/?q=retained'}});
  expect(JSON.parse(archived.content[0].text)).toEqual({contextOnly:true,messages:[{index:0,role:'user',text:'retained fixture',excerpt:false}],nextBefore:0});
  expect((await rpc.call('tools/list',{})).tools).toHaveLength(2);
  const excluded=await rpc.call('tools/call',{name:'hyperTUI',arguments:{uri:'hypertui://files/config.json'}});
  expect(excluded.isError).toBe(true);expect(excluded.content[0].text).toContain('ordinary local tools');
  const requests=[{id:1,method:'initialize',params:{}},{id:2,method:'tools/call',params:{name:'hyperTUI',arguments:{uri:'https://example.test/repos'}}},{id:3,method:'tools/list',params:{}}];
  const child=Bun.spawn([Bun.which('bun')!,join(import.meta.dir,'conversation-gateway.ts'),config],{stdin:new Blob([requests.map(request=>JSON.stringify({jsonrpc:'2.0',...request})).join('\n')+'\n']),stdout:'pipe',stderr:'pipe'});
  const output=(await new Response(child.stdout).text()).trim().split('\n').map(line=>JSON.parse(line));
  expect(await child.exited).toBe(0);
  expect(output.map(message=>message.method??message.id)).toEqual([1,2,'notifications/tools/list_changed',3]);
  expect(output.at(-1).result.tools.find((tool:any)=>tool.name==='p1_rename').inputSchema).toEqual(schema);
 }finally{rpc.close();await rm(f.root,{recursive:true,force:true});}
});

test('conversation wrapper preserves presenter discovery and forwards its arguments unchanged',async()=>{
 const root=await mkdtemp(join(tmpdir(),'hyper-presenter-'));
 const presenter=join(root,'presenter.ts'),catalog=join(root,'catalog.json'),config=join(root,'config.json');
 const uiTool={name:'present_ui',description:'Present fixture UI',inputSchema:{type:'object',properties:{title:{type:'string'}},required:['title']}};
 await writeFile(presenter,`import {createInterface} from 'node:readline';for await(const line of createInterface({input:process.stdin})){const m=JSON.parse(line);if(m.id===undefined)continue;const result=m.method==='initialize'?{protocolVersion:'2025-06-18',capabilities:{tools:{}},serverInfo:{name:'fixture',version:'1'}}:m.method==='tools/list'?{tools:[${JSON.stringify(uiTool)}]}:{content:[{type:'text',text:JSON.stringify(m.params)}]};process.stdout.write(JSON.stringify({jsonrpc:'2.0',id:m.id,result})+'\\n');}`);
 await writeFile(catalog,JSON.stringify({tools:[]}));
 await writeFile(config,JSON.stringify({catalog,workspace:root,codex:'unused',claude:'unused',mutations:true,presenter:{command:process.execPath,args:[presenter]}}));
 const rpc=new RpcProcess(process.execPath,[join(import.meta.dir,'conversation-gateway.ts'),config]);
 try{
  await rpc.call('initialize',{});expect((await rpc.call('tools/list',{})).tools.at(-1)).toEqual(uiTool);
  const result=await rpc.call('tools/call',{name:'present_ui',arguments:{title:'Fixture'}});
  expect(JSON.parse(result.content[0].text)).toEqual({name:'present_ui',arguments:{title:'Fixture'}});
 }finally{rpc.close();await rm(root,{recursive:true,force:true});}
});
