import main from './program.mjs';

// The compiler evaluates the app. This worker only carries its sequential IO.
const limit = 1048576;
const encoder = new TextEncoder();
const pending = new Map();
let serial = 0, started = false, stopped = false;

function bounded(text) {
  if (typeof text !== 'string') throw Error('Bend browser payload must be text');
  if (encoder.encode(text).length > limit) throw Error('Bend browser payload exceeds 1 MiB');
  return text;
}

globalThis[Symbol.for('bend-browser-request')] = (operation, data) => {
  if (stopped) return Promise.resolve({status: 3, data: 'stopped'});
  if (!Number.isInteger(operation) || operation < 1 || operation > 6)
    throw Error('Unsupported Bend browser operation ' + operation);
  bounded(data);
  if (pending.size) throw Error('The browser JS backend requires sequential IO');
  return new Promise(resolve => {
    const id = ++serial;
    pending.set(id, resolve);
    postMessage({type: 'request', id, operation, data});
  });
};

async function run() {
  let operation = main()(value => ({$: 'Emit', value}));
  while (!stopped) {
    while (operation?.$ === '$JMP') {
      if (typeof operation.f !== 'function' || !Array.isArray(operation.x))
        throw Error('Invalid Bend continuation');
      operation = operation.f(...operation.x);
    }
    if (operation?.$ === 'Emit') return;
    if (operation?.$ === 'Halt') throw Error('Bend exited with status ' + operation.code);
    if (operation?.$ !== '$FFI' || operation.need ||
        typeof operation.run !== 'function' || typeof operation.kont !== 'function' ||
        !Array.isArray(operation.args))
      throw Error('Unsupported IO in the sequential Bend browser backend');
    const reply = await operation.run(...operation.args, operation.kont);
    if (!stopped) operation = operation.kont(reply);
  }
}

self.onmessage = async ({data: message}) => {
  if (message?.type === 'stop') {
    stopped = true;
    for (const complete of pending.values()) complete({status: 3, data: 'stopped'});
    pending.clear();
    self.close();
    return;
  }
  if (stopped) return;
  if (message?.type === 'reply') {
    const complete = pending.get(message.id);
    if (!complete) return;
    pending.delete(message.id);
    const reply = message.reply;
    try {
      if (![1, 2, 3].includes(reply?.status)) throw Error('Invalid Bend browser reply status');
      complete({status: reply.status, data: bounded(reply.data)});
    } catch (problem) {
      complete({status: 2, data: String(problem.message || problem)});
    }
    return;
  }
  if (message?.type !== 'start' || started) return;
  started = true;
  if (message.threaded || message.workers !== 1) {
    postMessage({type: 'error', text: 'The Bend browser JS backend requires one worker'});
    return;
  }
  const beginning = performance.now();
  postMessage({type: 'ready', backend: 'javascript', workers: 1, threaded: false, milliseconds: 0});
  try {
    await run();
    if (!stopped) postMessage({type: 'done', milliseconds: performance.now() - beginning});
  } catch (problem) {
    if (!stopped) postMessage({type: 'error', text: String(problem?.stack || problem?.message || problem)});
  }
};
