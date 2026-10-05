import { existsSync, mkdirSync, mkdtempSync, readFileSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { resolve, basename, dirname, join } from 'node:path';
import { emitWebAssets } from './web-assets.ts';
import { verifyDependencies, verifyApplicationSources } from './config.ts';
import { captureSources, capturedConfig } from './snapshot.ts';

const configPath = resolve(process.argv[2] ?? 'config.bend');
const root = dirname(configPath);
verifyApplicationSources(root);
mkdirSync(join(root, 'dist'), {recursive:true});
const stage = mkdtempSync(join(root, 'dist/.web-build-'));
try {
  const snapshot = captureSources(root, join(stage, 'work'), false);
  const config = capturedConfig(snapshot, basename(configPath));
  const dependencies = verifyDependencies(root, config);
  if (snapshot.checkouts.fork.commit !== dependencies.compiler.revision) throw Error('Captured compiler revision does not match the declared dependency.');
  const output = join(stage, 'app.web'), destination = join(root, 'dist', config.name.toLowerCase() + '.web');
  // Retain LLVM optimization without Binaryen's whole-evaluator pass.
  const cflags = `${process.env.EMCC_CFLAGS ?? ''} -O1 -w`;
  const child = Bun.spawn([process.execPath, join(snapshot.fork, 'bend2/tool.ts'), join(snapshot.source, 'web.bend'), '-o', output, '--web-corpus-mib', '128'], {
    cwd:snapshot.source, stdout:'inherit', stderr:'inherit', env:{...process.env, EMCC_CFLAGS:cflags},
  });
  if (await child.exited !== 0) throw Error('Web compilation failed.');
  const manifest = await emitWebAssets(snapshot.source, config, output, undefined, snapshot.fork);
  Object.assign(manifest, {dependencies, checkoutAtSnapshot:snapshot.checkouts, capturedInputs:snapshot.inputs, compilerFlags:cflags});
  writeFileSync(join(output, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
  const previous = destination + '.previous-' + basename(stage);
  if (existsSync(destination)) {
    const file = join(destination, 'manifest.json');
    if (!existsSync(file) || JSON.parse(readFileSync(file, 'utf8')).bendWeb !== 1) throw Error('Refusing to replace an unrelated directory: ' + destination);
    renameSync(destination, previous);
  }
  try { renameSync(output, destination); }
  catch (error) { if (existsSync(previous)) renameSync(previous, destination); throw error; }
  if (existsSync(previous)) rmSync(previous, {recursive:true});
  console.log('Web build: ' + destination);
} finally {
  rmSync(stage, {recursive:true, force:true});
}
