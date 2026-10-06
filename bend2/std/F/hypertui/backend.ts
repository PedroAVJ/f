import { spawn, type ChildProcessWithoutNullStreams } from 'node:child_process';
import { createInterface } from 'node:readline';

export class RpcProcess {
  private child: ChildProcessWithoutNullStreams;
  private serial = 0;
  private pending = new Map<number,{resolve:(value:any)=>void;reject:(error:Error)=>void;timer:ReturnType<typeof setTimeout>}>();
  constructor(command: string, args: string[], cwd?: string, env?: NodeJS.ProcessEnv) {
    this.child = spawn(command,args,{cwd,env:{...process.env,...env},stdio:['pipe','pipe','pipe']});
    this.child.stderr.on('data',() => {});
    this.child.on('error',error => this.fail(error));
    this.child.on('exit',code => this.fail(Error('Backend exited: '+code)));
    const lines = createInterface({input:this.child.stdout});
    lines.on('line',line => {
      try {
        const message = JSON.parse(line), request = this.pending.get(message.id);
        if (!request) return;
        clearTimeout(request.timer);this.pending.delete(message.id);
        if (message.error) request.reject(Error(message.error.message));
        else request.resolve(message.result);
      } catch (error) {this.fail(error instanceof Error ? error : Error(String(error)));}
    });
  }
  private fail(error: Error) {
    for (const item of this.pending.values()) {clearTimeout(item.timer);item.reject(error);}
    this.pending.clear();
  }
  call(method: string, params: unknown, timeout = 60000): Promise<any> {
    const id = ++this.serial;
    return new Promise((resolve,reject) => {
      const timer = setTimeout(() => {this.pending.delete(id);reject(Error('Backend request timed out: '+method));},timeout);
      this.pending.set(id,{resolve,reject,timer});
      this.child.stdin.write(JSON.stringify({jsonrpc:'2.0',id,method,params})+'\n');
    });
  }
  notify(method: string) {this.child.stdin.write(JSON.stringify({jsonrpc:'2.0',method})+'\n');}
  close() {this.fail(Error('Backend closed.'));this.child.kill();}
}

export class CodexQueries {
  private rpc?: RpcProcess;
  private thread?: Promise<string>;
  constructor(private command: string, private cwd: string) {}
  private start(): Promise<string> {
    if (!this.thread) this.thread = (async () => {
      this.rpc = new RpcProcess(this.command,['app-server','--stdio'],this.cwd);
      await this.rpc.call('initialize',{clientInfo:{name:'F-HyperTUI-queries',version:'0.1.0'},capabilities:{experimentalApi:true}});
      this.rpc.notify('initialized');
      const result = await this.rpc.call('thread/start',{cwd:this.cwd,ephemeral:true,sandbox:'read-only',approvalPolicy:'never'});
      return result.thread.id;
    })();
    return this.thread;
  }
  async call(server: string, tool: string, args: unknown) {
    const threadId = await this.start();
    return this.rpc!.call('mcpServer/tool/call',{threadId,server,tool,arguments:args});
  }
  close() {this.rpc?.close();}
}

export class McpQueries {
  private rpc?: RpcProcess;
  private ready?: Promise<void>;
  constructor(private command: string, private args: string[], private cwd?: string, private env?: NodeJS.ProcessEnv) {}
  private start(): Promise<void> {
    if (!this.ready) this.ready = (async () => {
      this.rpc = new RpcProcess(this.command,this.args,this.cwd,this.env);
      await this.rpc.call('initialize',{protocolVersion:'2025-06-18',capabilities:{},clientInfo:{name:'F-HyperTUI-queries',version:'0.1.0'}});
      this.rpc.notify('notifications/initialized');
    })();
    return this.ready;
  }
  async listTools() {
    await this.start();
    return this.rpc!.call('tools/list',{});
  }
  async call(tool: string, args: unknown) {
    await this.start();
    return this.rpc!.call('tools/call',{name:tool,arguments:args},tool==='worker_start'?150000:60000);
  }
  close() {this.rpc?.close();}
}
