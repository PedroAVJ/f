import {createInterface} from 'node:readline';
import {readFile} from 'node:fs/promises';
import {QueryGateway} from './gateway.ts';
import {McpQueries} from './backend.ts';
import {validate} from './schema.ts';
const object=(properties:Record<string,unknown>)=>({type:'object',properties,required:Object.keys(properties),additionalProperties:false});
const navigation={name:'hyperTUI',description:'Open a program page at hypertui://programs/. Page links are reads; mutations are current-page actions. Search retained conversation via hypertui://conversation/?q=WORDS (optional before=message-index).',inputSchema:object({uri:{type:'string'}}),annotations:{readOnlyHint:true}};
const mutation={name:'hyperTUI_action',description:'Invoke an action advertised by the current page, then open its redirect. Never retry an uncertain mutation without checking the source.',inputSchema:object({uri:{type:'string'},name:{type:'string'},arguments:{type:'object'}})};
export async function archive(sessionFile:string,uri:string) {
  const u=new URL(uri),q=(u.searchParams.get('q')??'').toLowerCase();
  const saved=JSON.parse(await readFile(sessionFile,'utf8'));
  const messages=saved.threads.find((t:any)=>t.id===saved.selectedThreadId).messages;
  const rawBefore=u.searchParams.get('before'),before=rawBefore===null?messages.length:Number(rawBefore);
  if(!Number.isInteger(before)||before<0)throw Error('before must be a nonnegative message index.');
  const hits=[];
  for(let i=Math.min(before,messages.length)-1;i>=0&&hits.length<6;i--) {
    const m=messages[i],text=String(m.text??m.audio?.transcript??'');
    const index=text.toLowerCase().indexOf(q);
    if(index<0)continue;
    const start=Math.max(0,index-300);
    hits.push({index:i,role:m.role,text:text.slice(start,start+1600),excerpt:text.length>1600});
  }
  return {content:[{type:'text',text:JSON.stringify({contextOnly:true,messages:hits.reverse(),nextBefore:hits.length?hits[0].index:null})}]};
}
if(import.meta.main) {
  const config=JSON.parse(await readFile(process.argv[2],'utf8'));
  const catalog=JSON.parse(await readFile(config.catalog,'utf8'));
  const entries=catalog.tools;
  const gateway=new QueryGateway(entries,config.workspace,config.codex,config.claude,undefined,{...config,compact:true});
  const binding=config.presenter;
  const presenter=binding?new McpQueries(binding.command,binding.args,binding.cwd??config.workspace,binding.env):undefined;
  let uiTool:any;
  const lines=createInterface({input:process.stdin,crlfDelay:Infinity});
  const close=()=>{gateway.close();presenter?.close();lines.close();};
  process.once('SIGINT',close);process.once('SIGTERM',close);
  try {for await(const line of lines) {
    let message:any;
    try {
      message=JSON.parse(line);if(message.id===undefined)continue;
      let result:any;
      if(message.method==='initialize')result={protocolVersion:'2025-06-18',capabilities:{tools:{listChanged:true}},serverInfo:{name:'OpenDot conversation tools',version:'1'}};
      else if(message.method==='ping')result={};
      else if(message.method==='tools/list') {
        if(presenter&&!uiTool)uiTool=(await presenter.listTools()).tools.find((t:any)=>t.name==='present_ui');
        result={tools:[navigation,mutation,...gateway.actionTools(),...(uiTool?[uiTool]:[])]};
      } else if(message.method==='tools/call') {
        const {name,arguments:args={}}=message.params;
        if(name==='hyperTUI') {
          validate(navigation.inputSchema,args);
          if(new URL(args.uri).hostname==='conversation'){gateway.clearActions();result=await archive(config.sessionFile,args.uri);}
          else result=await gateway.open(args.uri);
        } else if(name==='hyperTUI_action') {
          validate(mutation.inputSchema,args);
          result=await gateway.act(args.uri,args.name,args.arguments);
        } else if(/^p[0-9]+_/.test(name))result=await gateway.callActionTool(name,args);
        else if(name==='present_ui'&&presenter) result=await presenter.call(name,args);
        else throw Error('This tool is unavailable in the conversation agent.');
      } else throw Error('Unknown method.');
      process.stdout.write(JSON.stringify({jsonrpc:'2.0',id:message.id,result})+'\n');
      if(message.method==='tools/call'&&message.params.name!=='present_ui')process.stdout.write(JSON.stringify({jsonrpc:'2.0',method:'notifications/tools/list_changed'})+'\n');
    } catch(error) {
      process.stdout.write(JSON.stringify({jsonrpc:'2.0',id:message?.id??null,result:{isError:true,content:[{type:'text',text:error instanceof Error?error.message:String(error)}]}})+'\n');
      if(message?.method==='tools/call'&&message.params?.name!=='present_ui')process.stdout.write(JSON.stringify({jsonrpc:'2.0',method:'notifications/tools/list_changed'})+'\n');
    }
  }} finally {close();}
}
