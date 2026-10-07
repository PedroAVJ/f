import {createInterface} from 'node:readline';
import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {McpQueries} from './backend.ts';
import {validate} from './schema.ts';
import type {Binding} from './gateway.ts';

// Restore the migration's two removed read tools; existing mutations stay in the
// original worker server, including its accepted-request and ownership gates.
export const workerReadTools=[
 {name:'worker_list',description:'List local independent workers. Registry lifecycle is not live task status.',inputSchema:{type:'object',properties:{},additionalProperties:false},annotations:{readOnlyHint:true}},
 {name:'worker_status',description:'Read current local worker health and saved task status.',inputSchema:{type:'object',properties:{workerId:{type:'string',pattern:'^[A-Za-z0-9_-]{1,40}$'}},additionalProperties:false},annotations:{readOnlyHint:true}},
];
if(import.meta.main){
 const binding:Binding=JSON.parse(process.argv[2]);
 const file=binding.args.at(-1)==='--development'?binding.args.at(-2)!:binding.args.at(-1)!;
 const config=JSON.parse(await readFile(file,'utf8'));
 const backend=new McpQueries(binding.command,binding.args,binding.cwd,binding.env);
 const localOrigin=(origin:string)=>{const url=new URL(origin);if(url.protocol!=='http:'||url.hostname!=='127.0.0.1')throw Error('Local worker origin must be loopback HTTP.');return url;};
 const get=async(origin:string,path:string)=>{
  const url=localOrigin(origin);
  const response=await fetch(new URL(path,url),{headers:{'tailscale-user-login':config.login},redirect:'error',signal:AbortSignal.timeout(15000)});
  if(!response.ok)throw Error('Worker returned HTTP '+response.status);return response.json();
 };
 try{for await(const line of createInterface({input:process.stdin,crlfDelay:Infinity})){
  let message:any;try{
   message=JSON.parse(line);if(message.id===undefined)continue;let result;
   if(message.method==='initialize')result={protocolVersion:'2025-06-18',capabilities:{tools:{}},serverInfo:{name:'Open Dot local workers',version:'1'}};
   else if(message.method==='ping')result={};
   else if(message.method==='tools/list'){const original=await backend.listTools();result={tools:[...original.tools,...workerReadTools.filter(t=>!original.tools.some((x:any)=>x.name===t.name))]};}
   else if(message.method==='tools/call'){
    const tool=workerReadTools.find(t=>t.name===message.params?.name);
    if(!tool)result=await backend.call(message.params.name,message.params.arguments??{});
    else{
     const args=message.params.arguments??{};validate(tool.inputSchema,args);
     const front=JSON.parse(await readFile(config.sessionFile,'utf8'));
     const receipt=front.requests?.find((r:any)=>r.id===config.requestId);
     if(front.version!==1||!front.threads?.some((t:any)=>t.id===front.selectedThreadId)||receipt?.threadId!==front.selectedThreadId||!(receipt.provider==='claude'||receipt.provider==='codex'&&receipt.speaker===true))throw Error('This speaker request is not available.');
     const registry=await get(config.managerOrigin??'http://127.0.0.1:19456','/workers');let value=registry;
     if(tool.name==='worker_status'){
      const worker=registry.workers.find((w:any)=>w.id===(args.workerId??'original'));if(!worker)throw Error('Worker not found.');
      const origin=localOrigin(worker.origin).origin;
      const health=await get(origin,'/health').catch(()=>null);
      if(!health){result={content:[{type:'text',text:JSON.stringify({workerId:worker.id,live:false,status:'unavailable',error:'The selected worker did not pass its live health check. No task was submitted or replayed.'})}]};process.stdout.write(JSON.stringify({jsonrpc:'2.0',id:message.id,result})+'\n');continue;}
      const session=JSON.parse(await readFile(worker.sessionFile,'utf8'));
      const thread=session.threads?.find((t:any)=>t.id===session.selectedThreadId);if(!thread)throw Error('Saved worker conversation is unavailable.');
      const requestId='claude-front:'+createHash('sha256').update(config.requestId+(worker.id==='original'?'':'\nworker:'+worker.id)).digest('hex');
      const current=session.requests?.find((r:any)=>r.id===requestId);
      value={workerId:worker.id,workspace:worker.workspace,live:health.status==='ok',provider:health.provider,status:thread.status,statusScope:'Global worker activity, not the delivery status or prerequisites of any individual feature.',contextOnly:true,messages:(thread.messages??[]).slice(-8).map((m:any)=>({role:m.role,provider:m.provider??'codex',text:Array.from(m.text??'').slice(-4000).join('')})),...(current?{currentRequest:{id:current.id,phase:current.phase}}:{})};
      if(config.factsFile){try{const facts=JSON.parse(await readFile(config.factsFile,'utf8'));if(facts&&typeof facts==='object'&&!Array.isArray(facts))value.verifiedFacts=facts;}catch(error){if((error as NodeJS.ErrnoException).code!=='ENOENT'&&!(error instanceof SyntaxError))throw error;}}
     }
     result={content:[{type:'text',text:JSON.stringify(value)}]};
    }
   }else throw Error('Unknown method.');
   process.stdout.write(JSON.stringify({jsonrpc:'2.0',id:message.id,result})+'\n');
  }catch(error){process.stdout.write(JSON.stringify({jsonrpc:'2.0',id:message?.id??null,error:{code:-32603,message:error instanceof Error?error.message:String(error)}})+'\n');}
 }}finally{backend.close();}
}
