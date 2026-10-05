import assert from 'node:assert/strict';
import { createDotHost } from '../web/host.mjs';

globalThis.ResizeObserver = class { observe() {} disconnect() {} };
globalThis.window = new EventTarget();
globalThis.document = new EventTarget();
let editor = false, disabled = false, sends = 0, prevented = 0;
const handlers = new Map();
const root = {
  dataset: {}, clientWidth: 390,
  addEventListener(name, handler) { handlers.set(name, handler); },
  removeEventListener(name) { handlers.delete(name); },
  querySelector(selector) {
    if (selector.includes('Close') || selector.includes('Cerrar')) return editor ? {} : null;
    if (selector.includes('Send') || selector.includes('Enviar')) return { disabled, click() { sends++; } };
    return null;
  },
};
const host = createDotHost({ root, deliver() {} });
function enter(values = {}) {
  handlers.get('keydown')({ key: 'Enter', shiftKey: false, isComposing: false, target: { matches: () => true }, preventDefault() { prevented++; }, ...values });
}
try {
  enter(); assert.equal(sends, 1); assert.equal(prevented, 1);
  editor = true;
  enter(); assert.equal(sends, 1); assert.equal(prevented, 1, 'Expanded Editor must preserve a newline');
  editor = false;
  enter({ shiftKey: true }); enter({ isComposing: true });
  assert.equal(sends, 1); assert.equal(prevented, 1);
  disabled = true; enter(); assert.equal(sends, 1); assert.equal(prevented, 1);
} finally { host.close(); }
console.log('PASS composer Enter sends; expanded Editor, Shift+Enter, IME, and disabled Send do not send');

// Exercise the real host transport with a minimal empty IndexedDB adapter.
globalThis.indexedDB = { open() {
  const request = { result: {
    close() {},
    transaction() {
      const transaction = { objectStore: () => ({ get: () => ({ result: undefined }) }) };
      queueMicrotask(() => transaction.oncomplete?.()); return transaction;
    },
  } };
  queueMicrotask(() => request.onsuccess?.()); return request;
} };
const saved = new Map();
globalThis.localStorage = { getItem: key => saved.get(key) ?? null, setItem: (key, value) => saved.set(key, value), removeItem: key => saved.delete(key) };
globalThis.location = new URL('http://localhost/');
root.querySelectorAll = () => [];
root.setAttribute = () => {};
let current = { provider: 'bakery', reviewContext: 'receipt-A', acceptedRequestIds: [] };
const posted = [];
globalThis.fetch = async (_url, options = {}) => {
  if (options.body) posted.push(JSON.parse(options.body));
  return Response.json(current);
};
const transportHost = createDotHost({ root, deliver() {} });
const sendTurn = id => transportHost.request(6, JSON.stringify({ url: '/api/turn', body: { requestId: id, threadId: 'sabor-a-cielo', text: 'confirmo' } }));
try {
  await transportHost.request(3, '/api/session'); transportHost.rendered();
  current = { ...current, reviewContext: 'receipt-B' };
  await transportHost.request(3, '/api/session');
  await sendTurn('stale-tab-request');
  assert.equal(posted.at(-1).reviewContext, 'receipt-A', 'Unrendered snapshot must not authorize another receipt');
  transportHost.rendered();
  await sendTurn('stale-tab-request');
  assert.equal(posted.at(-1).reviewContext, 'receipt-A', 'Retry must preserve the original review context');
  await sendTurn('fresh-tab-request');
  assert.equal(posted.at(-1).reviewContext, 'receipt-B');
  current = { provider: 'codex', acceptedRequestIds: [] };
  await transportHost.request(3, '/api/session'); transportHost.rendered();
  await sendTurn('personal-dot-request');
  assert.equal(Object.hasOwn(posted.at(-1), 'reviewContext'), false, 'Personal Dot protocol stays unchanged');
} finally { transportHost.close(); }
console.log('PASS bakery rendered-review binding, preserved retry context, and unchanged personal Dot requests');
