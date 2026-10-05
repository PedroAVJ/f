import { startBend } from './shell.js';
import { createDotHost } from './host.mjs';

const status = document.querySelector('#boot-status');
try {
  const app = startBend(document.querySelector('#app'), {
    workers: 1,
    host: createDotHost,
    onMessage(message) {
      if (message.type === 'stderr') console.error('Dot runtime:', message.text);
      if (message.type === 'error') {
        console.error('Dot runtime failed:', message.text);
        status.textContent = 'Dot could not start. Reload this page to try again.';
        status.style.display = 'block';
      }
    },
  });
  window.addEventListener('pagehide', () => app.stop(), { once: true });
  window.addEventListener('pageshow', e => { if (e.persisted) location.reload(); });
} catch {
  status.textContent = 'Dot could not start. Reload this page to try again.';
}
