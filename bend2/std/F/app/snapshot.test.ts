import { expect, test } from 'bun:test';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { captureSources, capturedConfig } from './snapshot.ts';

test('configuration and input hashes describe captured bytes after the working source changes', () => {
  const directory = mkdtempSync(join(tmpdir(), 'bend-snapshot-test-'));
  try {
    const root = join(directory, 'source');
    mkdirSync(root);
    const config = (name: string) => `import ../f/bend2/std/F/app/config.bend as App
def config() -> App.Config:
  App.Config{"${name}", "test.snapshot", "1.0.0", "17.0", "https://example.test", "Send", "Camera", "Microphone", "Speech", [], [], []}
`;
    writeFileSync(join(root, 'config.bend'), config('Captured'));
    execFileSync('git', ['init', '-q', root]);
    execFileSync('git', ['-C', root, 'add', 'config.bend']);
    execFileSync('git', ['-C', root, '-c', 'user.name=Test', '-c', 'user.email=test@localhost', 'commit', '-qm', 'fixture']);
    const snapshot = captureSources(root, join(directory, 'snapshot'), true);
    writeFileSync(join(root, 'config.bend'), config('Changed'));
    expect(capturedConfig(snapshot, 'config.bend').name).toBe('Captured');
    const bytes = readFileSync(join(snapshot.source, 'config.bend'));
    expect(snapshot.inputs.find(input => input.name === 'app/config.bend')?.sha256).toBe(createHash('sha256').update(bytes).digest('hex'));
    expect(bytes.toString()).not.toBe(readFileSync(join(root, 'config.bend'), 'utf8'));
    expect(snapshot.inputs.some(input => input.name === 'f/bend2/tool.ts')).toBe(true);
  } finally {
    rmSync(directory, {recursive:true, force:true});
  }
}, 30000);
