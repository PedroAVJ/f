import {test,expect} from 'bun:test';
import {mkdtemp,writeFile,readFile,rm} from 'node:fs/promises';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
test('fresh launch retains unrelated restrictions and restores only migrated worker permissions',async()=>{
 const dir=await mkdtemp(join(tmpdir(),'hyper-launch-'));
 try {
  const binary=join(dir,'capture'),output=join(dir,'capture.json'),catalog=join(dir,'catalog.json');
  await writeFile(catalog,'{"tools":[]}');
  await writeFile(binary,'#!/opt/homebrew/bin/bun\nimport {readFile,writeFile} from "node:fs/promises";\nconst args=process.argv.slice(2);if(args[0]==="mcp"){console.log("[]");process.exit(0);}\nlet raw=args[args.indexOf("--mcp-config")+1];let c=raw?JSON.parse(raw).mcpServers.hyper_queries:null;await writeFile('+JSON.stringify(output)+',JSON.stringify({args,gateway:c?JSON.parse(await readFile(c.args[1],"utf8")):null}));\n',{mode:0o700});
  const config={catalog,workspace:dir,codex:binary,claude:binary,mutations:false};
  const launch=join(import.meta.dir,'launch.ts'),mcp=JSON.stringify({mcpServers:{codex_worker:{command:'unused',args:[]},unrelated:{command:'unused',args:[]}}});
  for(const migrated of [false,true]){
   const args=['--tools','','--strict-mcp-config','--mcp-config',mcp,'--allowedTools',migrated?'mcp__codex_worker__present_ui':'mcp__codex_worker__worker_status','--disallowedTools','Bash','--append-system-prompt',migrated?'\nUse hyper_queries.hyperTUI(uri), starting at hypertui://programs/, for local state.':'Unrelated restrictions.'];
   const child=Bun.spawn([process.execPath,launch,JSON.stringify(config),'claude',binary,...args],{stdout:'pipe',stderr:'pipe'});expect(await child.exited).toBe(0);
   const result=JSON.parse(await readFile(output,'utf8')),allowed=result.args[result.args.indexOf('--allowedTools')+1];
   expect(allowed.includes('worker_start')).toBe(migrated);expect(result.gateway.mutations).toBe(false);expect(result.gateway.remoteOnly).toBe(true);
   expect(result.args[result.args.indexOf('--tools')+1]).toBe('');expect(result.args[result.args.indexOf('--disallowedTools')+1]).toBe('Bash');expect(allowed.includes('hyperTUI_action')).toBe(false);
  }
 }finally{await rm(dir,{recursive:true,force:true});}
});
