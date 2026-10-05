import { createHash, randomUUID } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { copyFileSync, existsSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, readlinkSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

function checkoutIdentity(directory: string) {
  const git = (...args: string[]) => execFileSync('git', ['-C', directory, ...args], { maxBuffer: 32 * 1024 * 1024 });
  const commit = git('rev-parse', 'HEAD').toString().trim();
  const status = git('status', '--porcelain', '-z');
  if (!status.length) return { commit, dirty: false };
  const hash = createHash('sha256').update(status).update(git('diff', '--binary', 'HEAD'));
  for (const file of git('ls-files', '--others', '--exclude-standard', '-z').toString().split('\0').filter(Boolean).sort()) {
    const path = join(directory, file);
    hash.update(file + '\0').update(lstatSync(path).isSymbolicLink() ? readlinkSync(path) : readFileSync(path)).update('\0');
  }
  return { commit, dirty: true, dirtyDigest: hash.digest('hex') };
}

const root = fileURLToPath(new URL('../', import.meta.url));
const generated = join(root, 'dist/mobile.web');
const destination = join(root, 'dist/mobile');
mkdirSync(join(root, 'dist'), { recursive: true });
const output = mkdtempSync(join(root, 'dist/.mobile-package-'));
try {
  for (const file of readdirSync(generated)) copyFileSync(join(generated, file), join(output, file));
  const shellPath = join(output, 'shell.js');
  const shell = readFileSync(shellPath, 'utf8');
  const anchor = 'messages, workers:threaded ? workers : 1, threaded,';
  if (shell.split(anchor).length !== 2) throw new Error('The fork browser event hook changed; update the mobile host adapter.');
  const renderAnchor = "      restore();\n      return '';";
  if (shell.split(renderAnchor).length !== 2) throw new Error('The fork browser input hook changed; update the mobile host adapter.');
  const syncInputs = `      restore();
        if (options.persistRenderedInputs) for (const field of root.querySelectorAll('input[data-bend-field]')) {
          try { field.value ? store?.setItem(kept(field),field.value) : store?.removeItem(kept(field)); }
          catch (problem) { console.warn('Dot could not save the draft:', problem.message); }
        }
        options.onRender?.();
        return '';`;
  const fetchAnchor = '      const response = await fetch(url, {signal,';
  if (shell.split(fetchAnchor).length !== 2) throw new Error('The fork browser POST hook changed; update the mobile host adapter.');
  const persistRequest = `      if (operation === 6 && options.durableRequestStorage && spec.body?.requestId) {
          if (url.origin !== location.origin) throw Error('durable requests must use the application origin');
          if (!store) throw Error('No se pudo guardar el envío en este dispositivo.');
          store.setItem(options.durableRequestStorage, JSON.stringify(spec.body));
        }
        const response = await fetch(url, {signal,`;
  const replyAnchor = '      return await responseText(response);';
  if (shell.split(replyAnchor).length !== 2) throw new Error('The fork browser acknowledgement hook changed; update the mobile host adapter.');
  const receipt = `      const text = await responseText(response);
        if (options.durableRequestStorage) {
          try {
            const pending = JSON.parse(store?.getItem(options.durableRequestStorage) || 'null');
            const acknowledgement = JSON.parse(text);
            if (pending && Array.isArray(acknowledgement.acceptedRequestIds) && acknowledgement.acceptedRequestIds.includes(pending.requestId)) {
              store?.removeItem(options.durableRequestStorage);
            }
          } catch (problem) { console.warn('Dot retained the pending send because its receipt could not be read:', problem.message); }
        }
        return text;`;
  writeFileSync(shellPath, shell.replace(anchor, anchor + '\n    emitEvent(text) { deliver(bounded(text)); },')
    .replace(renderAnchor, syncInputs).replace(fetchAnchor, persistRequest).replace(replyAnchor, receipt));
  for (const file of readdirSync(join(root, 'mobile'))) {
    if (file !== 'service-worker.js') copyFileSync(join(root, 'mobile', file), join(output, file));
  }
  const assets = readdirSync(output).sort().map(name => {
    const bytes = readFileSync(join(output, name));
    return { name, bytes: bytes.length, sha256: createHash('sha256').update(bytes).digest('hex') };
  });
  const version = createHash('sha256').update(JSON.stringify(assets)).digest('hex').slice(0, 16);
  const metadata = {
    version, compiler: 'PedroAVJ/f Bend2', packagedAt: new Date().toISOString(), assets,
    // These checkouts are observed now; an earlier compilation may have read different edits.
    checkoutAtPackaging: { source: checkoutIdentity(root), fork: checkoutIdentity(join(root, '../f')) },
  };
  writeFileSync(join(output, 'build.json'), JSON.stringify(metadata) + '\n');
  const files = ['/', ...readdirSync(output).map(file => '/' + file)];
  const worker = readFileSync(join(root, 'mobile/service-worker.js'), 'utf8')
    .replace('__BUILD_ID__', version).replace('__STATIC_FILES__', JSON.stringify(files));
  writeFileSync(join(output, 'service-worker.js'), worker);
  const previous = destination + '.previous-' + randomUUID();
  if (existsSync(destination)) renameSync(destination, previous);
  try { renameSync(output, destination); }
  catch (problem) {
    if (existsSync(previous)) renameSync(previous, destination);
    throw problem;
  }
  if (existsSync(previous)) rmSync(previous, { recursive: true });
  console.log('Phone app built at ' + destination);
} finally {
  if (existsSync(output)) rmSync(output, { recursive: true });
}
