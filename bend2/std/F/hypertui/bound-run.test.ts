import {test,expect} from 'bun:test';
import {QueryGateway} from './gateway.ts';
const metadata=(page:any)=>JSON.parse(page.content.at(-1).text.match(/```json\n([\s\S]*)\n```/)[1]);
test('issue run links bind exactly one runId and reject a different dispatch',async()=>{
 const id='12345678-1234-1234-1234-123456789abc',address='hypertui://program/codex/dispatch?runId='+id,calls:any[]=[],gateway=new QueryGateway([],process.cwd(),'unused','unused',undefined,{mutations:true,remoteOnly:true});
 (gateway as any).programs.set('codex',{listTools:async()=>({tools:[{name:'dispatch',description:'Dispatch queued issue',inputSchema:{type:'object',properties:{runId:{type:'string'}},required:['runId'],additionalProperties:false}}]}),call:async(name:string,args:any)=>{calls.push({name,args});return{content:[{type:'text',text:'Dispatched exact run.'}]}},close(){}});
 try {const page=metadata(await gateway.open(address));expect(page.actions[0].inputSchema.properties.runId.const).toBe(id);expect(calls.length).toBe(0);await expect(gateway.act(address,'run',{runId:'other'})).rejects.toThrow('constant');await gateway.act(address,'run',{runId:id});expect(calls).toEqual([{name:'dispatch',args:{runId:id}}]);}finally{gateway.close();}
});
