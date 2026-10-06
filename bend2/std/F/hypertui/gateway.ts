import { createInterface } from 'node:readline';
import { readFile, readdir, realpath, open } from 'node:fs/promises';
import { constants } from 'node:fs';
import { resolve, relative, isAbsolute, extname, dirname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash, randomUUID } from 'node:crypto';
import { execFile } from 'node:child_process';
import { encode } from '../server/host.ts';
import { render, localImage, type Content } from './render.ts';
import { checkSchema, validate, type Schema } from './schema.ts';
import { CodexQueries, McpQueries } from './backend.ts';
import { isMedia, mediaPage } from './media.ts';

export type Entry = {backend:'codex'|'chrome';server:string;name:string;class:'query'|'mutation'|'mixed';description:string;inputSchema:Schema};
export type Binding = {command:string;args:string[];cwd?:string;env?:NodeJS.ProcessEnv};
export type GatewayConfig = {catalog:string;workspace:string;codex:string;claude:string;worker?:Binding;mutations?:boolean;remote?:Binding;programs?:Record<string,Binding>;home?:string;remoteQueries?:Record<string,string[]>;links?:{label:string;uri:string}[]};
type Block = {kind:string;[key:string]:unknown};
type ScopedAction = {name:string;description:string;inputSchema:Schema;invoke:(args:any)=>Promise<Reply>};
type Reply = {content:Content[];actions?:ScopedAction[];isError?:boolean};
const toolUri = (entry:Entry) => `hypertui://tools/${encodeURIComponent(entry.backend)}/${encodeURIComponent(entry.server)}/${encodeURIComponent(entry.name)}`;
const link = (label:string,uri:string): Block => ({kind:'link',label,uri});
const code = (text:string,language=''): Block => ({kind:'code',text,language});
const words = (text:string): Block => ({kind:'text',text});
const object = (properties:Record<string,unknown>,required=Object.keys(properties)):Schema => ({type:'object',properties,required,additionalProperties:false});
const hash = (bytes:Buffer) => createHash('sha256').update(bytes).digest('hex');
const safeFile = (file:string) => !['.bend','.n'].includes(extname(file).toLowerCase()) && !['N.intent.json','N.intent.sig','.n-intent.json'].includes(basename(file));
const git = (workspace:string,args:string[]) => new Promise<string>((resolve,reject)=>execFile('git',['--no-optional-locks','-C',workspace,...args],{timeout:10000,maxBuffer:1024*1024,encoding:'utf8'},(error,stdout,stderr)=>error?reject(Error(String(stderr).trim()||error.message)):resolve(stdout)));
const addressUri = (address:string):URL => {
  if(typeof address!=='string'||address.length>131072) throw Error('Expected a bounded HyperTUI URI or absolute file path.');
  let url=isAbsolute(address)?new URL('hypertui://file/'):new URL(address);
  if(isAbsolute(address))url.searchParams.set('path',address);
  else if(url.protocol==='file:'){const path=fileURLToPath(url),search=url.search;url=new URL('hypertui://file/');url.search=search;url.searchParams.set('path',path);}
  if(!['hypertui:','http:','https:'].includes(url.protocol))throw Error('Unsupported page URI scheme.');
  return url;
};

