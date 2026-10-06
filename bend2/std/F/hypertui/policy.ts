import type { Entry } from './gateway.ts';
type PolicyEntry=Entry & {policyKey?:string};
export function toml(value:any):string {
  if(Array.isArray(value)) return '['+value.map(toml).join(',')+']';
  if(value && typeof value==='object') return '{'+Object.entries(value).filter(([,v])=>v!==null&&v!==undefined).map(([k,v])=>JSON.stringify(k)+'='+toml(v)).join(',')+'}';
  return JSON.stringify(value);
}
export function codexPolicy(entries:PolicyEntry[],servers:any[]):string[] {
  const overrides=['features.view_image=false','web_search="disabled"'];
  for(const entry of entries.filter(e=>e.backend==='codex'&&e.class==='query'&&e.server==='codex_apps')) {
    if(!entry.policyKey?.startsWith('apps.')) throw Error('Connector query has no supported exposure policy: '+entry.name);
    overrides.push(entry.policyKey+'=false');
  }
  for(const server of servers) {
    const tools=entries.filter(e=>e.backend==='codex'&&e.server===server.name);
    if(!server.enabled || !tools.some(e=>e.class==='query')) continue;
    const retained=tools.filter(e=>e.class!=='query').map(e=>e.name);
    const {type,...transport}=server.transport;
    const config:any={...transport,enabled:retained.length>0,enabled_tools:retained};
    for(const key of ['startup_timeout_sec','tool_timeout_sec']) if(server[key]!==null) config[key]=server[key];
    overrides.push('mcp_servers.'+server.name+'='+toml(config));
  }
  return overrides.flatMap(value=>['-c',value]);
}
export function claudePolicy(entries:Entry[]):string[] {
  return ['--disallowedTools',entries.filter(e=>e.backend==='chrome'&&e.class==='query').map(e=>'mcp__claude-in-chrome__'+e.name).join(',')];
}
