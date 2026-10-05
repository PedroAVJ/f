import { createHash, randomUUID } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const fork = join(root, '../f');
const destination = join(root, 'dist/mobile.web');
mkdirSync(join(root, 'dist'), {recursive: true});
const output = mkdtempSync(join(root, 'dist/.mobile-js-'));
try {
  const generatedPath = join(output, 'program.js');
  execFileSync('bun', [join(fork, 'bend2/tool.ts'), 'mobile.bend', '-o', generatedPath], {
    cwd: root, stdio: 'inherit', timeout: 90000,
  });
  const generated = readFileSync(generatedPath, 'utf8');
  const effect = `io_eff("std/F/browser/host.request", () => ({$: "std/F/browser/host.Reply", status: 2, data: 'browser host unavailable'}));`;
  const tail = 'cli(process.argv.slice(1));\nio_exit($main$, null);';
  if (generated.split(effect).length !== 2 || !generated.endsWith(tail))
    throw Error('The fork JS browser boundary changed; update the checked adapter.');
  const foreignKeys = [...generated.matchAll(/io_eff\("([^"]+)"/g)].map(match => match[1]);
  if (foreignKeys.length !== 1 || foreignKeys[0] !== 'std/F/browser/host.request')
    throw Error('The browser JS adapter supports only F browser host IO.');
  const adapted = generated.slice(0, -tail.length).replace(effect, `io_eff("std/F/browser/host.request", async (operation, data) => {
  const reply = await globalThis[Symbol.for("bend-browser-request")](operation, data);
  return {$: "std/F/browser/host.Reply", status: reply.status, data: reply.data};
});`) + 'export default function nativeMain() { return run_loop($main$()); }\n';
  writeFileSync(join(output, 'program.mjs'), adapted);
  rmSync(generatedPath);
  for (const file of ['shell.js', 'renderer.js', 'gpu.js'])
    copyFileSync(join(fork, 'bend2/std/F/browser', file), join(output, file));
  copyFileSync(join(root, 'mobile/worker.js'), join(output, 'worker.js'));
  writeFileSync(join(output, 'runtime.json'), JSON.stringify({
    backend: 'javascript', compiler: 'PedroAVJ/f Bend2', workers: 1,
    entry: 'program.mjs', source: 'mobile.bend',
    compilerOutputSha256: createHash('sha256').update(generated).digest('hex'),
    adaptedProgramSha256: createHash('sha256').update(adapted).digest('hex'),
    adaptation: ['F browser Host.request asynchronous bridge', 'Browser module entry'],
  }) + '\n');
  const previous = destination + '.previous-' + randomUUID();
  if (existsSync(destination)) renameSync(destination, previous);
  try { renameSync(output, destination); }
  catch (problem) {
    if (existsSync(previous)) renameSync(previous, destination);
    throw problem;
  }
  if (existsSync(previous)) rmSync(previous, {recursive: true});
  console.log('Compiled Bend phone runtime at ' + destination);
} finally {
  if (existsSync(output)) rmSync(output, {recursive: true});
}
