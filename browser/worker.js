// Reusable host boundary. All application evaluation stays in Wasm.
let module, serial = 0;
const pending = new Map();
self.onmessage = async ({data: m}) => {
  if (m.type === 'stop') {
    for (const complete of pending.values()) complete({status:3,data:'stopped'});
    pending.clear(); module?.PThread?.terminateAllThreads(); self.close(); return;
  }
  if (m.type === 'reply') {
    const complete = pending.get(m.id);
    if (complete) { pending.delete(m.id); complete(m.reply); }
    return;
  }
  if (m.type !== 'start' || module) return;
  try {
    const started = performance.now();
    const create = (await import(m.threaded ? './threads.mjs' : './seq.mjs')).default;
    const lines = [null, [], []];
    module = await create({
      bendWrite(fd, bytes) {
        const line = lines[fd];
        for (const byte of bytes) {
          if (byte === 10) {
            postMessage({type:fd === 1 ? 'stdout' : 'stderr',text:new TextDecoder().decode(new Uint8Array(line))});
            line.length = 0;
          } else {
            if (line.length >= 1048576) throw Error('browser output line exceeds 1 MiB');
            line.push(byte);
          }
        }
      },
      print: text => postMessage({type: 'stdout', text}),
      printErr: text => postMessage({type: 'stderr', text}),
      onAbort: text => postMessage({type: 'error', text: String(text)})
    });
    module.bendRequest = (operation, data) => new Promise(resolve => {
      const id = ++serial;
      pending.set(id, resolve);
      postMessage({type: 'request', id, operation, data});
    });
    postMessage({type: 'ready', milliseconds: performance.now() - started, threaded: m.threaded});
    const run = performance.now();
    const code = await module.ccall('bend_start', 'number', ['number'], [m.workers], {async: true});
    for (const fd of [1,2]) {
      if (lines[fd].length) postMessage({type:fd === 1 ? 'stdout' : 'stderr',text:new TextDecoder().decode(new Uint8Array(lines[fd]))});
    }
    if (code !== 0) throw Error('Bend exited with status ' + code);
    postMessage({type: 'done', milliseconds: performance.now() - run,
      rows: Array.from({length: 8}, (_, i) => module._bend_worker_rows(i))});
    module.PThread?.terminateAllThreads();
  } catch (e) {
    module?.PThread?.terminateAllThreads();
    postMessage({type: 'error', text: String(e?.stack || e?.message || (Number.isInteger(e?.status) ? 'Bend exited with status ' + e.status : e))});
  }
};