export class QueryGateway {
  private codex:CodexQueries;
  private chrome:McpQueries;
  private worker?:McpQueries;
  private remote?:McpQueries;
  private programs=new Map<string,McpQueries>();
  private renderer?:Promise<any>;
  private current?:{uri:string;actions:Map<string,ScopedAction>};
  private results=new Map<string,Reply>();
  constructor(private entries:Entry[],private workspace:string,codex:string,claude:string,worker?:Binding,private options:Pick<GatewayConfig,'mutations'|'remote'|'programs'|'home'|'remoteQueries'|'links'>={}) {
    this.codex=new CodexQueries(codex,workspace);
    this.chrome=new McpQueries(claude,['--claude-in-chrome-mcp'],workspace);
    if(worker)this.worker=new McpQueries(worker.command,worker.args,worker.cwd??workspace,worker.env);
    if(options.remote)this.remote=new McpQueries(options.remote.command,options.remote.args,options.remote.cwd??workspace,options.remote.env);
    for(const [name,binding] of Object.entries(options.programs??{}))this.programs.set(name,new McpQueries(binding.command,binding.args,binding.cwd??workspace,binding.env));
  }
  close(){this.codex.close();this.chrome.close();this.worker?.close();this.remote?.close();for(const backend of this.programs.values())backend.close();}
  private async page(title:string,blocks:Block[],images=new Map<string,Content>(),actions:ScopedAction[]=[]):Promise<Reply> {
    this.renderer??=(async()=>{await import('../../../main.ts');return(await import('./program.bend')).default;})();
    const app=await this.renderer;
    const actionBlocks=actions.map(action=>({kind:'action',name:action.name,label:action.description,inputSchema:action.inputSchema}));
    const result=await render(app.tree(encode({title,blocks:[...blocks,...actionBlocks]} as Parameters<typeof encode>[0])),async asset=>{
      const image=images.get(asset);if(!image)throw Error('Image is not part of this page.');return image;
    });
    return{content:result.content,actions};
  }
  private async resultPage(title:string,result:any,source:string,actions:ScopedAction[]=[],extra:Block[]=[]):Promise<Reply> {
    const blocks:Block[]=[link('Programs','hypertui://programs/'),link('Source page',source),...extra],images=new Map<string,Content>();
    for(const item of result.content??[]) {
      if(item.type==='text') {
        blocks.push(code(item.text));
        // Providers may return Markdown links; lower those links into F query nodes.
        for(const match of item.text.matchAll(/\[([^\]]+)\]\(<?([^\s)>]+)>?\)/g)) {
          try {const target=new URL(match[2],source);if(['hypertui:','http:','https:'].includes(target.protocol))blocks.push(link(match[1],target.href));}catch(error){if(!(error instanceof TypeError))throw error;}
        }
      } else if(item.type==='image') {const asset='image:'+images.size;images.set(asset,item);blocks.push({kind:'image',asset,label:'Page image'});}
      else if(item.type==='resource_link')blocks.push(link(item.name,item.uri));
      else if(item.type==='resource'&&typeof item.resource?.text==='string')blocks.push(code(item.resource.text));
      else throw Error('This program returned an unsupported content type.');
    }
    if(result.structuredContent!==undefined)blocks.push(code(JSON.stringify(result.structuredContent,null,2),'json'));
    if(!result.content?.length&&result.structuredContent===undefined)blocks.push(code(JSON.stringify(result,null,2),'json'));
    return{...await this.page(title,blocks,images,actions),...(result.isError?{isError:true}:{})};
  }
  private async files(url:URL,absolutePath?:string):Promise<Reply> {
    const root=await realpath(absolutePath?dirname(absolutePath):this.workspace);
    const requested=absolutePath?basename(absolutePath):decodeURIComponent(url.pathname).replace(/^\//,'');
    const file=await realpath(resolve(root,requested)),subpath=relative(root,file);
    if(!absolutePath&&(subpath.startsWith('..')||isAbsolute(subpath)))throw Error('File is outside this workspace.');
    const handle=await open(file,constants.O_RDONLY|constants.O_NOFOLLOW|constants.O_NONBLOCK);
    const blocks:Block[]=[link('Programs','hypertui://programs/'),...(absolutePath?[words('Explicit file: '+absolutePath)]:[])];
    try {
      const stat=await handle.stat();
      if(absolutePath&&!stat.isFile())throw Error('Explicit absolute paths must identify regular files.');
      if(stat.isDirectory()) {
        const names=(await readdir(file,{withFileTypes:true})).filter(entry=>!entry.isSymbolicLink()).sort((a,b)=>a.name.localeCompare(b.name));
        if(names.length>1000)throw Error('Directory has more than 1000 entries; open a narrower path.');
        for(const entry of names)blocks.push(link(entry.name+(entry.isDirectory()?'/':''),'hypertui://files/'+[subpath,entry.name].filter(Boolean).map(part=>part.split('/').map(encodeURIComponent).join('/')).join('/')));
        return this.page(subpath||'Workspace files',blocks);
      }
      if(!stat.isFile())throw Error('Expected a regular file.');
      if(isMedia(file)) {
        if(stat.size>512*1024*1024)throw Error('Media files are limited to 512 MiB.');
        const media=await mediaPage(file,handle.fd,url);return this.page(subpath,[...blocks,...media.blocks],media.images);
      }
      if(['.png','.jpg','.jpeg','.webp'].includes(extname(file).toLowerCase())) {
        const image=await localImage(absolutePath?dirname(file):root,absolutePath?basename(file):subpath),asset='image:current';
        blocks.push({kind:'image',label:subpath,asset});return this.page(subpath,blocks,new Map([[asset,image]]));
      }
      if(stat.size>1024*1024)throw Error('Text files are limited to 1 MiB.');
      const bytes=await handle.readFile(),source=new TextDecoder('utf-8',{fatal:true}).decode(bytes),digest=hash(bytes);
      const workspaceRelative=relative(await realpath(this.workspace),file),workspaceFile=!workspaceRelative.startsWith('..')&&!isAbsolute(workspaceRelative);
      if(source.includes('\0'))throw Error('Binary files need an explicit viewer.');
      blocks.push(code(source,extname(file).slice(1).replace(/[^a-zA-Z0-9_+-]/g,'')),words('SHA256: '+digest));
      const actions:ScopedAction[]=[];
      if(this.options.mutations&&workspaceFile&&safeFile(file))actions.push({name:'replace_text',description:'Replace this text file, only if its SHA256 still matches the displayed version.',inputSchema:object({expectedSHA256:{type:'string',const:digest},text:{type:'string',maxLength:1024*1024}}),invoke:async args=>{
        if(!safeFile(file))throw Error('Protected source must be edited through its ownership-aware program.');
        const next=Buffer.from(args.text,'utf8');if(next.length>1024*1024||args.text.includes('\0'))throw Error('Replacement must be UTF-8 text of at most 1 MiB.');
        const writer=await open(file,constants.O_RDWR|constants.O_NOFOLLOW|constants.O_NONBLOCK);
        try {
          const current=await writer.stat();if(!current.isFile()||current.size>1024*1024||current.dev!==stat.dev||current.ino!==stat.ino||hash(await writer.readFile())!==args.expectedSHA256)throw Error('File changed; open it again before editing.');
          await writer.write(next,0,next.length,0);await writer.truncate(next.length);await writer.sync();
        }finally{await writer.close();}
        return this.page('File saved',[words('Wrote '+next.length+' bytes.'),words('SHA256: '+hash(next)),link('Read saved file',url.href)]);
      }});
      if(this.options.mutations&&!workspaceFile)blocks.push(words('This explicitly supplied file is outside the active workspace and is read-only here.'));
      if(this.options.mutations&&!safeFile(file))blocks.push(words('Protected Bend/N source and ownership manifests are read-only here. Use the N program for checked body edits.'));
      return this.page(subpath,blocks,new Map(),actions);
    }finally{await handle.close();}
  }
  private async workerPage(url:URL):Promise<Reply> {
    if(!this.worker)throw Error('This gateway has no worker binding.');
    const backend=this.worker,result=await backend.call('hyperTUI',{uri:url.href});
    const {tools}=await backend.listTools();
    const names=url.pathname==='/'?['worker_start']:['worker_submit','worker_stop'];
    const workerId=decodeURIComponent(url.pathname.slice(1));
    const actions:ScopedAction[]=this.options.mutations?tools.filter((tool:any)=>names.includes(tool.name)).map((tool:any)=>{
      const inputSchema=workerId?{...tool.inputSchema,properties:{...tool.inputSchema.properties,workerId:{type:'string',const:workerId}},required:Array.from(new Set([...(tool.inputSchema.required??[]),'workerId']))}:tool.inputSchema;
      return{...tool,inputSchema,invoke:async(args:any)=>this.resultPage(tool.name,await backend.call(tool.name,args),url.href)};
    }):[];
    return this.resultPage('Workers',result,url.href,actions);
  }
  private async remoteOperations(address:string,result:any) {
    const backend=this.remote!;
    const {tools}=await backend.listTools();
    if(tools.some((tool:any)=>tool.name==='hyperTUI_action')) {
      const metadata=result.content?.find((item:any)=>item.type==='text'&&item.text.startsWith('Page actions (invoke with hyperTUI_action):'));
      const json=metadata?.text.match(/```json\n([\s\S]*)\n```/)?.[1];
      if(!json)return[];
      const page=JSON.parse(json);
      return(page.actions??[]).map((action:any)=>({...action,call:(args:any)=>backend.call('hyperTUI_action',{uri:page.uri,name:action.name,arguments:args})}));
    }
    return tools.filter((tool:any)=>tool.name!=='hyperTUI').map((tool:any)=>({...tool,name:tool.name.replace(/^p[0-9]+_/,''),call:(args:any)=>backend.call(tool.name,args)}));
  }
  private remoteQuery(address:string,name:string) {
    const target=new URL('hypertui://remote/');target.searchParams.set('page',address);target.searchParams.set('query',name);return target;
  }
  private async remotePage(address:string,result?:any):Promise<Reply> {
    if(!this.remote)throw Error('No remote HyperTUI provider is configured.');
    result??=await this.remote.call('hyperTUI',{uri:address});
    const operations=await this.remoteOperations(address,result),queries=this.options.remoteQueries?.[new URL(address).origin]??[];
    const extra=operations.filter((operation:any)=>queries.includes(operation.name)).map((operation:any)=>link(operation.name,this.remoteQuery(address,operation.name).href));
    const actions:ScopedAction[]=this.options.mutations?operations.filter((operation:any)=>!queries.includes(operation.name)).map((operation:any)=>({name:operation.name,description:operation.description,inputSchema:operation.inputSchema,invoke:async(args:any)=>this.remotePage(address,await operation.call(args))})):[];
    return this.resultPage('Remote program',result,address,actions,extra);
  }
  private async remoteQueryPage(url:URL):Promise<Reply> {
    const address=url.searchParams.get('page'),name=url.searchParams.get('query');
    if(!this.remote||!address||!name||!this.options.remoteQueries?.[new URL(address).origin]?.includes(name))throw Error('Unknown configured remote query.');
    const result=await this.remote.call('hyperTUI',{uri:address}),operations=await this.remoteOperations(address,result),operation=operations.find((operation:any)=>operation.name===name);
    if(!operation)throw Error('This query is not available on that source page.');
    const raw=url.searchParams.get('args');
    if(raw===null) {
      const run=new URL(url);run.searchParams.set('args',JSON.stringify(example(operation.inputSchema)));
      return this.page(name,[link('Source page',address),words(operation.description),code(JSON.stringify(operation.inputSchema,null,2),'json'),link('Run query',run.href)]);
    }
    const args=JSON.parse(raw);validate(operation.inputSchema,args);
    return this.remotePage(address,await operation.call(args));
  }
  private async externalPage(url:URL):Promise<Reply> {
    const [name,toolName]=url.pathname.split('/').filter(Boolean).map(decodeURIComponent),backend=this.programs.get(name);
    if(!backend)throw Error('Unknown configured program.');
    const {tools}=await backend.listTools();
    if(!toolName)return this.page(name,[link('Programs','hypertui://programs/'),...tools.map((tool:any)=>link(tool.name,'hypertui://program/'+encodeURIComponent(name)+'/'+encodeURIComponent(tool.name)))]);
    const tool=tools.find((tool:any)=>tool.name===toolName);if(!tool)throw Error('Unknown program operation.');
    checkSchema(tool.inputSchema);
    const blocks=[link('Program','hypertui://program/'+encodeURIComponent(name)),words(tool.description??tool.name),code(JSON.stringify(tool.inputSchema,null,2),'json')];
    if(tool.annotations?.readOnlyHint===true) {
      const raw=url.searchParams.get('args');
      if(raw===null)return this.page(tool.name,[...blocks,link('Run query',url.href+'?args='+encodeURIComponent(JSON.stringify(example(tool.inputSchema))))]);
      const args=JSON.parse(raw);validate(tool.inputSchema,args);
      return this.resultPage(tool.name,await backend.call(tool.name,args),url.href);
    }
    if(!this.options.mutations)throw Error('Mutation pages are not enabled in this harness.');
    return this.page(tool.name,blocks,new Map(),[{name:'run',description:tool.description??tool.name,inputSchema:tool.inputSchema,invoke:async args=>this.resultPage(tool.name,await backend.call(tool.name,args),url.href)}]);
  }
  private async read(url:URL):Promise<Reply> {
    if(url.protocol!=='hypertui:')return this.remotePage(url.href);
    if(url.hostname==='file') {const path=url.searchParams.get('path');if(!path||!isAbsolute(path))throw Error('The explicit file page requires an absolute path.');return this.files(url,path);}
    if(url.hostname==='files')return this.files(url);
    if(url.hostname==='workers')return this.workerPage(url);
    if(url.hostname==='program')return this.externalPage(url);
    if(url.hostname==='remote')return this.remoteQueryPage(url);
    if(url.hostname==='results'){const page=this.results.get(url.pathname.slice(1));if(!page)throw Error('Result page expired or belongs to another session.');return page;}
    const available=this.entries.filter(entry=>this.options.mutations||entry.class==='query');
    if(url.hostname==='repos'&&url.pathname==='/local/') {
      const status=await git(this.workspace,['status','--short','--branch']),files=await git(this.workspace,['ls-files']);
      const blocks:Block[]=[link('Programs','hypertui://programs/'),code(status,'text'),link('Workspace files','hypertui://files/')];
      for(const file of files.trim().split('\n').filter(Boolean).slice(0,1000))blocks.push(link(file,'hypertui://files/'+file.split('/').map(encodeURIComponent).join('/')));
      return this.page('Local repository',blocks);
    }
    if(url.hostname==='programs'||url.hostname==='browser'||url.hostname==='repos') {
      const selected=available.filter(entry=>url.hostname==='browser'?entry.backend==='chrome':url.hostname==='repos'?entry.name.startsWith('github.'):true);
      const groups=Array.from(new Set(selected.map(entry=>`${entry.backend}/${entry.server}/${entry.name.includes('.')?entry.name.split('.')[0]:''}`))).sort();
      const blocks=[link('Files','hypertui://files/'),...(this.worker?[link('Workers','hypertui://workers/')]:[]),link('Browser','hypertui://browser/'),link('Repositories','hypertui://repos/'),link('Local repository','hypertui://repos/local/'),...(this.options.home?[link('Remote programs',this.options.home)]:[])];
      for(const item of this.options.links??[])blocks.push(link(item.label,item.uri));
      for(const name of this.programs.keys())blocks.push(link(name,'hypertui://program/'+encodeURIComponent(name)));
      for(const group of groups)blocks.push(link(group,'hypertui://tools/'+group.split('/').map(encodeURIComponent).join('/')+'/'));
      return this.page('Programs',blocks);
    }
    if(url.hostname!=='tools')throw Error('Unknown program.');
    const [backend,server,name]=url.pathname.split('/').filter(Boolean).map(decodeURIComponent);
    const entry=available.find(item=>item.backend===backend&&item.server===server&&item.name===name);
    if(!entry) {
      if(url.searchParams.has('args'))throw Error('Only cataloged query-only tools may run here.');
      const selected=available.filter(item=>item.backend===backend&&item.server===server&&(!name||item.name.startsWith(name+'.')));
      if(!selected.length)throw Error('Unknown program operation.');
      return this.page(name||server,[link('Programs','hypertui://programs/'),...selected.map(item=>link(item.name,toolUri(item)))]);
    }
    const blocks=[link('Programs','hypertui://programs/'),words(entry.description),code(JSON.stringify(entry.inputSchema,null,2),'json')];
    const invoke=async(args:any)=>this.resultPage(entry.name,entry.backend==='chrome'?await this.chrome.call(entry.name,args):await this.codex.call(entry.server,entry.name,args),url.href);
    if(entry.class!=='query')return this.page(entry.name,blocks,new Map(),[{name:'run',description:entry.description,inputSchema:entry.inputSchema,invoke}]);
    const raw=url.searchParams.get('args');
    if(raw===null)return this.page(entry.name,[...blocks,words('Arguments are JSON in the args query parameter. Replace required values in the query link before opening it.'),link('Run query',toolUri(entry)+'?args='+encodeURIComponent(JSON.stringify(example(entry.inputSchema))))]);
    const args=JSON.parse(raw);validate(entry.inputSchema,args);return invoke(args);
  }
  async open(address:string) {
    const url=addressUri(address),page=await this.read(url);
    const actions=page.actions??[];
    this.current={uri:url.href,actions:new Map(actions.map(action=>[action.name,action]))};
    const metadata={uri:url.href,actions:actions.map(({invoke,...action})=>action)};
    return{content:[...page.content,{type:'text' as const,text:'Page actions (invoke with hyperTUI_action):\n```json\n'+JSON.stringify(metadata,null,2)+'\n```'}],...(page.isError?{isError:true}:{})};
  }
  async act(address:string,name:string,args:unknown) {
    if(!this.options.mutations)throw Error('Mutation pages are not enabled in this harness.');
    const uri=addressUri(address).href;
    if(!this.current||this.current.uri!==uri)throw Error('Open this page before invoking its action.');
    const action=this.current.actions.get(name);if(!action)throw Error('Action is not enabled on the current page.');
    validate(action.inputSchema,args);this.current=undefined;
    let result:Reply;
    try{result=await action.invoke(args);}catch(error){result=await this.page('Action outcome',[words(error instanceof Error?error.message:String(error)),words('The operation did not complete successfully. Inspect its source before retrying.'),link('Inspect source',uri)]);result.isError=true;}
    const id=randomUUID();this.results.set(id,result);while(this.results.size>16)this.results.delete(this.results.keys().next().value!);
    return{content:[{type:'text' as const,text:'[Continue](<hypertui://results/'+id+'>)'}],...(result.isError?{isError:true}:{})};
  }
}
function example(schema:Schema):unknown {
  if(schema.default!==undefined)return schema.default;
  if(schema.const!==undefined)return schema.const;
  if(Array.isArray(schema.enum))return schema.enum[0];
  if(schema.type==='object')return Object.fromEntries((schema.required??[]).map((name:string)=>[name,example(schema.properties?.[name]??{})]));
  if(schema.type==='array')return[];
  if(schema.type==='number'||schema.type==='integer')return schema.minimum??0;
  if(schema.type==='boolean')return false;
  return'<required>';
}
export async function serveQueries(config:GatewayConfig) {
  const catalog=JSON.parse(await readFile(config.catalog,'utf8'));
  const gateway=new QueryGateway(catalog.tools,config.workspace,config.codex,config.claude,config.worker,config);
  const lines=createInterface({input:process.stdin,crlfDelay:Infinity});
  const close=()=>{gateway.close();lines.close();};process.once('SIGTERM',close);process.once('SIGINT',close);
  const navigation={name:'hyperTUI',description:'Open an F program page. Start at hypertui://programs/. Read-only operations use URI links; mutations are typed actions on the current page. Explicit local files accept absolute paths, file:/// URIs, or hypertui://file/?path=ENCODED_ABSOLUTE_PATH. Normal filesystem permissions apply.',inputSchema:object({uri:{type:'string'}}),annotations:{readOnlyHint:true}};
  const mutation={name:'hyperTUI_action',description:'Invoke only a typed action advertised on the currently open page. Copy its exact input schema. Returns a redirect URI: open it with hyperTUI to read the result. Old page actions become invalid after invocation.',inputSchema:object({uri:{type:'string'},name:{type:'string'},arguments:{type:'object'}})};
  try {
    for await(const line of lines) {
      let message:any;
      try {
        if(Buffer.byteLength(line)>2*1024*1024)throw Error('Request exceeds 2 MiB.');
        message=JSON.parse(line);if(message.id===undefined)continue;
        let result:unknown;
        if(message.method==='initialize')result={protocolVersion:'2025-06-18',capabilities:{tools:{}},serverInfo:{name:'F HyperTUI programs',version:'0.2.0'}};
        else if(message.method==='ping')result={};
        else if(message.method==='tools/list')result={tools:config.mutations?[navigation,mutation]:[navigation]};
        else if(message.method==='tools/call') {
          try {
            const args=message.params.arguments??{};
            if(message.params.name==='hyperTUI'){validate(navigation.inputSchema,args);result=await gateway.open(args.uri);}
            else if(message.params.name==='hyperTUI_action'){validate(mutation.inputSchema,args);result=await gateway.act(args.uri,args.name,args.arguments);}
            else throw Error('Unknown tool.');
          }catch(error){result={isError:true,content:[{type:'text',text:error instanceof Error?error.message:String(error)}]};}
        }else throw Error('Unknown method.');
        process.stdout.write(JSON.stringify({jsonrpc:'2.0',id:message.id,result})+'\n');
      }catch(error){process.stdout.write(JSON.stringify({jsonrpc:'2.0',id:message?.id??null,error:{code:-32600,message:error instanceof Error?error.message:String(error)}})+'\n');}
    }
  }finally{close();}
}
if(import.meta.main){const config=process.argv[2];if(!config)throw Error('Usage: gateway.ts CONFIG.json');await serveQueries(JSON.parse(await readFile(resolve(config),'utf8')));}
