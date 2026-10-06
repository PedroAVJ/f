import {test,expect} from 'bun:test';
import {mkdtemp,writeFile,symlink,rm,open} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {execFileSync} from 'node:child_process';
import {QueryGateway} from './gateway.ts';
import {codexPolicy,claudePolicy} from './policy.ts';
import {mediaPage} from './media.ts';

test('query catalog does not permit mutation calls or escape workspace',async()=>{
 const root=await mkdtemp(join(tmpdir(),'hyper-test-'));
 const gateway=new QueryGateway([{backend:'codex',server:'test',name:'delete',class:'mutation',description:'',inputSchema:{}}],root,'unused','unused');
 try {
  await writeFile(join(root,'code.ts'),'const fenced = "```";');await symlink('/etc/hosts',join(root,'outside'));
  const result=await gateway.open('hypertui://files/code.ts');
  expect(result.content.some((v:any)=>v.text?.includes('````ts\nconst fenced'))).toBe(true);
  await expect(gateway.open('hypertui://files/outside')).rejects.toThrow('outside');
  await expect(gateway.open('hypertui://tools/codex/test/delete?args=%7B%7D')).rejects.toThrow('Only cataloged');
 } finally {gateway.close();await rm(root,{recursive:true,force:true});}
});
test('installed harness policies retain mutations and mixed tools and disable only queries',()=>{
 const entries:any[]=[{backend:'codex',server:'notes',name:'read',class:'query'},{backend:'codex',server:'notes',name:'write',class:'mutation'},{backend:'codex',server:'notes',name:'execute',class:'mixed'},{backend:'chrome',name:'read_page',class:'query'},{backend:'chrome',name:'computer',class:'mixed'}];
 const args=codexPolicy(entries,[{name:'notes',enabled:true,transport:{type:'stdio',command:'notes',args:[]}}]);
 expect(args.join(' ')).toContain('"enabled_tools"=["write","execute"]');expect(args.join(' ')).not.toContain('plugins.');
 expect(claudePolicy(entries)).toEqual(['--disallowedTools','mcp__claude-in-chrome__read_page']);
});
test('real media decoders render seekable audio and video images',async()=>{
 const root=await mkdtemp(join(tmpdir(),'hyper-media-test-'));
 try {
  for(const [name,args] of [['sample.wav',['-f','lavfi','-i','sine=frequency=300:duration=11']],['sample.mp4',['-f','lavfi','-i','color=c=red:s=160x100:d=11','-c:v','libx264']]] as const) {
   const path=join(root,name);execFileSync('/opt/homebrew/bin/ffmpeg',['-v','error',...args,'-threads','1',path]);
   if(name.endsWith('wav')) await writeFile(path+'.txt','Fixture transcript.');
   const handle=await open(path,'r');
   try {const page=await mediaPage(path,handle.fd,new URL('hypertui://files/'+name));expect(page.images.get('image:media')?.type).toBe('image');expect(page.blocks.some(v=>v.uri?.includes('t=10'))).toBe(true);if(name.endsWith('wav'))expect(page.blocks.some(v=>v.text==='Fixture transcript.')).toBe(true);} finally {await handle.close();}
  }
 } finally {await rm(root,{recursive:true,force:true});}
},30000);
