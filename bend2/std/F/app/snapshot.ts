import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { cpSync, mkdirSync, readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';
import { forkRoot, type Config } from './config.ts';

const digest = (file: string) => createHash('sha256').update(readFileSync(file)).digest('hex');
const git = (directory: string, args: string[]) => execFileSync('git', ['-C', directory, ...args], {encoding:'utf8'}).trim();
function files(directory: string): string[] {
  return readdirSync(directory).sort().flatMap(name => {
    const file = join(directory, name);
    return statSync(file).isDirectory() ? files(file) : [file];
  });
}

export function captureSources(root: string, destination: string, development: boolean) {
  const checkout = (directory: string) => ({commit:git(directory, ['rev-parse', 'HEAD']), dirty:!!git(directory, ['status', '--porcelain', '--untracked-files=normal'])});
  const checkouts = {source:checkout(root), fork:checkout(forkRoot)};
  const source = join(destination, 'app'), fork = join(destination, 'f');
  const names = git(root, ['ls-files', '--cached', '--others', '--exclude-standard', '-z']).split('\0').filter(name => name.endsWith('.bend'));
  for (const name of new Set(names)) {
    const output = join(source, name);
    mkdirSync(dirname(output), {recursive:true});
    writeFileSync(output, readFileSync(join(root, name)));
  }
  mkdirSync(fork, {recursive:true});
  if (development) cpSync(join(forkRoot, 'bend2'), join(fork, 'bend2'), {recursive:true, filter:file => !file.split('/').some(part => part === 'node_modules' || part === '.git')});
  else {
    if (checkouts.fork.dirty) throw Error('Dependency has uncommitted source: compiler');
    const archive = execFileSync('git', ['-C', forkRoot, 'archive', checkouts.fork.commit, 'bend2'], {maxBuffer:128 * 1024 * 1024});
    execFileSync('tar', ['-xf', '-', '-C', fork], {input:archive});
  }
  const inputs = files(destination).map(file => ({name:relative(destination, file), sha256:digest(file)}));
  return {source, fork, checkouts, inputs};
}

export function capturedConfig(snapshot: ReturnType<typeof captureSources>, name: string): Config {
  // A fresh loader resolves Base and every config import inside this snapshot.
  const program = 'const {loadConfig} = await import(process.argv[1]); process.stdout.write(JSON.stringify(await loadConfig(process.argv[2])));';
  const output = execFileSync(process.execPath, ['-e', program, join(snapshot.fork, 'bend2/std/F/app/config.ts'), join(snapshot.source, name)], {cwd:snapshot.source, encoding:'utf8', maxBuffer:64 * 1024 * 1024});
  return JSON.parse(output);
}
