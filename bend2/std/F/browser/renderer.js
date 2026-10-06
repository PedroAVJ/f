// Private browser painting adapter. Positions, token colours, text, component
// state and sprite frames are values produced by Bend/Wasm, not JS app logic.
const MAX = 4096;
const number = x => Number.isFinite(x) && x >= 0 && x <= 4294967295;
const numeric = x => (typeof x === 'string' || typeof x === 'number') && number(Number(x));
export const isStrokeWidth = x => typeof x === 'string' && /^\+?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?$/.test(x) && number(Number(x));
const string = x => typeof x === 'string';
function checkShape(c) {
  const [, name, x, y, width, height, geometry, fill, stroke, effects] = c;
  if (c.length !== 10 || !string(name) || ![x,y,width,height].every(number) ||
    !Array.isArray(geometry) || !Array.isArray(fill) || !Array.isArray(stroke) || !Array.isArray(effects)) throw Error('invalid F shape packet');
  const [g,...gs] = geometry;
  if (g === 'rounded') { if (gs.length !== 3 || !gs.every(number)) throw Error('invalid Rounded geometry'); }
  else if (g === 'text') { if (![3,4].includes(gs.length) || !string(gs[0]) || !gs.slice(1,3).every(number) || (gs.length === 4 && gs[3] !== 'monospace')) throw Error('invalid Text geometry'); }
  else if (g === 'path') {
    if (gs.length !== 1 || !Array.isArray(gs[0]) || gs[0].length > MAX) throw Error('invalid Path geometry');
    for (const p of gs[0]) {
      if (p[0] === 'path' && p.length === 2 && string(p[1])) continue;
      if (p[0] === 'circle' && p.length === 4 && p.slice(1).every(numeric)) continue;
      throw Error('invalid symbol path');
    }
  } else throw Error('unsupported F geometry');
  const [f,...fs] = fill;
  if (f === 'none' && fs.length === 0) {}
  else if (f === 'solid' && fs.length === 1 && string(fs[0])) {}
  else if (f === 'gradient' && fs.length === 3 && fs.slice(0,2).every(string) && number(fs[2]) && fs[2] <= 100) {}
  else if (f === 'photo' && fs.length === 3 && string(fs[0]) && fs.slice(1).every(number)) {}
  else if (f === 'atlas' && fs.length === 7 && string(fs[0]) && fs.slice(1).every(number)) {}
  else throw Error('invalid F fill');
  if (!(stroke[0] === 'none' && stroke.length === 1) &&
    !(stroke[0] === 'stroke' && stroke.length === 3 && string(stroke[1]) && isStrokeWidth(stroke[2]))) throw Error('invalid F stroke');
  if (effects.length > MAX) throw Error('too many F effects');
  for (const e of effects) {
    if (e[0] === 'blur' && e.length === 2 && number(e[1])) continue;
    if (e[0] === 'shadow' && e.length === 4 && e.slice(1,3).every(number) && string(e[3])) continue;
    if (e[0] === 'glass' && e.length === 7 && e.slice(1,6).every(number) && string(e[6]) && g === 'rounded') continue;
    throw Error('invalid F effect');
  }
}
function shapePath(geometry, width, height) {
  const path = new Path2D();
  if (geometry[0] === 'rounded') {
    path.roundRect(0,0,geometry[1],geometry[2],Math.min(geometry[3],geometry[1]/2,geometry[2]/2));
  } else if (geometry[0] === 'path') {
    const scale = Math.min(width,height)/24;
    const transform = new DOMMatrix().translate((width-24*scale)/2,(height-24*scale)/2).scale(scale);
    for (const p of geometry[1]) {
      const piece = new Path2D();
      if (p[0] === 'path') path.addPath(new Path2D(p[1]),transform);
      else { piece.arc(Number(p[1]),Number(p[2]),Number(p[3]),0,Math.PI*2); path.addPath(piece,transform); }
    }
  }
  return path;
}
export function createCanvasRenderer(root, event) {
  const assets = new Map(), inflight = new Set();
  let canvas, regions = [], closed = false;
  const pending = (promise, signal) => new Promise((resolve,reject) => {
    const abort = () => reject(signal.reason || Error('cancelled'));
    Promise.resolve(promise).then(resolve,reject).finally(() => signal.removeEventListener('abort',abort));
    if (signal.aborted) return abort();
    signal.addEventListener('abort',abort,{once:true});
  });
  async function image(url, signal) {
    if (!url) return null;
    let promise = assets.get(url);
    if (!promise) {
      let cancel;
      promise = new Promise((resolve,reject) => {
        const img = new Image();
        cancel = () => { img.onload=img.onerror=null;img.src='';reject(Error('stopped')); };
        img.onload = () => resolve(img); img.onerror = () => reject(Error('F image could not be loaded'));
        img.src = url;
      });
      promise.cancel=cancel;inflight.add(promise);
      if (assets.size < 32) assets.set(url,promise);
      promise.then(() => inflight.delete(promise),() => {inflight.delete(promise);assets.delete(url);});
    }
    return await pending(promise,signal);
  }
  const click = e => {
    const b = canvas.getBoundingClientRect();
    const x = (e.clientX-b.left)*canvas.width/b.width, y = (e.clientY-b.top)*canvas.height/b.height;
    const region = [...regions].reverse().find(r => x >= r.x && y >= r.y && x < r.x+r.width && y < r.y+r.height);
    if (region && region.enabled !== false) event(region.name);
  };
  function getCanvas() {
    if (canvas && !root.contains(canvas)) { canvas.removeEventListener('click',click);canvas=null;regions=[]; }
    if (!canvas) {
      canvas = root.querySelector('canvas') || document.createElement('canvas');
      canvas.setAttribute('aria-label','F application');
      canvas.addEventListener('click',click); root.append(canvas);
    }
    return canvas;
  }
  async function paint(data, signal) {
    if (closed || signal.aborted) throw Error('cancelled');
    const commands = JSON.parse(data);
    if (!Array.isArray(commands) || commands.length > MAX) throw Error('invalid canvas command list');
    for (const c of commands) {
      if (!Array.isArray(c)) throw Error('invalid canvas command');
      if (c[0] === 'shape') checkShape(c);
      else if (c[0] === 'frame' && c.length === 3 && c.slice(1).every(v=>Number.isInteger(v)&&v>=0&&v<=16384) && c[1]*c[2]<=16777216) {}
      else if (c[0] === 'region' && c.length === 7 && string(c[1]) && c.slice(2,6).every(number) && typeof c[6] === 'boolean') {}
      else if (c[0] === 'clear' && c.length === 1) {}
      else throw Error('unsupported canvas command');
    }
    const frames=commands.filter(c=>c[0]==='frame');
    if (frames.length!==1 || commands[0]!==frames[0]) throw Error('invalid Canvas frame');
    const loaded = new Map();
    for (const c of commands) if (c[0] === 'shape' && ['photo','atlas'].includes(c[7][0])) loaded.set(c,await image(c[7][1],signal));
    if (closed || signal.aborted) throw Error('cancelled');
    getCanvas();
    const [,w,h]=frames[0];if(canvas.width!==w)canvas.width=w;if(canvas.height!==h)canvas.height=h;
    const ctx = canvas.getContext('2d');
    if (!ctx) throw Error('Canvas 2D unavailable');
    const next = [];
    for (const c of commands) {
      const [kind,color,x,y,a,b] = c;
      if (kind === 'frame') continue;
      if (kind === 'clear') { ctx.clearRect(0,0,canvas.width,canvas.height); continue; }
      if (kind === 'region') { next.push({name:color,x,y,width:a,height:b,enabled:c[6]});continue; }
      ctx.save();
      try {
        const [,name,sx,sy,boxWidth,boxHeight,geometry,fill,stroke,effects] = c;
        const width = geometry[0] === 'rounded' ? geometry[1] : boxWidth;
        const height = geometry[0] === 'rounded' ? geometry[2] : boxHeight;
        ctx.translate(sx,sy);
        const path = shapePath(geometry,width,height);
        const glass = effects.find(e => e[0] === 'glass');
        const blur = effects.find(e => e[0] === 'blur');
        if ((glass || blur) && width && height) {
          if (width > 16384 || height > 16384 || width*height > 16777216) throw Error('F backdrop exceeds Canvas limits');
          const backdrop = document.createElement('canvas'); backdrop.width=width;backdrop.height=height;
          backdrop.getContext('2d').drawImage(canvas,sx,sy,width,height,0,0,width,height);
          ctx.save();
          if (geometry[0] !== 'text') ctx.clip(path);
          ctx.filter = glass ? `blur(${glass[1]}px) saturate(${glass[2]}%)` : `blur(${blur[1]}px)`;
          ctx.drawImage(backdrop,0,0);ctx.restore();
        }
        // CSS outer shadows belong to the box, even when its fill is None.
        for (const e of effects) if (e[0] === 'shadow' && width && height) {
          const outline = geometry[0] === 'rounded' ? path : new Path2D();
          if (geometry[0] !== 'rounded') outline.rect(0,0,width,height);
          const outside = new Path2D();outside.rect(-sx,-sy,canvas.width,canvas.height);outside.addPath(outline);
          ctx.save();ctx.clip(outside,'evenodd');ctx.fillStyle='#000';
          ctx.shadowOffsetY=e[1];ctx.shadowBlur=e[2];ctx.shadowColor=e[3];ctx.fill(outline);ctx.restore();
        }
        ctx.save();
        if (glass) ctx.globalAlpha=glass[5]/100;
        if (fill[0] === 'solid') ctx.fillStyle=fill[1];
        if (fill[0] === 'gradient') {
          const gradient=ctx.createLinearGradient(0,0,0,height);
          gradient.addColorStop(0,fill[1]);gradient.addColorStop(fill[3]/100,fill[1]);gradient.addColorStop(1,fill[2]);ctx.fillStyle=gradient;
        }
        if (geometry[0] === 'text') {
          ctx.font=`${geometry[3]} ${geometry[2]}px ${geometry[4]==='monospace'?'Menlo,ui-monospace,monospace':'system-ui'}`;ctx.textBaseline='top';ctx.fillText(geometry[1],0,0);
        } else if (fill[0] === 'solid' || fill[0] === 'gradient') ctx.fill(path);
        else if (fill[0] === 'photo' || fill[0] === 'atlas') {
          const img=loaded.get(c);
          if (img && width && height) {
            ctx.clip(path);
            if (fill[0] === 'atlas') ctx.drawImage(img,fill[2],fill[3],fill[4],fill[5],0,0,width,height);
            else { const scale=Math.max(width/img.naturalWidth,height/img.naturalHeight),w=img.naturalWidth*scale,h=img.naturalHeight*scale;ctx.drawImage(img,(width-w)/2,(height-h)/2,w,h); }
          }
        }
        ctx.restore();ctx.shadowColor='transparent';
        if (stroke[0] === 'stroke' && geometry[0] !== 'text' && Number(stroke[2])>0 && (geometry[0]!=='path'||Math.min(width,height)>0)) {
          ctx.save();ctx.strokeStyle=stroke[1];ctx.lineWidth=Number(stroke[2])*(geometry[0]==='path'?Math.min(width,height)/24:1);ctx.lineCap='round';ctx.lineJoin='round';
          if (geometry[0] === 'rounded') { ctx.clip(path);ctx.lineWidth*=2; }
          ctx.stroke(path);ctx.restore();
        }
        if (glass) {
          ctx.save();ctx.clip(path);const highlight=ctx.createLinearGradient(0,0,0,height/2);
          highlight.addColorStop(0,`rgba(255,255,255,${glass[4]/100})`);highlight.addColorStop(1,'rgba(255,255,255,0)');ctx.fillStyle=highlight;ctx.fillRect(0,0,width,height);ctx.restore();
          ctx.save();ctx.clip(path);ctx.strokeStyle=glass[6];ctx.lineWidth=1;ctx.stroke(path);ctx.restore();
        }
      } finally { ctx.restore(); }
    }
    regions=next;
    return '';
  }
  return {paint,close() {closed=true;for(const p of new Set([...assets.values(),...inflight]))p.cancel();assets.clear();inflight.clear();regions=[];canvas?.removeEventListener('click',click);}};
}
