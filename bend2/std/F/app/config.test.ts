import { afterEach, describe, expect, test } from 'bun:test';
import { execFileSync } from 'node:child_process';
import { existsSync, mkdtempSync, mkdirSync, readFileSync, readdirSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { forkRoot, materializeAssets, verifyDependencies, type Config, type Dependency } from './config.ts';

const temporary: string[] = [];
const git = (directory: string, ...args: string[]) => execFileSync('git', ['-C', directory, ...args], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();

function workspace() {
  const directory = mkdtempSync(join(tmpdir(), 'bend-app-boundary-'));
  temporary.push(directory);
  return directory;
}

function repository(root: string, name: string): Dependency {
  const directory = join(root, name);
  mkdirSync(directory);
  git(directory, 'init', '-q');
  writeFileSync(join(directory, 'source.bend'), 'import Base\n');
  git(directory, 'add', 'source.bend');
  git(directory, '-c', 'user.name=Boundary Test', '-c', 'user.email=boundary@example.invalid', '-c', 'commit.gpgsign=false', 'commit', '-qm', 'Initial fixture');
  return { name, repository: 'https://example.invalid/' + name, path: name, revision: git(directory, 'rev-parse', 'HEAD'), version: '' };
}

function compiler(path = forkRoot): Dependency {
  return { name: 'compiler', repository: 'https://github.com/PedroAVJ/f.git', path, revision: git(forkRoot, 'rev-parse', 'HEAD'), version: '' };
}

function configuration(dependencies: Dependency[] = [], assets: Config['assets'] = []): Config {
  return { name: 'Boundary', bundle: 'test.boundary', version: '1.0.0', minimum_os: '17.0', origin: 'https://example.invalid', submit_label: 'Send', camera_reason: 'Test camera', microphone_reason: 'Test microphone', speech_reason: 'Test speech', dependencies, assets, connections: [] };
}

const asset = (name: string, text = 'aGVsbG8='): Config['assets'][number] => ({ name, mime: 'application/octet-stream', base64: { text } });

afterEach(() => {
  for (const directory of temporary.splice(0)) rmSync(directory, { recursive: true, force: true });
});

describe('executing compiler dependency', () => {
  test('requires an explicit compiler declaration', () => {
    expect(() => verifyDependencies(workspace(), configuration(), true)).toThrow('executing language fork');
  });

  test('rejects a different real checkout even when its declared commit is exact', () => {
    const root = workspace();
    const other = { ...repository(root, 'other-fork'), name: 'compiler' };
    expect(() => verifyDependencies(root, configuration([other]), true)).toThrow('executing language fork');
  });

  test('accepts a realpath alias of the executing fork without changing its declared provenance', () => {
    const root = workspace();
    symlinkSync(forkRoot, join(root, 'language'));
    const dependency = compiler('./language');
    expect(verifyDependencies(root, configuration([dependency]), true)).toEqual({ compiler: { repository: dependency.repository, path: './language', revision: dependency.revision, version: '' } });
  });

  test('still rejects an incorrect revision for the executing fork', () => {
    expect(() => verifyDependencies(workspace(), configuration([{ ...compiler(), revision: '0'.repeat(40) }]), true)).toThrow('Dependency revision mismatch');
  });

  test('rejects duplicate dependency names instead of overwriting provenance', () => {
    const root = workspace();
    const first = repository(root, 'first');
    const second = { ...repository(root, 'second'), name: 'first' };
    expect(() => verifyDependencies(root, configuration([compiler(), first, second]), true)).toThrow('Duplicate dependency name: first');
  });

  test('does not let prototype property names bypass duplicate checks', () => {
    const root = workspace();
    const first = { ...repository(root, 'first'), name: '__proto__' };
    const second = { ...repository(root, 'second'), name: '__proto__' };
    expect(() => verifyDependencies(root, configuration([compiler(), first, second]), true)).toThrow();
  });
});

describe('asset output boundary', () => {
  test('rejects generated output and executable names before writing any earlier asset', () => {
    const root = workspace();
    const names = ['app.mjs', 'client.js', 'policy.mjs', 'shell.js', 'worker.js', 'renderer.js', 'gpu.js', 'seq.wasm', 'index.html', 'app.css', 'manifest.json', 'Info.plist', 'embedded.mobileprovision', 'Assets.car', 'Boundary', 'SOURCE.BEND', 'arbitrary.MJS'];
    for (const [index, name] of names.entries()) {
      const destination = join(root, String(index));
      expect(() => materializeAssets(configuration([], [asset('first.bin'), asset(name)]), destination)).toThrow('conflicts');
      expect(existsSync(destination)).toBe(false);
    }
  });

  test('preserves existing generated files and writes no earlier assets on collision', () => {
    const destination = workspace();
    writeFileSync(join(destination, 'manifest.json'), 'original manifest');
    expect(() => materializeAssets(configuration([], [asset('first.bin'), asset('manifest.json')]), destination)).toThrow('conflicts');
    expect(readdirSync(destination)).toEqual(['manifest.json']);
    expect(readFileSync(join(destination, 'manifest.json'), 'utf8')).toBe('original manifest');
  });

  test('preserves an existing non-reserved asset and does not partially write the batch', () => {
    const destination = workspace();
    writeFileSync(join(destination, 'kept.bin'), 'original bytes');
    expect(() => materializeAssets(configuration([], [asset('first.bin'), asset('kept.bin')]), destination)).toThrow('conflicts');
    expect(readdirSync(destination)).toEqual(['kept.bin']);
    expect(readFileSync(join(destination, 'kept.bin'), 'utf8')).toBe('original bytes');
  });

  test('rejects case aliases before materializing either name', () => {
    const destination = join(workspace(), 'assets');
    expect(() => materializeAssets(configuration([], [asset('Image.bin'), asset('image.bin')]), destination)).toThrow('conflicts');
    expect(existsSync(destination)).toBe(false);
  });

  test('validates later asset contents before writing the batch', () => {
    const destination = join(workspace(), 'assets');
    expect(() => materializeAssets(configuration([], [asset('first.bin'), asset('invalid.bin', 'not base64')]), destination)).toThrow('Invalid encoded asset');
    expect(existsSync(destination)).toBe(false);
  });

  test('materializes declared bytes and reports their digest without replacing existing output', () => {
    const destination = workspace();
    writeFileSync(join(destination, 'manifest.json'), 'untouched');
    const result = materializeAssets(configuration([], [asset('payload.bin')]), destination);
    expect(readFileSync(join(destination, 'payload.bin'), 'utf8')).toBe('hello');
    expect(readFileSync(join(destination, 'manifest.json'), 'utf8')).toBe('untouched');
    expect(result).toEqual([{ name: 'payload.bin', mime: 'application/octet-stream', bytes: 5, sha256: '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824' }]);
  });
});
