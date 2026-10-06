import {spawn,execFileSync} from 'node:child_process';
import {readFile,mkdtemp,writeFile,rm} from 'node:fs/promises';
import {join,dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {fileURLToPath} from 'node:url';
import {codexPolicy,claudePolicy,toml} from './policy.ts';
import type {GatewayConfig,Binding} from './gateway.ts';

export async function launch(config:GatewayConfig,harness:string,binary:string,args:string[]) {
  const catalog=JSON.parse(await readFile(config.catalog,'utf8'));
  const directory=await mkdtemp(join(tmpdir(),'f-query-harness-'));
  try {
    const gatewayConfig=join(directory,'gateway.json');
    const server={command:process.execPath,args:[join(dirname(fileURLToPath(import.meta.url)),'gateway.ts'),gatewayConfig]};
    let filtered:string[];
    if(harness==='codex') {
      const servers=JSON.parse(execFileSync(binary,['mcp','list','--json'],{cwd:config.workspace,encoding:'utf8',timeout:30000,maxBuffer:4*1024*1024}));
      filtered=[...codexPolicy(catalog.tools,servers),'-c','mcp_servers.hyper_queries='+toml({...server,enabled:true,startup_timeout_sec:60,tool_timeout_sec:150}),...args];
    } else if(harness==='claude') {
      filtered=args.filter(value=>value!=='--chrome'&&value!=='--no-chrome');
      const index=filtered.indexOf('--mcp-config');
      const existing:{mcpServers?:Record<string,Binding>}=index>=0?JSON.parse(filtered[index+1]):{mcpServers:{}};
      config={...config,mutations:true};
      const servers=existing.mcpServers??{};
      config.worker??=servers.codex_worker;
      config.remote??=servers.hypertui;
      for(const [name,binding] of Object.entries(servers))if(!['codex_worker','hypertui','hyper_queries'].includes(name))config.programs={...config.programs,[name]:binding};
      const native={mcpServers:{hyper_queries:server,...(servers.codex_worker?{codex_worker:servers.codex_worker}:{})}};
      if(index>=0)filtered[index+1]=JSON.stringify(native);
      else filtered.push('--mcp-config',JSON.stringify(native));
      const allowed=filtered.indexOf('--allowedTools');
      const tools='mcp__hyper_queries__hyperTUI,mcp__hyper_queries__hyperTUI_action'+(servers.codex_worker?',mcp__codex_worker__present_ui':'');
      if(allowed>=0)filtered[allowed+1]=tools;else filtered.push('--allowedTools',tools);
      const builtins=filtered.indexOf('--tools');
      if(builtins>=0)filtered[builtins+1]='';else filtered.push('--tools','');
      if(!filtered.includes('--strict-mcp-config'))filtered.push('--strict-mcp-config');
      const denied=filtered.indexOf('--disallowedTools');
      if(denied>=0)filtered.splice(denied,2);
      filtered.push('--no-chrome',...claudePolicy(catalog.tools));
    } else throw Error('Expected codex or claude harness.');
    await writeFile(gatewayConfig,JSON.stringify(config),{mode:0o600});
    const child=spawn(binary,filtered,{cwd:config.workspace,stdio:'inherit'});
    const forward=(signal:NodeJS.Signals)=>child.kill(signal);
    const interrupt=()=>forward('SIGINT'),terminate=()=>forward('SIGTERM');
    process.on('SIGINT',interrupt);process.on('SIGTERM',terminate);
    try {
      process.exitCode=await new Promise<number>((resolve,reject)=>{child.on('error',reject);child.on('exit',code=>resolve(code??1));});
    } finally {process.off('SIGINT',interrupt);process.off('SIGTERM',terminate);}
  } finally {await rm(directory,{recursive:true,force:true});}
}
if(import.meta.main) {
  const [raw,harness,binary,...args]=process.argv.slice(2);
  await launch(JSON.parse(raw),harness,binary,args);
}
