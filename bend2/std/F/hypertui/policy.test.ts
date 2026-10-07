import {test,expect} from 'bun:test';
import {codexPolicy,claudePolicy,restorePrompt,restoreCodexArgs,restoreCodexPrompt} from './policy.ts';
import {QueryGateway} from './gateway.ts';
test('only explicit verified remote replacements may disable a connector tool',()=>{
 const base:any={backend:'codex',server:'codex_apps',name:'read',class:'query',policyKey:'apps.test.tools.read.enabled'};
 expect(codexPolicy([base],[])).toEqual([]);
 expect(codexPolicy([{...base,replacement:{scope:'local',verified:true,uri:'https://example.test/'}}],[])).toEqual([]);
 expect(codexPolicy([{...base,replacement:{scope:'remote',verified:true,uri:'https://example.test/'}}],[])).toEqual(['-c','apps.test.tools.read.enabled=false']);
 expect(claudePolicy([{...base,backend:'chrome',replacement:{scope:'remote',verified:true,uri:'https://example.test/'}}])).toEqual(['--disallowedTools','mcp__claude-in-chrome__read']);
});
test('only the exact migration worker restriction is restored',()=>{
 const input=['exec','-c','mcp_servers.codex_worker={enabled_tools = ["worker_start", "worker_submit", "worker_stop", "present_ui"]}','-c','mcp_servers.unrelated.enabled=false'];
 const output=restoreCodexArgs(input);expect(output[2]).toContain('"worker_list","worker_status"');expect(output[4]).toBe(input[4]);
 const unrelated=['-c','mcp_servers.codex_worker={enabled_tools=["present_ui"]}'];expect(restoreCodexArgs(unrelated)).toEqual(unrelated);
});
test('prompt correction changes owned migration instructions and preserves user context',()=>{
 const old='Use the worker HyperTUI status page for live progress.\nUse hyper_queries.hyperTUI(uri), starting at hypertui://programs/, for files, workers. Only HyperTUI navigation is native.\nHyperTUI is installed. Transport auth remains required.';
 const result=restorePrompt(old);expect(result).toContain('Use worker_status');expect(result).not.toContain('Only HyperTUI navigation');expect(result).toContain('ownership-aware N');expect(result).toContain('Transport auth remains required');
 const context='Latest user request:\nQuote: the worker HyperTUI status page';const prompt='Continue the existing Open Dot conversation as Near.\n'+old+'\n'+context;
 expect(restoreCodexPrompt(prompt).endsWith(context)).toBe(true);expect(restoreCodexPrompt('unrelated user text')).toBe('unrelated user text');
});
test('remote-only gateway rejects local pages without starting backends',async()=>{
 const gateway=new QueryGateway([],process.cwd(),'unused','unused',undefined,{remoteOnly:true,mutations:true});
 try{for(const uri of ['hypertui://files/','hypertui://workers/','hypertui://repos/local/','/etc/hosts'])await expect(gateway.open(uri)).rejects.toThrow('ordinary local tools');}finally{gateway.close()}
});
test('prompt correction preserves restrictions following migration line without a sentinel',()=>{
 expect(restorePrompt('\nUse hyper_queries.hyperTUI(uri), starting at hypertui://programs/, for local work.\nNever enable unrelated tool X.')).toContain('Never enable unrelated tool X.');
});
