import {createGpuCompute} from './gpu.js';
import {createCanvasRenderer, isStrokeWidth} from './renderer.js';
const LIMIT = 1048576;
const encoder = new TextEncoder();
async function responseText(response) {
  const reader = response.body?.getReader();
  if (!reader) return '';
  const parts = []; let size = 0;
  try {
    for (;;) {
      const {done, value} = await reader.read();
      if (done) break;
      size += value.length;
      if (size > LIMIT) throw Error('response exceeds 1 MiB');
      parts.push(value);
    }
  } finally { await reader.cancel().catch(() => {}); }
  const bytes = new Uint8Array(size); let at = 0;
  for (const part of parts) { bytes.set(part, at); at += part.length; }
  return new TextDecoder().decode(bytes);
}
export function startBend(root, options = {}) {
  const workers = Math.max(1, Math.min(8, options.workers ?? 1));
  const threaded = workers > 1 && crossOriginIsolated && typeof SharedArrayBuffer !== 'undefined';
  const worker = new Worker(new URL('./worker.js', import.meta.url), {type: 'module'});
  const scope = 'bend-' + crypto.randomUUID() + '-';
  const events = [], active = new Map(), messages = [];
  let waiter, stopped = false;
  const notify = m => { messages.push(m); if (messages.length > 256) messages.shift(); options.onMessage?.(m); };
  const compute = createGpuCompute(options, notify);
  const deliver = text => {
    if (stopped) return;
    if (waiter) { const w = waiter; waiter = null; w(text); }
    else if (events.length < 256) events.push(text);
  };
  const renderer = createCanvasRenderer(root, deliver);
  const event = e => {
    const target = e.target.closest('[data-bend-event]');
    if (!target || !root.contains(target) || stopped) return;
    const text = target.dataset.bendEvent;
    deliver(text);
  };
  root.addEventListener('click', event);
  const input = e => {
    const field = e.target.closest('[data-bend-field]');
    if (field && root.contains(field)) deliver(JSON.stringify({action:'field',name:field.dataset.bendField,value:field.value}));
  };
  const upload = async e => {
    const field = e.target.closest('[data-bend-upload]'), file = field?.files?.[0];
    if (!file || !root.contains(field) || stopped) return;
    active.get(field)?.abort(Error('upload superseded'));
    const abort = new AbortController(); active.set(field, abort);
    const timer = setTimeout(() => abort.abort(Error('upload timeout')),60000);
    deliver(JSON.stringify({action:'uploading'}));
    try {
      if (!['image/jpeg','image/png','image/webp'].includes(file.type) || file.size > 20971520) throw Error('Usa una foto JPEG, PNG o WebP de hasta 20 MB.');
      const image = await createImageBitmap(file);
      let blob;
      try {
        const scale = Math.min(1,1280/Math.max(image.width,image.height));
        const canvas = document.createElement('canvas'); canvas.width=Math.max(1,Math.round(image.width*scale));canvas.height=Math.max(1,Math.round(image.height*scale));
        canvas.getContext('2d').drawImage(image,0,0,canvas.width,canvas.height);
        blob = await new Promise(resolve=>canvas.toBlob(resolve,'image/jpeg',0.85));
      } finally { image.close(); }
      if (!blob || blob.size > 786432) throw Error('La foto es demasiado grande. Prueba una foto más cercana.');
      const target = new URL(field.dataset.bendUpload,location.href);
      if (target.origin!==location.origin) throw Error('upload must use the application origin');
      const body = new FormData(); body.set('photo',blob,'upload.jpg');body.set('request_id',crypto.randomUUID());
      const response=await fetch(target,{method:'POST',body,signal:abort.signal});
      const text=await responseText(response);
      if (!response.ok) throw Error(JSON.parse(text).error || 'No se pudo leer la foto.');
      if (active.get(field) === abort) deliver(JSON.stringify({action:'uploaded',data:JSON.parse(text)}));
    } catch(error) { if (active.get(field) === abort) deliver(JSON.stringify({action:'error',error:String(error.message || error)})); }
    finally { clearTimeout(timer); if (active.get(field) === abort) active.delete(field); }
  };
  root.addEventListener('input',input); root.addEventListener('change',upload);
  const bounded = text => {
    if (encoder.encode(text).length > LIMIT) throw Error('message exceeds 1 MiB');
    return text;
  };
  async function request(operation, data, signal) {
    bounded(data);
    if (operation === 1) {
      const view = document.createElement('template'); view.innerHTML = data;
      for (const node of view.content.querySelectorAll('[data-bend-stroke-width]')) {
        if (!isStrokeWidth(node.dataset.bendStrokeWidth)) throw Error('invalid F stroke width');
      }
      // Isolate generated SVG resources when multiple compiled apps share a page.
      const ids = new Map();
      for (const node of view.content.querySelectorAll('[id^="bend-fill-"]')) {
        ids.set(node.id,scope+node.id); node.id=scope+node.id;
      }
      for (const node of view.content.querySelectorAll('[fill]')) {
        const match=/^url\(#(bend-fill-[^)]+)\)$/.exec(node.getAttribute('fill'));
        if (match && ids.has(match[1])) node.setAttribute('fill','url(#'+ids.get(match[1])+')');
      }
      root.replaceChildren(view.content); return '';
    }
    if (operation === 2) {
      if (events.length) return events.shift();
      if (waiter) throw Error('an event request is already pending');
      return await new Promise((resolve, reject) => {
        waiter = resolve;
        signal.addEventListener('abort', () => { waiter = null; reject(signal.reason); }, {once: true});
      });
    }
    if (operation === 3 || operation === 6) {
      const spec = operation === 6 ? JSON.parse(data) : {url:data};
      const url = new URL(spec.url,location.href);
      const response = await fetch(url, {signal, ...(operation === 6 ? {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(spec.body)} : {})});
      if (!response.ok) { const text=await responseText(response);let message;try{message=JSON.parse(text).error;}catch{}throw Error(message || `HTTP ${response.status}`); }
      return await responseText(response);
    }
    if (operation === 5) return await compute(data, signal);
    if (operation === 4) return await renderer.paint(data, signal);
    throw Error(`unsupported browser operation ${operation}`);
  }
  worker.onmessage = async ({data: m}) => {
    if (stopped) return;
    if (m.type !== 'request') { notify(m); return; }
    if (active.size >= 64) { worker.postMessage({type:'reply', id:m.id, reply:{status:2,data:'too many pending requests'}}); return; }
    const abort = new AbortController(); active.set(m.id, abort);
    const timeout = m.operation === 2 ? null : setTimeout(() => abort.abort(Error('request timeout')), 30000);
    let reply;
    try { reply = {status:1, data:bounded(await request(m.operation, m.data, abort.signal))}; }
    catch (e) { reply = {status:abort.signal.aborted ? 3 : 2, data:String(e?.message || e)}; }
    finally { clearTimeout(timeout); active.delete(m.id); }
    if (!stopped) worker.postMessage({type:'reply', id:m.id, reply});
  };
  worker.onerror = e => notify({type:'error',text:e.message});
  worker.postMessage({type:'start', threaded, workers:threaded ? workers : 1});
  return {
    messages, workers:threaded ? workers : 1, threaded,
    cancelPending() { for (const abort of active.values()) abort.abort(Error('cancelled')); },
    stop() {
      stopped = true; root.removeEventListener('click', event); root.removeEventListener('input',input);root.removeEventListener('change',upload);
      compute.close(); renderer.close();
      for (const abort of active.values()) abort.abort(Error('stopped'));
      active.clear(); events.length = 0; worker.postMessage({type:'stop'});
      setTimeout(() => worker.terminate(), 100);
    }
  };
}
