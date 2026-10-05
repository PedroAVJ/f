import { startBend } from './shell.js';

const root = document.getElementById('app');
const error = document.getElementById('runtime-error');
let pending;
try { pending = JSON.parse(localStorage.getItem('dot-pending-request') || 'null'); }
catch (problem) { console.warn('Dot could not restore a pending send:', problem.message); }
let restored = false;
const app = startBend(root, {
  persistRenderedInputs: true,
  durableRequestStorage: 'dot-pending-request',
  onRender() {
    if (restored) return;
    restored = true;
    if (pending) app.emitEvent(JSON.stringify({ action: 'pending', data: {
      id: pending.requestId, thread: pending.threadId, text: pending.text
    } }));
  },
  onMessage(message) {
    if (message.type === 'error' || message.type === 'stderr') {
      error.textContent = 'Dot no pudo abrirse. ' + message.text;
      error.hidden = false;
    }
  }
});
app.emitEvent(JSON.stringify({ action: 'session', value: crypto.randomUUID() }));

function resize() {
  const viewport = window.visualViewport;
  if (viewport && viewport.scale > 1) return;
  const height = Math.floor(viewport?.height ?? window.innerHeight);
  document.documentElement.style.setProperty('--dot-height', height + 'px');
  document.documentElement.style.setProperty('--dot-top', (viewport?.offsetTop ?? 0) + 'px');
  const stage = getComputedStyle(document.getElementById('stage'));
  const padding = parseFloat(stage.paddingTop) + parseFloat(stage.paddingBottom);
  app.emitEvent(JSON.stringify({
    action: 'resize', width: Math.floor(root.clientWidth), height: Math.max(200, height - padding)
  }));
}
resize();
window.addEventListener('resize', resize);
window.visualViewport?.addEventListener('resize', resize);
window.visualViewport?.addEventListener('scroll', resize);
window.addEventListener('pageshow', resize);
document.addEventListener('visibilitychange', () => {
  if (!document.hidden) {
    resize();
    app.emitEvent(JSON.stringify({ action: 'refresh' }));
  }
});
setInterval(() => {
  if (!document.hidden) app.emitEvent(JSON.stringify({ action: 'refresh' }));
}, 1500);
root.addEventListener('keydown', event => {
  if (event.key === 'Enter' && !event.isComposing && event.target.matches('[data-bend-field]')) {
    const send = root.querySelector('[data-bend-event="button · Enviar"]');
    if (send && !send.disabled) { event.preventDefault(); send.click(); }
  }
});
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('/service-worker.js').catch(problem => {
    console.warn('Dot offline cache unavailable:', problem.message);
  });
}
