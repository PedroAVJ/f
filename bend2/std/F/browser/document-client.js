/* Browser IO for server-rendered Bend documents. Routes, fields and mutations
   are declared by the document; no application schema lives here. */
(() => {
  'use strict';
  let navigating = false;
  let writing = false;
  let drag = null;
  let suppressClick = false;
  let pollFailures = 0;
  const app = () => document.getElementById('app');
  const notice = () => document.getElementById('notice');
  const draftKey = form => `bend-draft:${new URL(form.action).pathname}${new URL(form.action).search}`;
  const sameOrigin = value => {
    const url = new URL(value, location.href);
    if (url.origin !== location.origin) throw Error('The document cannot navigate outside this private origin.');
    return url;
  };
  const status = text => {
    const target = document.querySelector('[data-save-status]');
    if (target) target.textContent = text;
  };
  function message(text, error = false, buttons = []) {
    const target = notice();
    target.replaceChildren(document.createTextNode(text));
    target.hidden = !text;
    target.classList.toggle('error', error);
    for (const [label, run] of buttons) {
      const button = document.createElement('button');
      button.type = 'button';
      button.textContent = label;
      button.addEventListener('click', run);
      target.append(button);
    }
  }
  function fields(form) {
    const result = {};
    for (const element of form.elements) {
      if (!element.name || element.disabled || element.type === 'submit') continue;
      result[element.name] = element.dataset.number ? Number(element.value) : element.value;
    }
    return result;
  }
  function keepDraft(form) {
    if (!form.matches('[data-draft]')) return;
    form.dataset.dirty = 'true';
    status('Unsaved changes');
    try { sessionStorage.setItem(draftKey(form), JSON.stringify(fields(form))); }
    catch { message('This browser cannot retain an unsaved draft. Save before leaving.', true); }
  }
  const dirty = () => document.querySelector('form[data-dirty="true"]');
  function restoreDrafts() {
    for (const form of document.querySelectorAll('form[data-draft]')) {
      let draft;
      try { draft = JSON.parse(sessionStorage.getItem(draftKey(form)) || 'null'); }
      catch { message('A browser draft could not be read. The saved document is unchanged.', true); continue; }
      if (!draft) continue;
      const restore = () => {
        for (const [name, value] of Object.entries(draft)) {
          if (name === 'expectedRevision' || name === 'requestId') continue;
          const input = form.elements.namedItem(name);
          if (input && 'value' in input) input.value = String(value);
        }
        keepDraft(form);
        message('Your unsaved fields are restored. Review them, then save.');
      };
      if (draft.expectedRevision === undefined || draft.expectedRevision === Number(app().dataset.revision)) restore();
      else message('A newer saved revision is shown. An older unsaved draft is retained in this tab.', false, [
        ['Use my draft on this revision', restore],
        ['Discard my unsaved draft', () => { sessionStorage.removeItem(draftKey(form)); message('Unsaved draft discarded.'); }],
      ]);
    }
  }
  async function fetchBounded(url, options = {}) {
    const response = await fetch(sameOrigin(url), {credentials: 'same-origin', cache: 'no-store', signal: AbortSignal.timeout(15000), ...options});
    const reader = response.body.getReader();
    const chunks = [];
    let length = 0;
    try {
      for (;;) {
        const part = await reader.read();
        if (part.done) break;
        length += part.value.byteLength;
        if (length > 2 * 1024 * 1024) { await reader.cancel(); throw Error('Document response is too large.'); }
        chunks.push(part.value);
      }
    } finally { reader.releaseLock(); }
    const bytes = new Uint8Array(length);
    let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
    return {response, text: new TextDecoder().decode(bytes)};
  }
  async function navigate(value, {replace = false, refresh = false, ignoreDraft = false} = {}) {
    if (navigating || writing) return;
    const url = sameOrigin(value);
    if (dirty() && !ignoreDraft && !refresh) {
      message('Your unsaved fields are retained in this tab.', false, [['Leave this form', () => navigate(url, {replace, ignoreDraft: true})]]);
      return;
    }
    if (url.pathname !== location.pathname) { location.assign(url.href); return; }
    navigating = true;
    const scroll = {x: scrollX, y: scrollY};
    try {
      const {response, text} = await fetchBounded(url, {headers: {accept: 'text/html'}});
      if (!response.ok) throw Error(JSON.parse(text).error || `Could not open the document (${response.status}).`);
      const parsed = new DOMParser().parseFromString(text, 'text/html');
      const next = parsed.getElementById('app');
      if (!next) throw Error('The server did not return a document.');
      app().replaceWith(document.importNode(next, true));
      if (!refresh) history[replace ? 'replaceState' : 'pushState'](null, '', url.pathname + url.search);
      message('');
      restoreDrafts();
      scrollTo(scroll.x, scroll.y);
      pollFailures = 0;
    } catch (error) { message(error.message, true); }
    finally { navigating = false; }
  }
  async function submit(form) {
    if (writing || navigating || !form.reportValidity()) return;
    const body = fields(form);
    const fingerprint = JSON.stringify(body);
    if (form.dataset.fingerprint !== fingerprint) {
      form.dataset.requestId = crypto.randomUUID();
      form.dataset.fingerprint = fingerprint;
    }
    body.requestId = form.dataset.requestId;
    writing = true;
    for (const button of form.querySelectorAll('button')) button.disabled = true;
    status('Saving…');
    try {
      const {response, text} = await fetchBounded(form.action, {method: 'POST', headers: {'content-type': 'application/json', accept: 'application/json'}, body: JSON.stringify(body)});
      const result = JSON.parse(text);
      if (!response.ok) {
        status(response.status === 409 ? 'Revision conflict' : 'Not saved');
        message(result.error || `Could not save (${response.status}).`, true, [['Review latest', () => navigate(location.href, {replace: true, ignoreDraft: true})]]);
        return;
      }
      if (!result.uri) throw Error('The save reply did not include a document address.');
      sessionStorage.removeItem(draftKey(form));
      delete form.dataset.dirty;
      writing = false;
      await navigate(result.uri, {replace: true, ignoreDraft: true});
      if (!dirty()) message(result.notice || 'Saved.');
    } catch (error) {
      status('Save unconfirmed');
      message(`Save unconfirmed: ${error.message} Your draft is retained.`, true, [['Review latest', () => navigate(location.href, {replace: true, ignoreDraft: true})]]);
    } finally {
      writing = false;
      for (const button of form.querySelectorAll('button')) button.disabled = false;
    }
  }
  document.addEventListener('submit', event => {
    const form = event.target.closest('form[data-action]');
    if (!form) return;
    event.preventDefault();
    void submit(form);
  });
  document.addEventListener('input', event => {
    const form = event.target.closest('form[data-draft]');
    if (form) keepDraft(form);
  });
  document.addEventListener('change', event => {
    if (event.target.matches('select[data-navigate]')) void navigate(event.target.value);
  });
  document.addEventListener('click', event => {
    if (suppressClick) { event.preventDefault(); suppressClick = false; return; }
    const link = event.target.closest('a[href], [data-nav]');
    if (!link || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    const destination = link.dataset.nav || link.getAttribute('href');
    if (!destination || new URL(destination, location.href).origin !== location.origin) return;
    event.preventDefault();
    void navigate(destination);
  });
  document.addEventListener('keydown', event => {
    const item = event.target.closest('[data-nav]');
    if (item && ['Enter', ' '].includes(event.key)) { event.preventDefault(); void navigate(item.dataset.nav); }
  });
  function point(event, svg) {
    const p = new DOMPoint(event.clientX, event.clientY).matrixTransform(svg.getScreenCTM().inverse());
    return {x: p.x, y: p.y};
  }
  document.addEventListener('pointerdown', event => {
    if (event.button !== 0 || writing || navigating) return;
    const sketch = event.target.closest('[data-sketch-input]');
    if (sketch) {
      const form = sketch.closest('form');
      const input = form.elements.namedItem(sketch.dataset.sketchInput);
      if (!input) return;
      const start = point(event, sketch);
      drag = {kind: 'sketch', node: sketch, form, input, points: [start], pointer: event.pointerId};
      sketch.setPointerCapture(event.pointerId);
      event.preventDefault();
      return;
    }
    const node = event.target.closest('[data-drag-form]');
    if (!node) return;
    const form = document.getElementById(node.dataset.dragForm);
    const svg = node.closest('.artboard');
    if (!form || !svg) return;
    drag = {kind: 'move', node, form, svg, pointer: event.pointerId, start: point(event, svg), x: Number(node.dataset.x), y: Number(node.dataset.y), moved: false};
    node.setPointerCapture(event.pointerId);
    event.preventDefault();
  });
  document.addEventListener('pointermove', event => {
    if (!drag || event.pointerId !== drag.pointer) return;
    if (drag.kind === 'sketch') {
      const p = point(event, drag.node);
      p.x = Math.round(Math.max(0, Math.min(240, p.x)));
      p.y = Math.round(Math.max(0, Math.min(52, p.y)));
      const last = drag.points.at(-1);
      if (Math.hypot(p.x - last.x, p.y - last.y) < 2 || drag.points.length >= 300) return;
      drag.points.push(p);
      const value = drag.points.map(p => `${Math.round(p.x)},${Math.round(p.y)}`).join(' ');
      drag.node.querySelector('polyline').setAttribute('points', value);
      drag.input.value = value;
      keepDraft(drag.form);
      return;
    }
    const p = point(event, drag.svg);
    const dx = p.x - drag.start.x, dy = p.y - drag.start.y;
    if (Math.hypot(dx, dy) < 3 && !drag.moved) return;
    drag.moved = true;
    const x = Math.round(Math.max(0, Math.min(drag.svg.viewBox.baseVal.width - Number(drag.node.dataset.width), drag.x + dx)));
    const y = Math.round(Math.max(0, Math.min(drag.svg.viewBox.baseVal.height - Number(drag.node.dataset.height), drag.y + dy)));
    drag.node.setAttribute('transform', `translate(${x} ${y})`);
    drag.form.elements.namedItem('x').value = String(x);
    drag.form.elements.namedItem('y').value = String(y);
    keepDraft(drag.form);
  });
  function endPointer(event) {
    if (!drag || event.pointerId !== drag.pointer) return;
    const completed = drag;
    drag = null;
    completed.node.releasePointerCapture(event.pointerId);
    if (completed.kind === 'move' && completed.moved) {
      suppressClick = true;
      if (event.type === 'pointerup') completed.form.requestSubmit();
      else message('Movement is kept as an unsaved draft. Save changes to keep it.');
    }
  }
  document.addEventListener('pointerup', endPointer);
  document.addEventListener('pointercancel', endPointer);
  window.addEventListener('popstate', () => { void navigate(location.href, {replace: true, ignoreDraft: true}); });
  window.addEventListener('beforeunload', event => { if (dirty() || writing) { event.preventDefault(); event.returnValue = ''; } });
  setInterval(async () => {
    if (document.hidden || navigating || writing || drag) return;
    const root = app();
    if (!root?.dataset.poll) return;
    try {
      const {response, text} = await fetchBounded(root.dataset.poll);
      if (!response.ok) throw Error('Private connection unavailable.');
      const latest = JSON.parse(text).revision;
      if (root !== app() || navigating || writing) return;
      if (String(latest) !== root.dataset.revision) {
        if (dirty()) message('A newer revision is available. Your unsaved fields are still here.', false, [['Review latest', () => navigate(location.href, {replace: true, ignoreDraft: true})]]);
        else await navigate(location.href, {refresh: true});
      }
      if (pollFailures && !dirty()) status(`Saved · revision ${app().dataset.revision}`);
      pollFailures = 0;
    } catch {
      pollFailures++;
      status('Offline · draft retained');
    }
  }, 3000);
  restoreDrafts();
})();
