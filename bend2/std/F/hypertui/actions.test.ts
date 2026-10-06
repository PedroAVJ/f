import {test,expect} from 'bun:test';
import {mkdtemp,writeFile,readFile,rm} from 'node:fs/promises';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {QueryGateway} from './gateway.ts';
import {checkSchema,validate} from './schema.ts';
const metadata=(page:any)=>JSON.parse(page.content.at(-1).text.match(/```json\n([\s\S]*)\n```/)[1]);

test('file mutation follows current-page schema, protects declarations and redirects to readback',async()=>{
 const root=await mkdtemp(join(tmpdir(),'hyper-actions-'));
 const gateway=new QueryGateway([],root,'unused','unused',undefined,{mutations:true});
 try {
  await writeFile(join(root,'fixture.txt'),'before');await writeFile(join(root,'SPEC.bend'),'user-owned declarations');
  const address='hypertui://files/fixture.txt';
  const page=metadata(await gateway.open(address)),action=page.actions[0];
  expect(action.name).toBe('replace_text');
  await expect(gateway.act(address,'replace_text',{expectedSHA256:'stale',text:'after'})).rejects.toThrow('constant');
  await expect(gateway.act('hypertui://files/other.txt','replace_text',{expectedSHA256:action.inputSchema.properties.expectedSHA256.const,text:'after'})).rejects.toThrow('Open');
  const result=await gateway.act(address,'replace_text',{expectedSHA256:action.inputSchema.properties.expectedSHA256.const,text:'after'});
  expect(await readFile(join(root,'fixture.txt'),'utf8')).toBe('after');
  await expect(gateway.act(address,'replace_text',{})).rejects.toThrow('Open');
  const redirect=result.content[0].text.match(/<(hypertui:[^>]+)>/)![1];
  expect((await gateway.open(redirect)).content.some((c:any)=>c.text?.includes('File saved'))).toBe(true);
  expect(metadata(await gateway.open('hypertui://files/SPEC.bend')).actions).toEqual([]);
  for(const name of ['contract.n','N.intent.json','N.intent.sig','.n-intent.json']){await writeFile(join(root,name),'protected');expect(metadata(await gateway.open('hypertui://files/'+name)).actions).toEqual([]);}
 }finally{gateway.close();await rm(root,{recursive:true,force:true});}
});
test('an external edit after navigation rejects the stale file mutation',async()=>{
 const root=await mkdtemp(join(tmpdir(),'hyper-conflict-')),path=join(root,'fixture.txt');
 const gateway=new QueryGateway([],root,'unused','unused',undefined,{mutations:true});
 try {
  await writeFile(path,'first');const page=metadata(await gateway.open('hypertui://files/fixture.txt'));
  await writeFile(path,'concurrent');const result=await gateway.act(page.uri,'replace_text',{expectedSHA256:page.actions[0].inputSchema.properties.expectedSHA256.const,text:'replacement'});
  expect(result.isError).toBe(true);expect(await readFile(path,'utf8')).toBe('concurrent');
 }finally{gateway.close();await rm(root,{recursive:true,force:true});}
});
test('catalog schemas support bounded local references, alternatives and exact object arguments',async()=>{
 const catalog=JSON.parse(await readFile(new URL('../../../../evidence/hypertui/catalog.json',import.meta.url),'utf8'));
 for(const tool of catalog.tools)checkSchema(tool.inputSchema);
 const schema={type:'object',$defs:{value:{anyOf:[{type:'string',pattern:'^[a-z]+$',minLength:2},{type:'integer',minimum:1}]}},properties:{value:{$ref:'#/$defs/value'},mode:{const:'write'}},required:['value','mode'],additionalProperties:false};
 expect(()=>validate(schema,{value:'valid',mode:'write'})).not.toThrow();expect(()=>validate(schema,{value:2,mode:'write'})).not.toThrow();
 expect(()=>validate(schema,{value:'BAD',mode:'write'})).toThrow('allowed schema');expect(()=>validate(schema,{value:'valid',mode:'read'})).toThrow('constant');expect(()=>validate(schema,{value:2,mode:'write',extra:true})).toThrow('Unknown');
 expect(()=>checkSchema({$ref:'https://example.test/schema'})).toThrow('local');
});
