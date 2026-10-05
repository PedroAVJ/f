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
// Keep compatible browser nodes; Bend still chooses every rendered value.
function domKey(node) {
  if (node.nodeType !== 1) return null;
  for (const name of ['id','data-bend-field','data-bend-upload','data-bend-event']) {
    if (node.hasAttribute(name)) return name + ':' + node.getAttribute(name);
  }
  // Labels follow their control; general containers keep positional identity.
  const field = node.nodeName === 'LABEL' && node.querySelector('[data-bend-field],[data-bend-upload]');
  return field ? 'field-label:' + domKey(field) : null;
}
function compatible(a, b) {
  return a.nodeType === b.nodeType && a.nodeName === b.nodeName &&
    a.namespaceURI === b.namespaceURI && domKey(a) === domKey(b) &&
    (a.nodeName !== 'INPUT' || a.type === b.type);
}
function reconcile(parent, next, edits, composing, requestId) {
  const before = [...parent.childNodes], after = [...next.childNodes];
  const used = new Set(), keyed = new Map(), reserved = new Map(), held = new Set();
  for (const node of before) {
    const key = domKey(node);
    if (key !== null) keyed.set(key, keyed.has(key) ? null : node);
  }
  // Reserve unchanged branches before positional matching can consume them.
  for (const fresh of after) if (domKey(fresh) === null) {
    const node = before.find(n => !held.has(n) && compatible(n,fresh) && n.isEqualNode(fresh));
    if (node) { reserved.set(fresh,node); held.add(node); }
  }
  // Changed containers can still contain the same retained controls/IDs.
  const anchors = node => node.nodeType === 1 ? new Set([...node.querySelectorAll('[id],[data-bend-field],[data-bend-upload],[data-bend-event]')].map(domKey)) : new Set();
  for (const fresh of after) if (domKey(fresh) === null && !reserved.has(fresh)) {
    const keys = anchors(fresh);let score=0, match;
    for (const node of before) if (!held.has(node) && compatible(node,fresh)) {
      const shared = [...anchors(node)].filter(k => keys.has(k)).length;
      if (shared > score) { score=shared;match=node; }
    }
    if (match) { reserved.set(fresh,match); held.add(match); }
  }
  for (const [index, fresh] of after.entries()) {
    const key = domKey(fresh);
    let node = key === null ? reserved.get(fresh) || before[index] : keyed.get(key);
    if (held.has(node) && reserved.get(fresh) !== node) node = null;
    if (!node || used.has(node) || !compatible(node,fresh)) {
      node = key === null ? before.find(n => !used.has(n) && !held.has(n) && domKey(n) === null && compatible(n,fresh)) : null;
    }
    if (!node) { parent.insertBefore(fresh,parent.childNodes[index] || null); continue; }
    used.add(node);
    const current = parent.childNodes[index];
    if (current !== node) {
      if (parent.moveBefore) parent.moveBefore(node,current || null);
      else if (node.contains?.(document.activeElement)) {
        // Move intervening siblings, never detach the active/composing branch.
        const end = [...parent.childNodes].indexOf(node);
        for (const sibling of [...parent.childNodes].slice(index,end).reverse()) parent.insertBefore(sibling,node.nextSibling);
      } else parent.insertBefore(node,current || null);
    }
    if (node.nodeType !== 1) { if (node.nodeValue !== fresh.nodeValue) node.nodeValue = fresh.nodeValue; continue; }
    const edit = edits.get(node), pending = edit && requestId <= edit.delivered;
    for (const attr of [...node.attributes]) if (!fresh.hasAttribute(attr.name) &&
      !(attr.name === 'value' && (pending || composing.has(node)))) node.removeAttribute(attr.name);
    for (const attr of fresh.attributes) {
      if (attr.name === 'value' && (pending || composing.has(node))) continue;
      if (node.getAttribute(attr.name) !== attr.value) node.setAttribute(attr.name,attr.value);
    }
    if ((node.nodeName === 'INPUT' || node.nodeName === 'TEXTAREA') && node.type !== 'file') {
      if (!pending && !composing.has(node)) {
        if (node.value !== fresh.value) node.value = fresh.value;
        edits.delete(node);
      }
      if (node.checked !== fresh.checked) node.checked = fresh.checked;
    }
    if (node.nodeName !== 'TEXTAREA' || !(pending || composing.has(node)))
      reconcile(node,fresh,edits,composing,requestId);
  }
  for (const node of before) if (!used.has(node) && node.parentNode === parent) node.remove();
}
export function startBend(root, options = {}) {
  const workers = Math.max(1, Math.min(8, options.workers ?? 1));
  const threaded = workers > 1 && crossOriginIsolated && typeof SharedArrayBuffer !== 'undefined';
  const worker = new Worker(new URL('./worker.js', import.meta.url), {type: 'module'});
  const scope = 'bend-' + crypto.randomUUID() + '-';
  const events = [], active = new Map(), messages = [];
  const edits = new WeakMap(), composing = new WeakSet();
  let waiter, stopped = false;
  const notify = m => { messages.push(m); if (messages.length > 256) messages.shift(); options.onMessage?.(m); };
  const compute = createGpuCompute(options, notify);
  const consume = (entry, id) => {
    const edit = entry.field && edits.get(entry.field);
    if (edit?.version === entry.version) edit.delivered = id;
    host?.eventConsumed?.(entry.text);
    return entry.text;
  };
  const deliver = (text, field, version) => {
    if (stopped) return;
    const entry = {text, field, version};
    if (waiter) { const w = waiter; waiter = null; w(entry); }
    else if (events.length < 256) events.push(entry);
  };
  const renderer = createCanvasRenderer(root, deliver);
  const host = options.host?.({root, deliver});
  // A textbox's text outlives the page: each edit is kept in localStorage by the textbox's name, and a
  // textbox that appears empty gets its kept text back as an edit, so Bend keeps it in the input's state.
  const store = (() => { try { return localStorage; } catch { return null; } })();
  const kept = field => 'bend-input:' + field.dataset.bendField, restored = new WeakSet();
  let painting = false;
  const event = e => {
    const target = e.target.closest('[data-bend-event]');
    if (!target || !root.contains(target) || stopped) return;
    const text = target.dataset.bendEvent;
    deliver(text);
  };
  root.addEventListener('click', event);
  const input = e => {
    const field = e.target.closest('[data-bend-field]');
    if (field && root.contains(field)) {
      const version = (edits.get(field)?.version || 0) + 1;
      edits.set(field,{version,delivered:Infinity});
      deliver(JSON.stringify({action:'field',name:field.dataset.bendField,value:field.value}),field,version);
      try { field.value ? store?.setItem(kept(field),field.value) : store?.removeItem(kept(field)); } catch {}
    }
  };
  const restore = () => {
    for (const field of root.querySelectorAll('input[data-bend-field],textarea[data-bend-field]')) {
      if (restored.has(field)) continue;
      restored.add(field);
      let text = null;
      try { text = store?.getItem(kept(field)); } catch {}
      if (text && !field.value) { field.value = text; input({target:field}); }
    }
  };
  // Focus is the textbox's own state too: Bend draws it from these events (a repaint's own moves send none).
  const focus = e => {
    const field = e.target.closest?.('[data-bend-field]');
    if (field && root.contains(field) && !painting && !stopped)
      deliver(JSON.stringify({action:e.type === 'focusin' ? 'focus' : 'blur',name:field.dataset.bendField}));
  };
  root.addEventListener('focusin',focus); root.addEventListener('focusout',focus);
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
    finally {
      clearTimeout(timer);
      if (active.get(field) === abort) { active.delete(field); field.value = ''; }
    }
  };
  const composition = e => {
    const field = e.target.closest('[data-bend-field]');
    if (field && root.contains(field)) {
      if (e.type === 'compositionstart') composing.add(field);
      else composing.delete(field);
    }
  };
  root.addEventListener('compositionstart',composition);root.addEventListener('compositionend',composition);
  root.addEventListener('input',input); root.addEventListener('change',upload);
  const bounded = text => {
    if (encoder.encode(text).length > LIMIT) throw Error('message exceeds 1 MiB');
    return text;
  };
  async function request(operation, data, signal, requestId) {
    bounded(data);
    const hosted = await host?.request?.(operation, data, signal, requestId);
    if (hosted !== undefined) return hosted;
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
      const focused = root.contains(document.activeElement) ? document.activeElement : null;
      const selection = focused && typeof focused.selectionStart === 'number'
        ? [focused.selectionStart,focused.selectionEnd,focused.selectionDirection] : null;
      painting = true;
      try {
        reconcile(root,view.content,edits,composing,requestId);
        if (focused && root.contains(focused)) {
          if (document.activeElement !== focused) focused.focus({preventScroll:true});
          if (selection && !composing.has(focused) &&
            (focused.selectionStart !== selection[0] || focused.selectionEnd !== selection[1] || focused.selectionDirection !== selection[2]))
            focused.setSelectionRange(...selection);
        }
      } finally { painting = false; }
      restore();
      host?.rendered?.();
      return '';
    }
    if (operation === 2) {
      if (events.length) return consume(events.shift(),requestId);
      if (waiter) throw Error('an event request is already pending');
      return await new Promise((resolve, reject) => {
        waiter = entry => resolve(consume(entry,requestId));
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
    try { reply = {status:1, data:bounded(await request(m.operation, m.data, abort.signal, m.id))}; }
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
      root.removeEventListener('focusin',focus);root.removeEventListener('focusout',focus);
      root.removeEventListener('compositionstart',composition);root.removeEventListener('compositionend',composition);
      compute.close(); renderer.close();
      host?.close?.();
      for (const abort of active.values()) abort.abort(Error('stopped'));
      active.clear(); events.length = 0; worker.postMessage({type:'stop'});
      setTimeout(() => worker.terminate(), 100);
    }
  };
}
