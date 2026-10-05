import { afterEach, beforeEach, expect, test } from 'bun:test';
import { IDBFactory } from 'fake-indexeddb';
import { createMediaHost } from '../../web/media.mjs';
import { responseText } from '../../web/transport.mjs';

const original = Object.fromEntries(['indexedDB', 'localStorage', 'location', 'fetch', 'navigator', 'MediaRecorder'].map(key => [key, Object.getOwnPropertyDescriptor(globalThis, key)]));
beforeEach(() => {
  const storage = {};
  Object.defineProperties(storage, {
    getItem: { value: key => storage[key] ?? null },
    setItem: { value: (key, value) => { storage[key] = value; } },
    removeItem: { value: key => { delete storage[key]; } },
  });
  for (const [key, value] of Object.entries({ indexedDB: new IDBFactory(), localStorage: storage, location: { href: 'https://dot.test/', origin: 'https://dot.test' } }))
    Object.defineProperty(globalThis, key, { configurable: true, writable: true, value });
});
afterEach(() => {
  for (const [key, descriptor] of Object.entries(original)) {
    if (descriptor) Object.defineProperty(globalThis, key, descriptor);
    else delete globalThis[key];
  }
});

async function saved(kind, value) {
  const db = await new Promise((resolve, reject) => {
    const request = indexedDB.open('dot-media', 1);
    request.onupgradeneeded = () => request.result.createObjectStore('drafts');
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
  try {
    return await new Promise((resolve, reject) => {
      const transaction = db.transaction('drafts', value ? 'readwrite' : 'readonly');
      const store = transaction.objectStore('drafts');
      const request = value ? store.put(value, kind) : store.get(kind);
      transaction.oncomplete = () => resolve(request.result);
      transaction.onabort = () => reject(transaction.error);
    });
  } finally { db.close(); }
}

for (const kind of ['audio', 'image']) {
  test(`${kind} survives an uncertain upload and cannot be discarded before receipt reconciliation`, async () => {
    const draft = { kind, id: 'clip-1', session: 'physical-1', durationMs: 1200, width: 20, height: 20, blob: new Blob(['original'], { type: kind === 'audio' ? 'audio/mp4' : 'image/jpeg' }) };
    await saved(kind, draft);
    const metadata = { requestId: 'receipt-1', threadId: 'thread-1', text: 'caption', ...(kind === 'audio' ? { clipId: draft.id } : { imageId: draft.id }) };
    const events = [];
    const host = createMediaHost(event => events.push(event));
    globalThis.fetch = async () => { throw Error('Response lost'); };
    await expect(host.request(kind === 'audio' ? 11 : 13, { url: `/api/${kind}`, body: metadata })).rejects.toThrow('Response lost');
    await expect(host.request(kind === 'audio' ? 10 : 12, { action: kind === 'audio' ? 'record-cancel' : 'cancel' })).rejects.toThrow('pending send');
    expect((await saved(kind)).metadata.requestId).toBe('receipt-1');
    await host.restore([]);
    const restored = kind === 'audio' ? events.find(event => event.action === 'pending') : events.find(event => event.action === 'image');
    expect(restored.data[kind === 'audio' ? 'id' : 'requestId']).toBe('receipt-1');
    localStorage.setItem('bend-input:textbox · Message', 'caption');
    await host.acknowledge(['receipt-1']);
    expect(await saved(kind)).toBeUndefined();
    expect(localStorage.getItem('bend-input:textbox · Message')).toBeNull();
    expect(events.at(-1).data.id).toBe('receipt-1');
    host.close();
  });
}

test('an acknowledged caption does not erase a newer unsent draft', async () => {
  await saved('audio', { kind: 'audio', id: 'clip-1', metadata: { requestId: 'r1', threadId: 't1', text: 'old caption' } });
  localStorage.setItem('bend-input:textbox · Message', 'new message');
  await createMediaHost(() => {}).acknowledge(['r1']);
  expect(localStorage.getItem('bend-input:textbox · Message')).toBe('new message');
});

test('oversized streamed responses are cancelled at the one-MiB boundary', async () => {
  let cancelled = false;
  const body = new ReadableStream({ pull(controller) { controller.enqueue(new Uint8Array(1024 * 1024 + 1)); }, cancel() { cancelled = true; } });
  await expect(responseText(new Response(body))).rejects.toThrow('too large');
  expect(cancelled).toBe(true);
});

test('closing while microphone permission resolves releases the late stream', async () => {
  let grant, stopped = false;
  Object.defineProperty(globalThis, 'navigator', { configurable: true, value: { mediaDevices: { getUserMedia: () => new Promise(resolve => { grant = resolve; }) } } });
  Object.defineProperty(globalThis, 'MediaRecorder', { configurable: true, value: { isTypeSupported: () => true } });
  const events = [];
  const host = createMediaHost(event => events.push(event));
  const pending = host.request(10, { action: 'record', session: 'session-1' });
  host.close();
  grant({ getTracks: () => [{ stop() { stopped = true; } }] });
  await pending;
  expect(stopped).toBe(true);
  expect(events).toHaveLength(0);
});
