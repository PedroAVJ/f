import {createInterface} from 'node:readline';
import {readFile} from 'node:fs/promises';
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
 const get=async(origin:string,path:string)=>{
  const url=new URL(origin);if(url.protocol!=='http:'||url.hostname!=='127.0.0.1')throw Error('Local worker origin must be loopback HTTP.');
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
     const registry=await get(config.managerOrigin??'http://127.0.0.1:19456','/workers');let value=registry;
     if(tool.name==='worker_status'){
      const worker=registry.workers.find((w:any)=>w.id===(args.workerId??'original'));if(!worker)throw Error('Worker not found.');
      const health=await get(worker.origin,'/health'),session=await get(worker.origin,'/api/session');
      value={workerId:worker.id,health,selectedThreadId:session.selectedThreadId,threads:(session.threads??[]).map((t:any)=>({id:t.id,title:t.title,status:t.status,turnId:t.turnId,messageCount:t.messages?.length??0}))};
     }
     result={content:[{type:'text',text:JSON.stringify(value)}]};
    }
   }else throw Error('Unknown method.');
   process.stdout.write(JSON.stringify({jsonrpc:'2.0',id:message.id,result})+'\n');
  }catch(error){process.stdout.write(JSON.stringify({jsonrpc:'2.0',id:message?.id??null,error:{code:-32603,message:error instanceof Error?error.message:String(error)}})+'\n');}
 }}finally{backend.close();}
}
