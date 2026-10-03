// Generic checked multipart ABI. Bend owns every provider field and result codec.
function native_multipart(credential,url,headers,fields,filename,mimeType,bytes) {
 const host=globalThis[Symbol.for('near-v.native-host.v1')];
 const failure=()=>({$:CID(Reply),status:4,handle:0,data:'transport unavailable'});
 if(!host||typeof host.dispatch!=='function')return failure();
 const asyncMode=host.async===true;
 if(asyncMode&&globalThis[Symbol.for('near-v.native-io.async.v1')]!==true)return failure();
 try {
  const form=[];let field=fields;
  while(field?.$===CID(Con)){if(form.length>=64||field.head?.$!==CID(FormField)||typeof field.head.name!=='string'||typeof field.head.value!=='string')return failure();form.push({name:field.head.name,value:field.head.value});field=field.tail}
  if(field?.$!==CID(Nil))return failure();
  const upload=[];let byte=bytes;
  while(byte?.$===CID(Con)){if(upload.length>=33554432||!Number.isInteger(byte.head)||byte.head<0||byte.head>255)return failure();upload.push(byte.head);byte=byte.tail}
  if(byte?.$!==CID(Nil)||!upload.length)return failure();
  const pack=reply=>!reply||![1,2,3,4].includes(reply.status)||!Number.isInteger(reply.handle)||reply.handle<0||reply.handle>0xffffffff||typeof reply.data!=='string'?failure():({$:CID(Reply),status:reply.status,handle:reply.handle,data:reply.status===4?'transport failed':reply.data});
  const result=host.dispatch('http.multipart_open',[credential,url,headers,form,filename,mimeType,upload]);
  if(asyncMode)return Promise.resolve(result).then(pack,failure);
  if(result&&typeof result.then==='function'){result.catch?.(()=>{});return failure()}
  return pack(result);
 }catch{return failure()}
}
io_eff(CID(http_multipart_open_raw),native_multipart);
