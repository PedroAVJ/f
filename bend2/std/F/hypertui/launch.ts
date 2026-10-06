import {spawn,execFileSync} from 'node:child_process';
import {readFile,mkdtemp,writeFile,rm} from 'node:fs/promises';
import {join,dirname} from 'node:path';
import {tmpdir} from 'node:os';
import {fileURLToPath} from 'node:url';
import {codexPolicy,claudePolicy,toml} from './policy.ts';

export async function launch(config:{workspace:string;codex:string;claude:string;catalog:string;worker?:{command:string;args:string[]}},harness:string,binary:string,args:string[]) {
  const catalog=JSON.parse(await readFile(config.catalog,'utf8'));
  const directory=await mkdtemp(join(tmpdir(),'f-query-harness-'));
  try {
    const gatewayConfig=join(directory,'gateway.json');
    await writeFile(gatewayConfig,JSON.stringify(config),{mode:0o600});
    const server={command:process.execPath,args:[join(dirname(fileURLToPath(import.meta.url)),'gateway.ts'),gatewayConfig]};
    let filtered:string[];
    if(harness==='codex') {
      const servers=JSON.parse(execFileSync(binary,['mcp','list','--json'],{cwd:config.workspace,encoding:'utf8',timeout:30000,maxBuffer:4*1024*1024}));
      filtered=[...codexPolicy(catalog.tools,servers),'-c','mcp_servers.hyper_queries='+toml({...server,enabled:true,startup_timeout_sec:60,tool_timeout_sec:150}),...args];
    } else if(harness==='claude') {
      filtered=[...args];
      const index=filtered.indexOf('--mcp-config');
      if(index>=0) {
        const existing=JSON.parse(filtered[index+1]);
        existing.mcpServers.hyper_queries=server;
        filtered[index+1]=JSON.stringify(existing);
      } else filtered.push('--mcp-config',JSON.stringify({mcpServers:{hyper_queries:server}}));
      const allowed=filtered.indexOf('--allowedTools');
      if(allowed>=0) filtered[allowed+1]+=',mcp__hyper_queries__hyperTUI';
      filtered.push(...claudePolicy(catalog.tools));
    } else throw Error('Expected codex or claude harness.');
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
