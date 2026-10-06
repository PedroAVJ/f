import { spawn } from 'node:child_process';
import { mkdtemp, readFile, rm, open } from 'node:fs/promises';
import { constants } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, extname } from 'node:path';
import type { Content } from './render.ts';

const formats:Record<string,string>={'.mp4':'mov','.mov':'mov','.m4v':'mov','.mkv':'matroska','.webm':'matroska','.mp3':'mp3','.wav':'wav','.flac':'flac','.ogg':'ogg','.m4a':'mov'};
const videos = new Set(['.mp4','.mov','.m4v','.mkv','.webm']);
export const isMedia = (path:string) => extname(path).toLowerCase() === '.pdf' || !!formats[extname(path).toLowerCase()];
const run = (command:string,args:string[],fd:number) => new Promise<string>((resolve,reject) => {
  const child=spawn(command,args,{stdio:['ignore','pipe','pipe',fd]});
  let stdout='',stderr='',size=0;
  const timer=setTimeout(()=>{child.kill();reject(Error(command+' timed out.'));},20000);
  child.stdout!.on('data',chunk=>{size+=chunk.length;if(size>1024*1024){child.kill();reject(Error('Media metadata exceeds 1 MiB.'));}else stdout+=chunk;});
  child.stderr!.on('data',chunk=>{stderr=(stderr+chunk).slice(-500);});
  child.on('error',error=>{clearTimeout(timer);reject(error);});
  child.on('close',code=>{clearTimeout(timer);code===0?resolve(stdout):reject(Error(command+' failed: '+stderr));});
});
export async function mediaPage(file:string, fd:number, url:URL) {
  const directory=await mkdtemp(join(tmpdir(),'f-media-'));
  const extension=extname(file).toLowerCase(), blocks:any[]=[], images=new Map<string,Content>();
  const addLink=(label:string,key:string,value:number) => {const target=new URL(url);target.searchParams.set(key,String(value));blocks.push({kind:'link',label,uri:target.href});};
  try {
    let imagePath:string;
    if (extension === '.pdf') {
      const metadata=await run('/opt/homebrew/bin/pdfinfo',['/dev/fd/3'],fd);
      const pages=Number(metadata.match(/^Pages:\s+(\d+)/m)?.[1]);
      const page=Number(url.searchParams.get('page') ?? 1);
      if (!Number.isInteger(page) || page<1 || page>pages) throw Error('PDF page is outside the document.');
      blocks.push({kind:'text',text:`Page ${page} of ${pages}`},{kind:'code',text:metadata});
      const target=join(directory,'page');
      await run('/opt/homebrew/bin/pdftoppm',['-f',String(page),'-l',String(page),'-singlefile','-scale-to','1400','-png','/dev/fd/3',target],fd);
      imagePath=target+'.png';
      if (page>1) addLink('Previous page','page',page-1);
      if (page<pages) addLink('Next page','page',page+1);
    } else {
      const format=formats[extension], base=['-v','error','-protocol_whitelist','file,pipe','-f',format];
      const metadata=JSON.parse(await run('/opt/homebrew/bin/ffprobe',[...base,'-show_format','-show_streams','-of','json','/dev/fd/3'],fd));
      const duration=Number(metadata.format?.duration), time=Number(url.searchParams.get('t') ?? 0);
      if (!Number.isFinite(duration) || !Number.isFinite(time) || time<0 || time>=duration) throw Error('Seek time is outside the media duration.');
      blocks.push({kind:'text',text:`${videos.has(extension)?'Video frame':'Audio waveform'} at ${time}s of ${duration.toFixed(2)}s`},{kind:'code',language:'json',text:JSON.stringify(metadata,null,2)});
      imagePath=join(directory,'frame.png');
      const filter=videos.has(extension) ? ['-vf','scale=1400:-2'] : ['-filter_complex','aformat=channel_layouts=mono,showwavespic=s=1400x240:colors=2980b9'];
      await run('/opt/homebrew/bin/ffmpeg',[...base,'-threads','1','-filter_threads','1','-filter_complex_threads','1','-ss',String(time),...(!videos.has(extension)?['-t',String(Math.min(30,duration-time))]:[]),'-i','/dev/fd/3',...filter,'-frames:v','1','-threads','1',imagePath],fd);
      if (!videos.has(extension)) {
        let transcript:string;
        try {
          const handle=await open(file+'.txt',constants.O_RDONLY|constants.O_NOFOLLOW|constants.O_NONBLOCK);
          try {const stat=await handle.stat();if(!stat.isFile()||stat.size>1024*1024) throw Error('Transcript sidecar must be a file below 1 MiB.');transcript=await handle.readFile('utf8');} finally {await handle.close();}
        } catch(error) {if((error as NodeJS.ErrnoException).code!=='ENOENT') throw error;transcript='No transcript sidecar is available. Add a .txt sidecar to this audio file to display its transcript.';}
        blocks.push({kind:'code',text:transcript});
      }
      if(time>0) addLink('Seek backward','t',Math.max(0,time-10));
      if(time+10<duration) addLink('Seek forward','t',time+10);
      addLink('Start','t',0);
    }
    const bytes=await readFile(imagePath);
    if(bytes.length>8*1024*1024) throw Error('Rendered image exceeds 8 MiB.');
    images.set('image:media',{type:'image',mimeType:'image/png',data:bytes.toString('base64')});
    blocks.push({kind:'image',label:extension==='.pdf'?'Rendered PDF page':videos.has(extension)?'Video frame':'Audio waveform',asset:'image:media'});
    return {blocks,images};
  } finally {await rm(directory,{recursive:true,force:true});}
}
