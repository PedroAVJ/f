import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, realpathSync, readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { resolve, join } from 'node:path';

export const forkRoot = resolve(import.meta.dir, '../../../..');
export type Dependency = { name: string; repository: string; path: string; revision: string; version: string };
export type Connection = { id: string; name: string; subtitle: string; origin: string };
type Blob = { text?: string; left?: Blob; right?: Blob };
type List<T> = { $: string; head?: T; tail?: List<T> };
export type Config = {
  name: string; bundle: string; version: string; minimum_os: string; origin: string; submit_label: string;
  camera_reason: string; microphone_reason: string; speech_reason: string;
  dependencies: Dependency[]; assets: { name: string; mime: string; base64: Blob }[]; connections: Connection[];
};
function list<T>(node: List<T>): T[] {
  const result: T[] = [];
  while (node?.$ === 'Con') { result.push(node.head!); node = node.tail!; }
  if (node?.$ !== 'Nil') throw Error('Invalid configuration list.');
  return result;
}
export async function loadConfig(file: string): Promise<Config> {
  await import(resolve(forkRoot, 'bend2/main.ts'));
  const module = (await import(resolve(file))).default;
  if (typeof module?.config !== 'function') throw Error('App configuration must export config().');
  const raw = module.config();
  const config = { ...raw, dependencies: list<Dependency>(raw.dependencies), assets: list<Config['assets'][number]>(raw.assets), connections: list<Connection>(raw.connections) } as Config;
  if (!/^[A-Za-z][A-Za-z0-9_-]{0,60}$/.test(config.name) || !/^[A-Za-z0-9.-]+$/.test(config.bundle)
    || !/^\d+(\.\d+){0,2}$/.test(config.version) || !/^\d+\.\d+$/.test(config.minimum_os)) throw Error('Invalid app identity or version.');
  const seen = new Set<string>();
  for (const item of config.connections) {
    const url = new URL(item.origin);
    if (!/^[A-Za-z0-9_-]{1,64}$/.test(item.id) || seen.has(item.id) || !item.name || item.name.length > 80 || item.subtitle.length > 200
      || url.protocol !== 'https:' || url.username || url.password || url.pathname !== '/' || url.search || url.hash) throw Error('Invalid configured connection.');
    seen.add(item.id);
  }
  return config;
}
export async function loadDependencies(file: string): Promise<Dependency[]> {
  await import(resolve(forkRoot, 'bend2/main.ts'));
  const module = (await import(resolve(file))).default;
  if (typeof module?.dependencies !== 'function') throw Error('Package must export dependencies().');
  return list<Dependency>(module.dependencies());
}
export function verifyDependencies(root: string, config: Pick<Config, 'dependencies'>, allowDirty = false) {
  const git = (directory: string, args: string[]) => execFileSync('git', ['-C', directory, ...args], {encoding:'utf8', stdio:['ignore','pipe','pipe']}).trim();
  const result: Record<string, Omit<Dependency, 'name'>> = Object.create(null);
  const compiler = config.dependencies.filter(dependency => dependency.name === 'compiler');
  if (compiler.length !== 1 || realpathSync(resolve(root, compiler[0].path)) !== realpathSync(forkRoot)) throw Error('The compiler dependency must identify the executing language fork.');
  for (const { name, ...dependency } of config.dependencies) {
    if (Object.hasOwn(result, name)) throw Error('Duplicate dependency name: ' + name);
    if (!/^[a-f0-9]{40}$/.test(dependency.revision)) throw Error('Invalid dependency revision: ' + name);
    const directory = resolve(root, dependency.path);
    if (git(directory, ['rev-parse', 'HEAD']) !== dependency.revision) throw Error('Dependency revision mismatch: ' + name);
    if (!allowDirty && git(directory, ['status', '--porcelain', '--untracked-files=normal'])) throw Error('Dependency has uncommitted source: ' + name);
    if (dependency.version) throw Error('Use an exact revision; dependency version verification requires its Bend configuration.');
    result[name] = dependency;
  }
  return result;
}
function blob(value: Blob): string {
  if (typeof value?.text === 'string') return value.text;
  if (!value?.left || !value.right) throw Error('Invalid binary asset tree.');
  return blob(value.left) + blob(value.right);
}
export function materializeAssets(config: Config, directory: string) {
  const seen = new Set<string>();
  const reserved = new Set(['index.html', 'app.css', 'app.mjs', 'client.js', 'policy.mjs', 'shell.js', 'manifest.json', 'info.plist', 'embedded.mobileprovision', 'assets.car', config.name.toLowerCase()]);
  const assets = config.assets.map(asset => {
    const name = asset.name.toLowerCase();
    if (!/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(asset.name) || seen.has(name) || reserved.has(name) || /\.(?:[cm]?js|wasm|html|bend|[cm]?ts)$/i.test(name) || existsSync(join(directory, asset.name))) throw Error('Asset name conflicts with application source or generated output: ' + asset.name);
    seen.add(name);
    const encoded = blob(asset.base64);
    const bytes = Buffer.from(encoded, 'base64');
    if (bytes.length > 20 * 1024 * 1024 || bytes.toString('base64') !== encoded) throw Error('Invalid encoded asset: ' + asset.name);
    return {asset, bytes};
  });
  mkdirSync(directory, {recursive:true});
  return assets.map(({asset, bytes}) => {
    writeFileSync(join(directory, asset.name), bytes, {flag:'wx'});
    return {name:asset.name, mime:asset.mime, bytes:bytes.length, sha256:createHash('sha256').update(bytes).digest('hex')};
  });
}
export function verifyApplicationSources(root: string) {
  const names = execFileSync('git', ['-C', root, 'ls-files', '-z'], {encoding:'utf8'}).split('\0').filter(Boolean);
  const invalid = names.filter(name => name !== 'LICENSE' && !name.endsWith('.bend'));
  if (invalid.length) throw Error('Application files must be Bend source or LICENSE:\n' + invalid.join('\n'));
  for (const name of names.filter(name => name.endsWith('.bend'))) {
    const text = readFileSync(resolve(root, name), 'utf8');
    if (/\bimport\s+["'][^"']+\.(?:[cm]?js|ts|c|h)["']/.test(text)) throw Error('Application source may not import a foreign implementation: ' + name);
  }
}
