import { createInterface } from 'node:readline';
import { readFile, readdir, realpath, open } from 'node:fs/promises';
import { constants } from 'node:fs';
import { resolve, relative, isAbsolute, extname, dirname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import { encode } from '../server/host.ts';
import { render, localImage, type Content } from './render.ts';
import { CodexQueries, McpQueries } from './backend.ts';
import { isMedia, mediaPage } from './media.ts';

export type Entry = {backend:'codex'|'chrome';server:string;name:string;class:'query'|'mutation'|'mixed';description:string;inputSchema:any};
type Block = {kind:string;[key:string]:unknown};
const queryUri = (entry:Entry) => `hypertui://tools/${encodeURIComponent(entry.backend)}/${encodeURIComponent(entry.server)}/${encodeURIComponent(entry.name)}`;
const link = (label:string,uri:string): Block => ({kind:'link',label,uri});
const code = (text:string,language=''): Block => ({kind:'code',text,language});
const words = (text:string): Block => ({kind:'text',text});

export class QueryGateway {
  private codex: CodexQueries;
  private chrome: McpQueries;
  private worker?: McpQueries;
  private renderer?: Promise<any>;
  constructor(private entries: Entry[], private workspace: string, codex: string, claude: string, worker?: {command:string;args:string[]}) {
    this.codex = new CodexQueries(codex,workspace);
    this.chrome = new McpQueries(claude,['--claude-in-chrome-mcp'],workspace);
    if (worker) this.worker = new McpQueries(worker.command,worker.args,workspace);
  }
  close() {this.codex.close();this.chrome.close();this.worker?.close();}
  private async page(title:string, blocks:Block[], images = new Map<string,Content>()) {
    this.renderer ??= (async () => {await import('../../../main.ts');return (await import('./program.bend')).default;})();
    const app = await this.renderer;
    const result = await render(app.tree(encode({title,blocks} as Parameters<typeof encode>[0])),async asset => {
      const image = images.get(asset);
      if (!image) throw Error('Image is not part of this query result.');
      return image;
    });
    return {content:result.content};
  }
  private async files(url:URL, absolutePath?:string) {
    const root = await realpath(absolutePath ? dirname(absolutePath) : this.workspace);
    const requested = absolutePath ? basename(absolutePath) : decodeURIComponent(url.pathname).replace(/^\//,'');
    const file = await realpath(resolve(root,requested)), subpath = relative(root,file);
    if (!absolutePath && (subpath.startsWith('..') || isAbsolute(subpath))) throw Error('File is outside this workspace.');
    const handle = await open(file,constants.O_RDONLY|constants.O_NOFOLLOW|constants.O_NONBLOCK);
    const blocks:Block[] = [link('Programs','hypertui://programs/'),...(absolutePath ? [words('Explicit file: '+absolutePath)] : [])];
    try {
      const stat = await handle.stat();
      if (absolutePath && !stat.isFile()) throw Error('Explicit absolute paths must identify regular files.');
      if (stat.isDirectory()) {
        const names = (await readdir(file,{withFileTypes:true})).filter(entry => !entry.isSymbolicLink()).sort((a,b) => a.name.localeCompare(b.name));
        if (names.length > 1000) throw Error('Directory has more than 1000 entries; open a narrower path.');
        for (const entry of names) blocks.push(link(entry.name+(entry.isDirectory()?'/':''),'hypertui://files/'+[subpath,entry.name].filter(Boolean).map(part=>part.split('/').map(encodeURIComponent).join('/')).join('/')));
        return await this.page(subpath || 'Workspace files',blocks);
      }
      if (!stat.isFile()) throw Error('Expected a regular file.');
      if (isMedia(file)) {
        if(stat.size>512*1024*1024) throw Error('Media files are limited to 512 MiB.');
        const media=await mediaPage(file,handle.fd,url);
        return await this.page(subpath,[...blocks,...media.blocks],media.images);
      }
      if (['.png','.jpg','.jpeg','.webp'].includes(extname(file).toLowerCase())) {
        const image = await localImage(absolutePath ? dirname(file) : root,absolutePath ? basename(file) : subpath), asset='image:current';
        blocks.push({kind:'image',label:subpath,asset});
        return await this.page(subpath,blocks,new Map([[asset,image]]));
      }
      if(stat.size>1024*1024) throw Error('Text files are limited to 1 MiB.');
      const bytes=await handle.readFile();
      const source = new TextDecoder('utf-8',{fatal:true}).decode(bytes);
      if (source.includes('\0')) throw Error('Binary files need an explicit viewer.');
      blocks.push(code(source,extname(file).slice(1).replace(/[^a-zA-Z0-9_+-]/g,'')));
      return await this.page(subpath,blocks);
    } finally {await handle.close();}
  }
  async open(address: string) {
    if (typeof address !== 'string' || address.length > 131072) throw Error('Expected a bounded HyperTUI URI or absolute file path.');
    let url = isAbsolute(address) ? new URL('hypertui://file/') : new URL(address);
    if (isAbsolute(address)) url.searchParams.set('path',address);
    else if (url.protocol === 'file:') {
      const file=fileURLToPath(url), search=url.search;
      url=new URL('hypertui://file/');url.search=search;url.searchParams.set('path',file);
    }
    if (url.protocol !== 'hypertui:') throw Error('Expected a HyperTUI or local file URI.');
    if (url.hostname === 'file') {
      const path=url.searchParams.get('path');
      if (!path || !isAbsolute(path)) throw Error('The explicit file page requires an absolute path.');
      return this.files(url,path);
    }
    if (url.hostname === 'files') return this.files(url);
    if (url.hostname === 'workers') {
      if (!this.worker) throw Error('This gateway has no worker binding.');
      return this.worker.call('hyperTUI',{uri:address});
    }
    const queries = this.entries.filter(entry => entry.class === 'query');
    if (url.hostname === 'programs' || url.hostname === 'browser' || url.hostname === 'repos') {
      const selected = queries.filter(entry => url.hostname === 'browser' ? entry.backend === 'chrome' : url.hostname === 'repos' ? entry.name.startsWith('github.') : true);
      const groups = Array.from(new Set(selected.map(entry => `${entry.backend}/${entry.server}/${entry.name.includes('.') ? entry.name.split('.')[0] : ''}`))).sort();
      const blocks = [link('Files','hypertui://files/'),...(this.worker ? [link('Workers','hypertui://workers/')] : []),link('Browser','hypertui://browser/'),link('Repositories','hypertui://repos/')];
      for (const group of groups) blocks.push(link(group,'hypertui://tools/'+group.split('/').map(encodeURIComponent).join('/')+'/'));
      return this.page('Programs',blocks);
    }
    if (url.hostname !== 'tools') throw Error('Unknown program.');
    const parts = url.pathname.split('/').filter(Boolean).map(decodeURIComponent), [backend,server,name] = parts;
    const entry = queries.find(item => item.backend === backend && item.server === server && item.name === name);
    if (!entry) {
      if (url.searchParams.has('args')) throw Error('Only cataloged query-only tools may run here.');
      const selected = queries.filter(item => item.backend === backend && item.server === server && (!name || item.name.startsWith(name+'.')));
      if (!selected.length) throw Error('Unknown query program.');
      return this.page(name || server,[link('Programs','hypertui://programs/'),...selected.map(item => link(item.name,queryUri(item)))]);
    }
    const blocks = [link('Programs','hypertui://programs/'),words(entry.description),code(JSON.stringify(entry.inputSchema,null,2),'json')];
    const raw = url.searchParams.get('args');
    if (raw === null) {
      blocks.push(words('Arguments are JSON in the args query parameter. Replace the required values in the linked query before opening it.'),link('Run query',queryUri(entry)+'?args='+encodeURIComponent(JSON.stringify(example(entry.inputSchema)))));
      return this.page(entry.name,blocks);
    }
    const args = JSON.parse(raw);
    if (!args || typeof args !== 'object' || Array.isArray(args)) throw Error('Query arguments must be a JSON object.');
    const result = entry.backend === 'chrome' ? await this.chrome.call(entry.name,args) : await this.codex.call(entry.server,entry.name,args);
    const images = new Map<string,Content>();
    for (const item of result.content ?? []) {
      if (item.type === 'text') blocks.push(code(item.text));
      else if (item.type === 'image') {
        const asset='image:'+images.size;
        images.set(asset,item);blocks.push({kind:'image',asset,label:'Query image'});
      } else if (item.type === 'resource_link') blocks.push(link(item.name,item.uri));
      else if (item.type === 'resource' && typeof item.resource?.text === 'string') blocks.push(code(item.resource.text));
      else throw Error('This query returned an unsupported content type.');
    }
    if (result.structuredContent !== undefined) blocks.push(code(JSON.stringify(result.structuredContent,null,2),'json'));
    if (!result.content?.length && result.structuredContent === undefined) blocks.push(code(JSON.stringify(result,null,2),'json'));
    const rendered = await this.page(entry.name,blocks,images);
    return {...rendered,...(result.isError ? {isError:true} : {})};
  }
}
function example(schema:any):unknown {
  if (schema.default !== undefined) return schema.default;
  if (Array.isArray(schema.enum)) return schema.enum[0];
  if (schema.type === 'object') return Object.fromEntries((schema.required ?? []).map((name:string) => [name,example(schema.properties?.[name] ?? {})]));
  if (schema.type === 'array') return [];
  if (schema.type === 'number' || schema.type === 'integer') return schema.minimum ?? 0;
  if (schema.type === 'boolean') return false;
  return '<required>';
}

export async function serveQueries(config:{catalog:string;workspace:string;codex:string;claude:string;worker?:{command:string;args:string[]}}) {
  const catalog = JSON.parse(await readFile(config.catalog,'utf8'));
  const gateway = new QueryGateway(catalog.tools,config.workspace,config.codex,config.claude,config.worker);
  const lines = createInterface({input:process.stdin,crlfDelay:Infinity});
  const close = () => {gateway.close();lines.close();};
  process.once('SIGTERM',close);process.once('SIGINT',close);
  try {
    for await (const line of lines) {
      let message:any;
      try {
        if (Buffer.byteLength(line) > 1024*1024) throw Error('Request exceeds 1 MiB.');
        message=JSON.parse(line);
        if (message.id === undefined) continue;
        let result:unknown;
        if (message.method === 'initialize') result={protocolVersion:'2025-06-18',capabilities:{tools:{}},serverInfo:{name:'F HyperTUI programs',version:'0.1.0'}};
        else if (message.method === 'ping') result={};
        else if (message.method === 'tools/list') result={tools:[{name:'hyperTUI',description:'Open an F program page. Start at hypertui://programs/. Explicit local files may use an absolute path, file:/// URI, or hypertui://file/?path=ENCODED_ABSOLUTE_PATH. Filesystem permissions still apply. Queries are URI links; tools moved here retain their original input schema and result.',inputSchema:{type:'object',properties:{uri:{type:'string'}},required:['uri'],additionalProperties:false},annotations:{readOnlyHint:true}}]};
        else if (message.method === 'tools/call' && message.params?.name === 'hyperTUI') {
          try {result=await gateway.open(message.params.arguments.uri);}
          catch(error) {result={isError:true,content:[{type:'text',text:error instanceof Error ? error.message : String(error)}]};}
        } else throw Error('Unknown method or tool.');
        process.stdout.write(JSON.stringify({jsonrpc:'2.0',id:message.id,result})+'\n');
      } catch(error) {process.stdout.write(JSON.stringify({jsonrpc:'2.0',id:message?.id ?? null,error:{code:-32600,message:error instanceof Error ? error.message : String(error)}})+'\n');}
    }
  } finally {close();}
}
if (import.meta.main) {
  const config = process.argv[2];
  if (!config) throw Error('Usage: gateway.ts CONFIG.json');
  await serveQueries(JSON.parse(await readFile(resolve(config),'utf8')));
}
