// Only raw bytes -> checked Bend List<U32>; no provider decoding.
function native_bytes(handle) {
  const host=globalThis[Symbol.for('near-v.native-host.v1')];
  const empty=()=>({$:CID(Nil)});
  const fail=()=>({$:CID(ByteReply),status:4,handle:0,bytes:empty()});
  if(!host||typeof host.dispatch!=='function')return fail();
  const asyncMode=host.async===true;
  if(asyncMode&&globalThis[Symbol.for('near-v.native-io.async.v1')]!==true)return fail();
  function pack(reply) {
    if(!reply||![1,2,3,4].includes(reply.status)||!Number.isInteger(reply.handle)||reply.handle<0||reply.handle>0xffffffff
      ||!(Array.isArray(reply.bytes)||reply.bytes instanceof Uint8Array)||reply.bytes.length>1048576
      ||!Array.from(reply.bytes).every(n=>Number.isInteger(n)&&n>=0&&n<=255))return fail();
    let bytes=empty();
    if(reply.status!==4)for(let i=reply.bytes.length-1;i>=0;i--)bytes={$:CID(Con),head:reply.bytes[i],tail:bytes};
    return {$:CID(ByteReply),status:reply.status,handle:reply.handle,bytes};
  }
  try {
    const reply=host.dispatch('stream.read_bytes',[handle]);
    if(asyncMode)return Promise.resolve(reply).then(pack,fail);
    if(reply&&typeof reply.then==='function'){reply.catch?.(()=>{});return fail();}
    return pack(reply);
  }catch{return fail();}
}
io_eff(CID(stream_read_bytes_raw),native_bytes);
