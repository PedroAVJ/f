import {createInterface} from 'node:readline';
import {readFile} from 'node:fs/promises';
import {spawn} from 'node:child_process';
import {checkSchema,validate} from './schema.ts';

// The schema file and command are operator configuration, never page arguments.
const [schemaFile,command,...args]=process.argv.slice(2);
if(!schemaFile||!command)throw Error('Usage: json-cli.ts SCHEMAS.json COMMAND [ARGS]');
const {tools}=JSON.parse(await readFile(schemaFile,'utf8'));
for(const tool of tools)checkSchema(tool.inputSchema);
const invoke=(name:string,arguments_:unknown)=>new Promise<any>((resolve,reject)=>{
  const child=spawn(command,args,{stdio:['pipe','pipe','pipe']});let stdout='',size=0;
  const timer=setTimeout(()=>{child.kill();reject(Error('Program operation timed out; inspect status before retrying.'));},60000);
  child.stdout.on('data',chunk=>{size+=chunk.length;if(size>4*1024*1024){child.kill();reject(Error('Program output exceeds 4 MiB.'));}else stdout+=chunk;});
  // Stderr may contain private backend diagnostics; only its sanitized JSON result is public.
  child.stderr.on('data',()=>{});
  child.on('error',error=>{clearTimeout(timer);reject(error);});
  child.on('close',code=>{clearTimeout(timer);if(code!==0){reject(Error('Program process exited with code '+code+'.'));return;}try{resolve(JSON.parse(stdout));}catch{reject(Error('Program returned invalid JSON.'));}});
  child.stdin.end(JSON.stringify({name,arguments:arguments_}));
});
for await(const line of createInterface({input:process.stdin,crlfDelay:Infinity})) {
  let message:any;
  try {
    if(Buffer.byteLength(line)>2*1024*1024)throw Error('Request exceeds 2 MiB.');
    message=JSON.parse(line);if(message.id===undefined)continue;
    let result:any;
    if(message.method==='initialize')result={protocolVersion:'2025-06-18',capabilities:{tools:{}},serverInfo:{name:'Scoped JSON program',version:'0.1.0'}};
    else if(message.method==='tools/list')result={tools};
    else if(message.method==='ping')result={};
    else if(message.method==='tools/call') {
      const tool=tools.find((tool:any)=>tool.name===message.params?.name);if(!tool)throw Error('Unknown program operation.');
      validate(tool.inputSchema,message.params.arguments??{});
      const output=await invoke(tool.name,message.params.arguments??{});
      result={content:[{type:'text',text:JSON.stringify(output)}],...(output.ok===false?{isError:true}:{})};
    }else throw Error('Unknown method.');
    process.stdout.write(JSON.stringify({jsonrpc:'2.0',id:message.id,result})+'\n');
  }catch(error){process.stdout.write(JSON.stringify({jsonrpc:'2.0',id:message?.id??null,error:{code:-32603,message:error instanceof Error?error.message:String(error)}})+'\n');}
}
