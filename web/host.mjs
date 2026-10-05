import { createMediaHost } from './media.mjs';

import { responseText, sameOrigin, forgetAcceptedCaption } from './transport.mjs';

const PENDING = 'dot.pending';

export function createDotHost({ root, deliver }) {
  const event = value => deliver(JSON.stringify(value));
  const imageLimit = Number(root.dataset.maxImageBytes);
  const media = createMediaHost(event, {
    maxImageBytes: Number.isSafeInteger(imageLimit) && imageLimit >= 65536 && imageLimit <= 5 * 1024 * 1024 ? imageLimit : undefined,
  });
  let restored = false, initialized = false, refreshQueued = false, thread, atBottom = true, lastHeight = 0, prepend = false;
  let displayedReview, pendingReview, browserSession, processingSendReview, processingRefresh = false;
  const sendReviews = [];
  const isSend = text => text === 'button · Send' || text === 'button · Enviar';
  const observeSnapshot = text => {
    const snapshot = JSON.parse(text);
    pendingReview = { provider: snapshot.provider, context: snapshot.reviewContext ?? null };
    return snapshot;
  };
  const viewport = () => ({ action: 'resize', width: Math.max(320, Math.floor(root.clientWidth)), height: Math.max(240, Math.floor(globalThis.visualViewport?.height ?? innerHeight)) });
  const resize = () => { if (initialized) event(viewport()); };
  const refresh = () => {
    if (!document.hidden && !refreshQueued) { refreshQueued = true; event({ action: 'refresh' }); }
  };
  const interval = setInterval(refresh, 1500);
  const observer = new ResizeObserver(resize);
  observer.observe(root);
  globalThis.visualViewport?.addEventListener('resize', resize);
  window.addEventListener('online', refresh);
  document.addEventListener('visibilitychange', refresh);
  const recordScroll = () => { atBottom = thread.scrollHeight - thread.scrollTop - thread.clientHeight < 40; };
  const click = e => {
    const button = e.target.closest('[data-bend-event]');
    if (button && !button.disabled && isSend(button.dataset.bendEvent)) sendReviews.push({ ...displayedReview });
    const prefix = 'button · open-url:';
    if (!button?.dataset.bendEvent.startsWith(prefix)) return;
    e.stopImmediatePropagation();
    const url = new URL(button.dataset.bendEvent.slice(prefix.length), location.href);
    if (['http:', 'https:'].includes(url.protocol)) window.open(url.href, '_blank', 'noopener,noreferrer');
  };
  const keydown = e => {
    if (e.key !== 'Enter' || e.shiftKey || e.isComposing || !e.target.matches('[data-bend-field="textbox · Message"],[data-bend-field="textbox · Mensaje"]')) return;
    if (root.querySelector('[data-bend-event="button · Close"],[data-bend-event="button · Cerrar"]')) return;
    const send = root.querySelector('[data-bend-event="button · Send"],[data-bend-event="button · Enviar"]');
    if (send && !send.disabled) { e.preventDefault(); send.click(); }
  };
  root.addEventListener('click', click, true);
  root.addEventListener('keydown', keydown);

  async function request(operation, data, signal) {
    if (operation === 9) {
      if (!initialized) {
        initialized = true;
        browserSession = crypto.randomUUID();
        event({ action: 'session', value: browserSession });
        event({ action: 'language', value: navigator.language.startsWith('es') ? 'es' : 'en' });
      }
      return JSON.stringify(viewport());
    }
    if (operation === 7 || operation === 8) return '';
    if (operation >= 10 && operation <= 13) {
      const spec = JSON.parse(data);
      // Session initialization is queued before these startup photo events.
      if (operation === 12 && spec.action === 'load' && !spec.session) spec.session = browserSession;
      const text = await media.request(operation, spec, signal);
      if (operation === 11 || operation === 13) observeSnapshot(text);
      return text;
    }
    if (operation !== 3 && operation !== 6) return undefined;
    const spec = operation === 3 ? { url: data } : JSON.parse(data);
    const url = sameOrigin(spec.url);
    if (url.searchParams.has('before')) prepend = true;
    if (url.pathname === '/api/turn' && operation === 6) {
      // Preserve the displayed review across retries as well as the receipt ID.
      let held;
      try { held = JSON.parse(localStorage.getItem(PENDING)); } catch { /* Invalid saved context cannot override the displayed review. */ }
      if (displayedReview?.provider === 'bakery') {
        spec.body.reviewContext = held?.id === spec.body.requestId && Object.hasOwn(held, 'reviewContext') ? held.reviewContext : (processingSendReview?.context ?? null);
      }
      localStorage.setItem(PENDING, JSON.stringify({ id: spec.body.requestId, thread: spec.body.threadId, text: spec.body.text, kind: spec.body.mode === 'call' ? 'call' : 'text', ...(displayedReview?.provider === 'bakery' ? { reviewContext: spec.body.reviewContext } : {}) }));
    }
    const response = await fetch(url, { signal, credentials: 'same-origin', ...(operation === 6 ? {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(spec.body),
    } : {}) });
    const text = await responseText(response);
    const snapshot = observeSnapshot(text);
    let pending;
    try { pending = JSON.parse(localStorage.getItem(PENDING)); } catch { /* A malformed local receipt is not sent. */ }
    if (pending && snapshot.acceptedRequestIds?.includes(pending.id)) {
      localStorage.removeItem(PENDING); forgetAcceptedCaption(pending.text);
    }
    await media.acknowledge(snapshot.acceptedRequestIds ?? []);
    if (!restored && url.pathname === '/api/session') {
      restored = true;
      if (pending) event({ action: 'pending', data: pending });
      await media.restore(snapshot.acceptedRequestIds ?? []);
    }
    return text;
  }

  return {
    request,
    eventConsumed(text) {
      processingSendReview = isSend(text) ? sendReviews.shift() : undefined;
      try { processingRefresh = JSON.parse(text).action === 'refresh'; } catch { processingRefresh = false; }
    },
    rendered() {
      if (processingRefresh) { refreshQueued = false; processingRefresh = false; }
      if (pendingReview) { displayedReview = pendingReview; pendingReview = undefined; }
      for (const button of root.querySelectorAll('[data-bend-event="button · Speaker"],[data-bend-event="button · Altavoz"]')) {
        button.disabled = true;
        button.title = 'Audio output is selected in your device’s audio controls.';
      }
      const next = root.querySelector('#dot-thread');
      if (thread !== next) {
        thread?.removeEventListener('scroll', recordScroll);
        thread = next;
        thread?.addEventListener('scroll', recordScroll, { passive: true });
        atBottom = true; lastHeight = 0;
      }
      if (thread) {
        if (prepend && lastHeight) thread.scrollTop += thread.scrollHeight - lastHeight;
        else if (atBottom) thread.scrollTop = thread.scrollHeight;
        lastHeight = thread.scrollHeight; prepend = false;
      }
      root.setAttribute('aria-busy', 'false');
    },
    close() {
      clearInterval(interval); observer.disconnect();
      globalThis.visualViewport?.removeEventListener('resize', resize);
      window.removeEventListener('online', refresh);
      document.removeEventListener('visibilitychange', refresh);
      root.removeEventListener('click', click, true); root.removeEventListener('keydown', keydown);
      thread?.removeEventListener('scroll', recordScroll);
      media.close();
    },
  };
}
