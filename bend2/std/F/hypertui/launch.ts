import {spawn,execFileSync} from 'node:child_process';
import {readFile,mkdtemp,writeFile,rm} from 'node:fs/promises';
import {join,dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {fileURLToPath} from 'node:url';
import {codexPolicy,claudePolicy,toml,localWorkerTools,restorePrompt,restoreCodexArgs,restoreCodexPrompt} from './policy.ts';
import type {GatewayConfig,Binding} from './gateway.ts';

function configFromCodexArgs(args:string[]):Binding|undefined {
  for(const arg of args){
    const match=arg.match(/^mcp_servers\.hypertui=\{command = ("(?:[^"\\]|\\.)*"), args = (\[.*\]), enabled = true, startup_timeout_sec = 60, tool_timeout_sec = 150\}$/s);
    if(match)return {command:JSON.parse(match[1]),args:JSON.parse(match[2])};
  }
}

function workerBinding(binding:Binding):Binding {
  return {command:process.execPath,args:[join(dirname(fileURLToPath(import.meta.url)),'worker-tools.ts'),JSON.stringify(binding)]};
}
function codexWorkerBinding(args:string[]):string[]{
 return restoreCodexArgs(args).map((arg,index)=>{
  if(arg===args[index]||!arg.startsWith('mcp_servers.codex_worker='))return arg;
  const match=arg.match(/^mcp_servers\.codex_worker=\{command = ("(?:[^"\\]|\\.)*"), args = (\[.*?\]), env = /s);
  if(!match)throw Error('Cannot restore the known worker binding; configuration format changed.');
  const binding=workerBinding({command:JSON.parse(match[1]),args:JSON.parse(match[2])});
  return arg.replace(match[0],'mcp_servers.codex_worker={command = '+JSON.stringify(binding.command)+', args = '+JSON.stringify(binding.args)+', env = ');
 });
}

export async function launch(config:GatewayConfig,harness:string,binary:string,args:string[]) {
  const catalog=JSON.parse(await readFile(config.catalog,'utf8'));
  config={...config,remoteOnly:true,mutations:config.mutations??true};
  const directory=await mkdtemp(join(tmpdir(),'f-query-harness-'));
  try {
    const gatewayConfig=join(directory,'gateway.json');
    const server={command:process.execPath,args:[join(dirname(fileURLToPath(import.meta.url)),'gateway.ts'),gatewayConfig]};
    let filtered:string[];
    if(harness==='codex') {
      const servers=JSON.parse(execFileSync(binary,['mcp','list','--json'],{cwd:config.workspace,encoding:'utf8',timeout:30000,maxBuffer:4*1024*1024}));
      filtered=codexWorkerBinding(args);
      const insert=filtered.findIndex(arg=>arg==='app-server'||arg==='exec')+1;
      filtered.splice(insert,0,...codexPolicy(catalog.tools,servers),'-c','mcp_servers.hyper_queries='+toml({...server,enabled:true,startup_timeout_sec:60,tool_timeout_sec:150}));
      config.remote??=configFromCodexArgs(args);
    } else if(harness==='claude') {
      filtered=[...args];
      const index=filtered.indexOf('--mcp-config');
      const existing:{mcpServers?:Record<string,Binding>}=index>=0?JSON.parse(filtered[index+1]):{mcpServers:{}};
      const servers=existing.mcpServers??{};
      config.worker??=servers.codex_worker;
      config.remote??=servers.hypertui;
      const native={mcpServers:{...servers,hyper_queries:server}};
      if(index>=0)filtered[index+1]=JSON.stringify(native);
      else filtered.push('--mcp-config',JSON.stringify(native));
      const allowed=filtered.indexOf('--allowedTools');
      const promptIndex=filtered.indexOf('--append-system-prompt');
      const migratedWorkers=allowed>=0&&filtered[allowed+1]==='mcp__codex_worker__present_ui'&&promptIndex>=0&&filtered[promptIndex+1].includes('Use hyper_queries.hyperTUI(uri), starting at hypertui://programs/,');
      if(servers.codex_worker&&migratedWorkers){native.mcpServers.codex_worker=workerBinding(servers.codex_worker);filtered[filtered.indexOf('--mcp-config')+1]=JSON.stringify(native);}
      const tools=['mcp__hyper_queries__hyperTUI',...(config.mutations?['mcp__hyper_queries__hyperTUI_action']:[]),...(servers.codex_worker&&migratedWorkers?localWorkerTools:[])];
      if(allowed>=0)filtered[allowed+1]=Array.from(new Set([...filtered[allowed+1].split(','),...tools].filter(Boolean))).join(',');else filtered.push('--allowedTools',tools.join(','));
      const prompt=filtered.indexOf('--append-system-prompt');
      if(prompt>=0)filtered[prompt+1]=restorePrompt(filtered[prompt+1]);else filtered.push('--append-system-prompt',restorePrompt(''));
      const addedDenials=claudePolicy(catalog.tools);
      const denied=filtered.indexOf('--disallowedTools');
      if(addedDenials.length){if(denied>=0)filtered[denied+1]+=(filtered[denied+1]?',':'')+addedDenials[1];else filtered.push(...addedDenials);}
    } else throw Error('Expected codex or claude harness.');
    await writeFile(gatewayConfig,JSON.stringify(config),{mode:0o600});
    const transformInput=harness==='codex'&&args.includes('exec')&&args.at(-1)==='-';
    const child=spawn(binary,filtered,{cwd:config.workspace,stdio:transformInput?['pipe','inherit','inherit']:'inherit'});
    const forward=(signal:NodeJS.Signals)=>child.kill(signal);
    const interrupt=()=>forward('SIGINT'),terminate=()=>forward('SIGTERM');
    process.on('SIGINT',interrupt);process.on('SIGTERM',terminate);
    try {
      const completion=new Promise<number>((resolve,reject)=>{child.on('error',reject);child.on('exit',code=>resolve(code??1));});
      if(transformInput){let input='';for await(const chunk of process.stdin)input+=chunk;child.stdin!.end(restoreCodexPrompt(input));}
      process.exitCode=await completion;
    } finally {process.off('SIGINT',interrupt);process.off('SIGTERM',terminate);}
  } finally {await rm(directory,{recursive:true,force:true});}
}
if(import.meta.main) {
  const [raw,harness,binary,...args]=process.argv.slice(2);
  await launch(JSON.parse(raw),harness,binary,args);
}
