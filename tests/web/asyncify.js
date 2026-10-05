// Build effects.bend, bang_scalar.bend, and text_bounds.bend as .web directories,
// then pass them here. These use real Wasm with bounded evaluator memory.
import assert from 'node:assert/strict';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

async function run(directory, replies, expected, variant) {
  const create = (await import(pathToFileURL(resolve(directory, variant + '.mjs')).href)).default;
  let output = '', pending, finished = false, requests = 0;
  const module = await create({ bendWrite(_fd, bytes) { output += new TextDecoder().decode(bytes); } });
  module.bendRequest = (operation, data) => new Promise(complete => {
    assert.equal(pending, undefined, 'only one effect is in flight');
    requests++;
    pending = { operation, data, complete };
  });
  const running = module.ccall('bend_start', 'number', ['number'], [variant === 'threads' ? 2 : 1], { async: true });
  const completion = running.then(code => { finished = true; return code; });
  for (const [index, reply] of replies.entries()) {
    for (let turn = 0; !pending && !finished && turn < 100; turn++)
      await new Promise(resolve => setTimeout(resolve, 1));
    assert.ok(pending, 'effect reached its asynchronous host');
    assert.equal(pending.operation, reply.operation);
    const before = output;
    await new Promise(resolve => setTimeout(resolve, 10));
    assert.equal(finished, false, 'evaluation remains suspended');
    assert.equal(requests, index + 1, 'next effect waits for this reply');
    assert.equal(output, before, 'no output before host completion');
    const request = pending;
    pending = undefined;
    request.complete(reply.value);
  }
  assert.equal(await completion, 0);
  assert.equal(requests, replies.length);
  assert.equal(output, expected);
  module.PThread?.terminateAllThreads();
}

const [effects, bang, textBounds] = process.argv.slice(2);
assert.ok(effects && bang && textBounds, 'pass the built effects, bang_scalar, and text_bounds directories');
for (const variant of ['seq', 'threads']) {
  await run(effects, [
    { operation: 3, value: { status: 1, data: 'fixture' } },
    { operation: 3, value: { status: 2, data: 'missing' } },
    { operation: 99, value: { status: 2, data: 'unsupported' } },
    { operation: 3, value: { status: 3, data: 'stopped' } },
  ], 'success:1:fixture\nfailure:2:missing\nunsupported:2:unsupported\ncancel:3:stopped\n', variant);
  await run(bang, [{ operation: 5, value: { status: 1, data: '[43]' } }], '43\n', variant);
  await run(bang, [{ operation: 5, value: { status: 2, data: 'unavailable' } }], '43\n', variant);
  await run(textBounds, [], 'True\nTrue\nTrue\nTrue\n', variant);
}
console.log('Async browser effects, GPU readback, CPU fallback, and bounded text previews passed.');
