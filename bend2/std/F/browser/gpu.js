// Generic browser transport. Kernel arithmetic is compiler-generated WGSL;
// rejected/offline dispatches return to the Bend implementation in Wasm.
export function createGpuCompute(options = {}, notify = () => {}) {
  let devicePromise, disabled = false, active = 0;
  const pipelines = new Map();
  const decision = (backend, reason, count) =>
    notify({type:'placement',backend,reason,count});
  const unavailable = (reason, count) => { decision('cpu', reason, count); const e = Error(reason); e.placement = true; throw e; };
  async function device() {
    if (disabled || options.gpu === false || !navigator.gpu) return null;
    if (!devicePromise) devicePromise = (async () => {
      const adapter = await navigator.gpu.requestAdapter();
      if (!adapter) return null;
      const d = await adapter.requestDevice();
      d.lost.then(info => { disabled = true; pipelines.clear(); notify({type:'gpu-lost', reason:info.reason, text:info.message}); });
      return d;
    })().catch(() => null);
    return devicePromise;
  }
  const pending = (promise, signal) => new Promise((resolve, reject) => {
    const aborted = () => reject(signal.reason || Error('cancelled'));
    Promise.resolve(promise).then(resolve,reject).finally(() => signal.removeEventListener('abort', aborted));
    if (signal.aborted) return aborted();
    signal.addEventListener('abort', aborted, {once:true});
  });
  const compute = async function compute(data, signal) {
    const packet = JSON.parse(data), {shader, values} = packet;
    const count = values?.length;
    if (typeof shader !== 'string' || shader.length > 65536 || !Array.isArray(values) || count > 65536 ||
      !values.every(v => Number.isInteger(v) && v >= 0 && v <= 4294967295)) throw Error('invalid compute packet');
    if (active >= 1) return unavailable('dispatch queue full', count);
    if (signal.aborted) throw signal.reason;
    active++;
    let d, input, output, readback, scoped = false;
    try {
      d = await pending(device(), signal);
      if (!d || disabled) return unavailable('WebGPU unavailable', count);
      const bytes = count * 4;
      if (bytes > d.limits.maxStorageBufferBindingSize || bytes > d.limits.maxBufferSize ||
        Math.ceil(count / 64) > d.limits.maxComputeWorkgroupsPerDimension) return unavailable('device limits', count);
      if (signal.aborted) throw signal.reason;
      d.pushErrorScope('validation'); scoped = true;
      let pipeline = pipelines.get(shader);
      if (!pipeline) {
        const module = d.createShaderModule({code:shader});
        const info = await pending(module.getCompilationInfo(), signal);
        if (info.messages.some(m => m.type === 'error')) throw Error('WGSL compilation failed: ' + info.messages.filter(m => m.type === 'error').map(m => m.message).join('; '));
        pipeline = await pending(d.createComputePipelineAsync({layout:'auto',compute:{module,entryPoint:'main'}}), signal);
        if (pipelines.size < 32) pipelines.set(shader, pipeline);
      }
      input = d.createBuffer({size:bytes,usage:GPUBufferUsage.STORAGE|GPUBufferUsage.COPY_DST});
      output = d.createBuffer({size:bytes,usage:GPUBufferUsage.STORAGE|GPUBufferUsage.COPY_SRC});
      readback = d.createBuffer({size:bytes,usage:GPUBufferUsage.COPY_DST|GPUBufferUsage.MAP_READ});
      d.queue.writeBuffer(input, 0, Uint32Array.from(values));
      const bindings = d.createBindGroup({layout:pipeline.getBindGroupLayout(0),entries:[
        {binding:0,resource:{buffer:input}},{binding:1,resource:{buffer:output}}]});
      const encoder = d.createCommandEncoder(), pass = encoder.beginComputePass();
      pass.setPipeline(pipeline); pass.setBindGroup(0,bindings); pass.dispatchWorkgroups(Math.ceil(count / 64)); pass.end();
      encoder.copyBufferToBuffer(output,0,readback,0,bytes); d.queue.submit([encoder.finish()]);
      await pending(readback.mapAsync(GPUMapMode.READ), signal);
      if (signal.aborted) throw signal.reason;
      const result = Array.from(new Uint32Array(readback.getMappedRange()));
      readback.unmap();
      const scope = d.popErrorScope(); scoped = false;
      const error = await pending(scope, signal);
      if (error || disabled) throw Error(error?.message || 'WebGPU device lost');
      decision('gpu', 'eligible kernel', count);
      return JSON.stringify(result);
    } catch (e) {
      if (!e?.placement) decision('cpu', signal.aborted ? 'cancelled GPU dispatch' : String(e?.message || e), count);
      throw e;
    } finally {
      if (scoped) await pending(d.popErrorScope(), signal).catch(() => {});
      input?.destroy(); output?.destroy(); readback?.destroy(); active--;
    }
  };
  compute.close = () => { disabled = true; pipelines.clear(); devicePromise?.then(d => d?.destroy()); };
  return compute;
}
