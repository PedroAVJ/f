import { copyFileSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { materializeAssets, forkRoot, type Config, type Connection } from './config.ts';

export async function emitWebAssets(root: string, config: Config, destination: string, connections?: Connection[], compilerRoot = forkRoot) {
  const child = Bun.spawn(['bun', join(compilerRoot, 'bend2/tool.ts'), join(root, 'browser_policy.bend'), '-o', join(destination, 'policy.mjs')], {cwd:root, stdout:'inherit', stderr:'inherit'});
  if (await child.exited !== 0) throw Error('Browser policy compilation failed.');
  mkdirSync(destination, {recursive:true});
  copyFileSync(join(compilerRoot, 'bend2/std/F/browser/client.js'), join(destination, 'client.js'));
  const catalog = connections ?? config.connections.map(item => ({...item, origin: item.origin === config.origin ? '' : item.origin}));
  const escape = (text: string) => text.replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]!));
  writeFileSync(join(destination, 'index.html'), `<!doctype html>
  <html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover"><meta name="color-scheme" content="dark"><meta name="robots" content="noindex,nofollow"><title>${escape(config.name)}</title><link rel="stylesheet" href="./app.css"></head>
  <body><main id="app" aria-label="${escape(config.name)}" aria-busy="true"></main><p id="boot-status" role="status">Opening ${escape(config.name)}…</p><script type="module" src="./app.mjs"></script></body></html>\n`);
  writeFileSync(join(destination, 'app.css'), `:root{color-scheme:dark;background:#000;color:#eee;font:17px/1.4 system-ui}*{box-sizing:border-box}body{margin:0}#app{position:relative;width:100%;max-width:1000px;min-height:100dvh;margin-inline:auto;white-space:pre;line-height:1.2}#app textarea{white-space:pre-wrap}#boot-status{position:fixed;inset:45% 20px auto;text-align:center}#app[aria-busy="false"]+#boot-status{display:none}#app [role="log"],#app [role="region"]{scrollbar-width:thin;touch-action:pan-y}button{cursor:pointer}button:disabled{cursor:default}button:focus-visible,#app [role="log"]:focus-visible,#app [role="region"]:focus-visible{outline:2px solid #ddd;outline-offset:3px;border-radius:10px}[data-bend-field]:focus-visible{box-shadow:inset 0 0 0 1px #777;border-radius:24px}@media(prefers-reduced-motion:reduce){*{scroll-behavior:auto!important}}\n`);
  writeFileSync(join(destination, 'app.mjs'), `import { startBend } from './shell.js';
  import { createBrowserClient } from './client.js';
  import policy from './policy.mjs';
  const catalog = ${JSON.stringify(catalog)};
  const status = document.querySelector('#boot-status');
  const failed = () => { status.textContent = ${JSON.stringify(config.name + ' could not start. Reload this page to try again.')}; status.style.display = 'block'; };
  try {
    const app = startBend(document.querySelector('#app'), {
      workers: 1,
      host: context => createBrowserClient({...context, policy, catalog}),
      onMessage(message) { if (message.type === 'stderr') console.error(message.text); if (message.type === 'error') { console.error(message.text); failed(); } },
    });
    window.addEventListener('pagehide', () => app.stop(), {once:true});
    window.addEventListener('pageshow', event => { if (event.persisted) location.reload(); });
  } catch (error) { console.error(error); failed(); }
  `);
  const assets = materializeAssets(config, destination);
  const manifestPath = join(destination, 'manifest.json');
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  manifest.files = [...new Set([...manifest.files, 'index.html', 'app.css', 'app.mjs', 'client.js', 'policy.mjs', ...assets.map(asset => asset.name)])];
  manifest.assets = assets;
  writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + '\n');
  return manifest;
}
