import { createInterface } from 'node:readline';
import { resolve, dirname } from 'node:path';
import { encode } from '../server/host.ts';
import { render, localImage, uri, validate, type Page } from './render.ts';

type App = {
  s(): unknown;
  hypertui_page(state:unknown,uri:string): any;
  hypertui_action(state:unknown,uri:string,name:string,args:unknown): {state:unknown; redirect:string};
};
const object = (properties:Record<string,unknown>, required = Object.keys(properties)) => ({type:'object',properties,required,additionalProperties:false});
const openTool = {name:'hyperTUI', description:'Open a page URI. Returns Markdown, inline images, and only that page’s typed mutation actions. Follow query links with this tool.', inputSchema:object({uri:{type:'string'}}), annotations:{readOnlyHint:true}};
const actTool = {name:'hyperTUI_action', description:'Invoke a typed action advertised on the currently open page. Copy its name and follow its inputSchema. Returns a redirect URI; open it with hyperTUI.', inputSchema:object({uri:{type:'string'},name:{type:'string'},arguments:{type:'object'}})};

export class Session {
  private state: unknown;
  private current = '';
  private page?: Page;
  constructor(private app: App, private assets: string) { this.state = app.s(); }
  async open(address: string) {
    const target = uri(address);
    const page = await render(this.app.hypertui_page(this.state,target),asset => localImage(this.assets,asset));
    this.current = target;
    this.page = page;
    const metadata = {uri:target,actions:page.actions};
    return {content:[...page.content,{type:'text' as const,text:'Page actions (invoke with hyperTUI_action):\n```json\n'+JSON.stringify(metadata,null,2)+'\n```'}]};
  }
  async act(address: string, name: string, args: unknown) {
    if (uri(address) !== this.current || !this.page) throw Error('Open this page before invoking an action.');
    // Re-render before mutation: an enabled action may have disappeared since open.
    const fresh = await render(this.app.hypertui_page(this.state,this.current),asset => localImage(this.assets,asset));
    const action = fresh.actions.find(action => action.name === name);
    if (!action) throw Error('Action is not enabled on the current page.');
    validate(action.inputSchema,args);
    const next = this.app.hypertui_action(this.state,this.current,name,encode(args as Parameters<typeof encode>[0]));
    const redirect = uri(next.redirect);
    this.state = next.state;
    this.page = undefined;
    this.current = '';
    return {content:[{type:'text',text:`[Continue](<${redirect}>)`}]};
  }
  async request(method: string, params: any = {}): Promise<unknown> {
    if (method === 'initialize') return {protocolVersion:'2025-06-18',capabilities:{tools:{}},serverInfo:{name:'F HyperTUI',version:'0.1.0'}};
    if (method === 'ping') return {};
    if (method === 'tools/list') return {tools:[openTool,actTool]};
    if (method === 'tools/call') {
      const args = params.arguments ?? {};
      try {
        if (params.name === 'hyperTUI') {
          if (Object.keys(args).some(key => key !== 'uri')) throw Error('Unexpected open argument.');
          return await this.open(args.uri);
        }
        if (params.name === 'hyperTUI_action') {
          if (Object.keys(args).some(key => !['uri','name','arguments'].includes(key)) || typeof args.name !== 'string') throw Error('Invalid action arguments.');
          return await this.act(args.uri,args.name,args.arguments);
        }
        throw Error('Unknown tool.');
      } catch (error) { return {isError:true,content:[{type:'text',text:error instanceof Error ? error.message : String(error)}]}; }
    }
    throw Error('Method not found: '+method);
  }
}

export async function serve(module: string, assets = dirname(module)) {
  await import('../../../main.ts');
  const app = (await import(resolve(module))).default as App;
  if (!['s','hypertui_page','hypertui_action'].every(name => typeof app[name as keyof App] === 'function')) throw Error('Missing F HyperTUI application entrypoints.');
  const session = new Session(app,assets);
  const lines = createInterface({input:process.stdin,crlfDelay:Infinity});
  for await (const line of lines) {
    let message: any;
    try {
      if (Buffer.byteLength(line) > 1024*1024) throw Error('Request exceeds 1 MiB.');
      message = JSON.parse(line);
      if (message.jsonrpc !== '2.0' || typeof message.method !== 'string' || Array.isArray(message)) throw Error('Invalid JSON-RPC request.');
      if (message.id === undefined) continue;
      if (typeof message.id !== 'string' && typeof message.id !== 'number') throw Error('Invalid request ID.');
      const result = await session.request(message.method,message.params);
      process.stdout.write(JSON.stringify({jsonrpc:'2.0',id:message.id,result})+'\n');
    } catch (error) {
      process.stdout.write(JSON.stringify({jsonrpc:'2.0',id:message?.id ?? null,error:{code:-32600,message:error instanceof Error ? error.message : String(error)}})+'\n');
    }
  }
}
if (import.meta.main) {
  const entry = process.argv[2];
  if (!entry?.endsWith('.bend')) throw Error('Usage: bun F/hypertui/host.ts APP.bend [ASSET_ROOT]');
  await serve(resolve(entry),process.argv[3] ? resolve(process.argv[3]) : dirname(resolve(entry)));
}
