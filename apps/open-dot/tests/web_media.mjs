import assert from 'node:assert/strict';
import { preparePhoto } from '../web/media.mjs';

let sizes, closed, calls;
globalThis.createImageBitmap = async () => ({ width: 4000, height: 3000, close() { closed++; } });
globalThis.document = { createElement(tag) {
  assert.equal(tag, 'canvas');
  return { getContext: () => ({ drawImage() {} }), toBlob(callback, type, quality) {
    calls.push({ width: this.width, height: this.height, type, quality });
    const size = sizes.shift(); callback(size === null ? null : { size });
  } };
} };
const reset = values => { sizes = values; closed = 0; calls = []; };

reset([2_000_000]);
assert.deepEqual(await preparePhoto({ size: 4_000_000 }), { blob: { size: 2_000_000 }, width: 2560, height: 1920 });
assert.equal(calls[0].quality, 0.88);
assert.equal(closed, 1);

reset([2_000_000, 1_000_000, 600_000]);
const bakery = await preparePhoto({ size: 4_000_000 }, 786432);
assert.equal(bakery.blob.size, 600_000);
assert.ok(bakery.width < 2560);
assert.equal(closed, 1);
assert.equal(calls.length, 3);
assert.ok(calls.every(call => call.type === 'image/jpeg'));

reset(Array(8).fill(2_000_000));
await assert.rejects(preparePhoto({ size: 4_000_000 }, 786432), /too large/);
assert.equal(calls.length, 8);
assert.equal(closed, 1);

reset([null]);
await assert.rejects(preparePhoto({ size: 4_000_000 }), /could not prepare/);
assert.equal(closed, 1);
await assert.rejects(preparePhoto({ size: 33 * 1024 * 1024 }), /32 MiB/);
console.log('PASS web photo size limits, bounded recompression, encoding failure, and bitmap cleanup');
