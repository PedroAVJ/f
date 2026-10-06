// Run with Node; the generated ladder crosses evaluator function boundaries.
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const work = mkdtempSync(join(tmpdir(), 'bend-web-dispatcher-'));
symlinkSync(root, join(work, 'fork'), 'dir');

function build(name, source) {
  const input = join(work, name + '.bend'), output = join(work, name + '.web');
  writeFileSync(input, source);
  const result = spawnSync('bun', [join(root, 'bend2/tool.ts'), input, '-o', output], {
    cwd: root, encoding: 'utf8', env: { ...process.env, EMCC_CFLAGS: '-O1 -w' },
  });
  assert.equal(result.status, 0, result.stderr || result.stdout);
  return output;
}

async function run(directory, variant, expected, error = false) {
  const previousExitCode = process.exitCode;
  await WebAssembly.compile(readFileSync(join(directory, variant + '.wasm')));
  const create = (await import(pathToFileURL(join(directory, variant + '.mjs')).href)).default;
  let output = '', requests = 0, completed = false;
  const module = await create({ bendWrite(_fd, bytes) { output += new TextDecoder().decode(bytes); } });
  module.bendRequest = async (operation, data) => {
    assert.equal(operation, 71);
    assert.equal(data, 'continue');
    assert.equal(output, '10079:50025072\n');
    requests++;
    await new Promise(resolve => setTimeout(resolve, 10));
    assert.equal(completed, false);
    return { status: 1, data: 'resumed' };
  };
  try {
    let status;
    try {
      status = await module.ccall('bend_start', 'number', ['number'], [variant === 'threads' ? 2 : 1], { async: true });
    } catch (failure) {
      if (!error || failure?.name !== 'ExitStatus') throw failure;
      status = failure.status;
    }
    completed = true;
    assert.equal(status, error ? 1 : 0);
    assert.equal(output, expected);
    assert.equal(requests, directory.endsWith('ladder.web') ? 1 : 0);
  } finally {
    module.PThread?.terminateAllThreads();
    if (error) process.exitCode = previousExitCode;
  }
}

try {
  let ladder = 'import Base\nimport ./fork/tests/web/dispatcher.bend as Fixture\n';
  ladder += 'def hop0(x: U32) -> U32 & U32: Fixture.walk(10000n, x, 7)\n';
  for (let index = 1; index <= 130; index++) {
    ladder += `def hop${index}(x: U32) -> U32 & U32: Fixture.advance(hop${index - 1}(x))\n`;
  }
  ladder += 'def main() -> IO(Unit): Fixture.finish(hop130(3))\n#|10079:50025072\n#|browser host unavailable\n';
  const directories = [
    [build('ladder', ladder), '10079:50025072\nresumed\n', false],
    [build('parallel', 'import Base\nimport ./fork/tests/web/parallel.bend as Fixture\ndef main() -> U32: Fixture.main()\n#|2621440\n'), '2621440\n', false],
    [build('stack', 'import Base\nimport ./fork/tests/io/stack_fault_trap.bend as Fixture\ndef main() -> U32: Fixture.run(300000000)\n#|bend: browser work stack exhausted (2 MiB)\n#|exit 1\n'), 'bend: browser work stack exhausted (2 MiB)\n', true],
  ];
  for (const variant of ['seq', 'threads']) {
    for (const [directory, expected, error] of directories) await run(directory, variant, expected, error);
  }
  console.log('Chunked browser loops, multi-value continuations, closures, effects, parallel work, and stack errors passed.');
} finally {
  rmSync(work, { recursive: true, force: true });
}
