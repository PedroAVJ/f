import { resolve, dirname, join } from 'node:path';
import { readFileSync } from 'node:fs';
import { loadConfig, verifyApplicationSources, verifyDependencies } from './config.ts';

const [configuration, command = 'check', ...args] = process.argv.slice(2);
if (!configuration) throw Error('Usage: app CONFIG.bend check|ios|web|server [arguments]');
const file = resolve(configuration);
const root = dirname(file);
if (command === 'check') {
  const config = await loadConfig(file);
  verifyDependencies(root, config);
  verifyApplicationSources(root);
  console.log('Application source and exact dependency revisions verified.');
} else if (command === 'ios' || command === 'web') {
  const child = Bun.spawn(['bun', join(import.meta.dir, command + '.ts'), file, ...args], {cwd:root, stdout:'inherit', stderr:'inherit', stdin:'inherit'});
  process.exit(await child.exited);
} else if (command === 'server') {
  const [entry, runtimeConfig, ...flags] = args;
  if (!entry?.endsWith('.bend') || !runtimeConfig) throw Error('Server requires a Bend entry and a runtime JSON configuration file outside source control.');
  if (flags.length && (flags.length !== 1 || flags[0] !== '--development')) throw Error('Unknown server option.');
  const development = flags[0] === '--development';
  const {run} = await import('../server/host.ts');
  const config = JSON.parse(readFileSync(resolve(runtimeConfig), 'utf8'));
  await run(resolve(root, entry), {...config, development});
} else throw Error('Unknown application tool: ' + command);
