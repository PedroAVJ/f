import { responseText, sameOrigin, forgetAcceptedCaption } from './transport.mjs';

function database() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open('dot-media', 1);
    request.onupgradeneeded = () => request.result.createObjectStore('drafts');
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(Error('Could not open saved media.'));
  });
}

async function stored(mode, operation) {
  const db = await database();
  try {
    return await new Promise((resolve, reject) => {
      const transaction = db.transaction('drafts', mode);
      const request = operation(transaction.objectStore('drafts'));
      transaction.oncomplete = () => resolve(request.result);
      transaction.onerror = transaction.onabort = () => reject(Error('Could not save the media draft.'));
    });
  } finally { db.close(); }
}

export async function preparePhoto(file, maxBytes = 5 * 1024 * 1024) {
  if (file.size > 32 * 1024 * 1024) throw Error('Choose a photo smaller than 32 MiB.');
  const bitmap = await createImageBitmap(file);
  try {
    const canvas = document.createElement('canvas');
    let scale = Math.min(1, 2560 / Math.max(bitmap.width, bitmap.height));
    for (let attempt = 0; attempt < 8; attempt++) {
      const width = Math.max(1, Math.round(bitmap.width * scale));
      const height = Math.max(1, Math.round(bitmap.height * scale));
      canvas.width = width; canvas.height = height;
      canvas.getContext('2d').drawImage(bitmap, 0, 0, width, height);
      const quality = Math.max(0.55, 0.88 - attempt * 0.08);
      const blob = await new Promise(resolve => canvas.toBlob(resolve, 'image/jpeg', quality));
      if (!blob) throw Error('The browser could not prepare this photo.');
      if (blob.size <= maxBytes) return { blob, width, height };
      scale *= 0.8;
    }
    throw Error('The photo is too large for this app. Try a closer photo.');
  } finally { bitmap.close(); }
}

export function createMediaHost(event, { maxImageBytes = 5 * 1024 * 1024 } = {}) {
  let recorder, recording, microphone, recordingTimer, call, recognition, speaking, player, picker;
  let closed = false, recordingGeneration = 0;
  const urls = new Set();
  const urlFor = blob => { const url = URL.createObjectURL(blob); urls.add(url); return url; };
  const voice = (session, mode, phase, values = {}) => event({ action: 'voice', data: { session, mode, phase, ...values } });
  const image = (session, phase, values = {}) => event({ action: 'image', data: { session, phase, ...values } });
  const documentEvent = (session, phase, values = {}) => event({ action: 'file', data: { session, phase, ...values } });
  let fileEdits = Promise.resolve(), documentSession;
  const stopMicrophone = () => { microphone?.getTracks().forEach(track => track.stop()); microphone = undefined; clearInterval(recordingTimer); };

  async function record(spec) {
    if (recorder?.state === 'recording') throw Error('A recording is already active.');
    if (!navigator.mediaDevices?.getUserMedia || !globalThis.MediaRecorder) throw Error('Voice recording is unavailable in this browser.');
    const mimeType = ['audio/mp4', 'audio/webm;codecs=opus'].find(type => MediaRecorder.isTypeSupported(type));
    if (!mimeType) throw Error('This browser has no supported voice recording format.');
    const generation = ++recordingGeneration;
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    if (closed || generation !== recordingGeneration) { stream.getTracks().forEach(track => track.stop()); return; }
    microphone = stream;
    recording = { id: crypto.randomUUID(), session: spec.session, started: Date.now(), chunks: [], cancelled: false };
    const held = recording;
    try { recorder = new MediaRecorder(microphone, { mimeType, audioBitsPerSecond: 64_000 }); }
    catch (error) { stopMicrophone(); throw error; }
    recorder.ondataavailable = e => { if (e.data.size) held.chunks.push(e.data); };
    recorder.onerror = () => { stopMicrophone(); voice(held.session, 'message', 'error', { error: 'The browser could not finish recording.' }); };
    recorder.onstop = async () => {
      stopMicrophone();
      if (held.cancelled) return;
      try {
        const blob = new Blob(held.chunks, { type: mimeType.split(';')[0] });
        if (!blob.size || blob.size > 16 * 1024 * 1024) throw Error('The recording must be at most 16 MiB.');
        const draft = { kind: 'audio', id: held.id, session: held.session, blob, durationMs: Math.min(300_000, Math.max(1, Date.now() - held.started)) };
        await stored('readwrite', store => store.put(draft, 'audio'));
        voice(held.session, 'message', 'recorded', { clipId: draft.id, durationMs: draft.durationMs, transcript: '' });
      } catch (error) { voice(held.session, 'message', 'error', { error: error.message }); }
    };
    recorder.start(1000);
    voice(held.session, 'message', 'recording', { clipId: held.id });
    recordingTimer = setInterval(() => {
      const elapsedMs = Date.now() - held.started;
      voice(held.session, 'message', 'elapsed', { elapsedMs, level: 0 });
      if (elapsedMs >= 300_000 && recorder.state === 'recording') recorder.stop();
    }, 500);
  }

  function endCall() {
    if (!call) return;
    const held = call; call = undefined;
    clearInterval(held.timer); recognition?.abort(); recognition = undefined;
    speechSynthesis.cancel(); speaking = undefined;
    voice(held.session, 'call', 'ended', { elapsedMs: Date.now() - held.started });
  }

  function listen() {
    if (!call || call.muted || speaking || recognition) return;
    const Recognition = globalThis.SpeechRecognition ?? globalThis.webkitSpeechRecognition;
    const held = call;
    recognition = new Recognition();
    const controller = recognition;
    recognition.lang = held.locale; recognition.interimResults = false; recognition.continuous = false;
    recognition.onresult = e => {
      if (call !== held || recognition !== controller) return;
      held.awaitingReply = true;
      voice(held.session, 'call', 'transcript', { text: e.results[0][0].transcript, elapsedMs: Date.now() - held.started });
    };
    recognition.onerror = e => {
      if (call !== held || recognition !== controller) return;
      if (e.error === 'aborted' || e.error === 'no-speech') return;
      voice(held.session, 'call', 'error', { error: 'Speech recognition is unavailable. Check microphone access or send a voice message.' });
      endCall();
    };
    recognition.onend = () => {
      if (recognition !== controller) return;
      recognition = undefined;
      if (call === held && !held.awaitingReply && !held.muted && !speaking) listen();
    };
    try { recognition.start(); }
    catch (error) { recognition = undefined; endCall(); throw error; }
    voice(held.session, 'call', 'listening', { elapsedMs: Date.now() - held.started });
  }

  async function voiceCommand(spec) {
    if (spec.action === 'record') return record(spec);
    if (spec.action === 'record-stop') { if (recorder?.state === 'recording') recorder.stop(); return; }
    if (spec.action === 'record-cancel') {
      recordingGeneration++;
      const draft = await stored('readonly', store => store.get('audio'));
      if (draft?.metadata?.requestId) throw Error('Check the pending send before discarding this recording.');
      if (recording) recording.cancelled = true;
      if (recorder?.state === 'recording') recorder.stop();
      stopMicrophone(); await stored('readwrite', store => store.delete('audio')); return;
    }
    if (spec.action === 'play') {
      player?.pause();
      let source;
      if (spec.url) source = sameOrigin(spec.url).href;
      else {
        const draft = await stored('readonly', store => store.get('audio'));
        if (!draft || draft.id !== spec.clipId) throw Error('The recording is no longer available.');
        source = urlFor(draft.blob);
      }
      player = new Audio(source);
      await player.play(); return;
    }
    if (spec.action === 'call') {
      if (!(globalThis.SpeechRecognition ?? globalThis.webkitSpeechRecognition) || !globalThis.speechSynthesis) throw Error('Calls are unavailable in this browser. You can still send voice messages.');
      endCall();
      call = { session: spec.session, started: Date.now(), locale: spec.locale === 'es' ? 'es-MX' : 'en-US', muted: false, speaker: true, awaitingReply: false };
      const held = call;
      held.timer = setInterval(() => voice(held.session, 'call', 'elapsed', { elapsedMs: Date.now() - held.started, muted: held.muted, speaker: true }), 1000);
      listen(); return;
    }
    if (spec.action === 'end') { endCall(); return; }
    if (!call || call.session !== spec.session) throw Error('The call is no longer active.');
    if (spec.action === 'mute' || spec.action === 'unmute') {
      call.muted = spec.action === 'mute';
      if (call.muted) recognition?.abort(); else listen();
      voice(call.session, 'call', 'elapsed', { elapsedMs: Date.now() - call.started, muted: call.muted, speaker: true }); return;
    }
    if (spec.action === 'speaker') {
      endCall();
      throw Error('Choose the speaker or headphones in your device’s audio controls before starting the call.');
    }
    if (spec.action === 'listen') { call.awaitingReply = false; listen(); return; }
    if (spec.action === 'speak') {
      recognition?.abort();
      speaking = new SpeechSynthesisUtterance(spec.text); speaking.lang = call.locale;
      const held = call, utterance = speaking;
      speaking.onend = () => { if (call !== held || speaking !== utterance) return; speaking = undefined; voice(held.session, 'call', 'spoken', { elapsedMs: Date.now() - held.started }); };
      speaking.onerror = () => { if (call !== held || speaking !== utterance) return; speaking = undefined; voice(held.session, 'call', 'error', { error: 'The browser could not play the reply.' }); endCall(); };
      speechSynthesis.speak(speaking); return;
    }
    throw Error('Unknown voice action.');
  }

  async function photoCommand(spec) {
    if (spec.action === 'cancel') {
      const draft = await stored('readonly', store => store.get('image'));
      if (draft?.metadata?.requestId) throw Error('Check the pending send before discarding this photo.');
      picker?.remove(); await stored('readwrite', store => store.delete('image')); return;
    }
    if (spec.action === 'load') {
      image(spec.session, 'loaded', { imageId: spec.imageId, url: sameOrigin(spec.url).href }); return;
    }
    if (spec.action !== 'pick' && spec.action !== 'camera') throw Error('Unknown photo action.');
    picker?.remove(); picker = document.createElement('input'); picker.type = 'file'; picker.accept = 'image/*';
    if (spec.action === 'camera') picker.capture = 'environment';
    picker.hidden = true; document.body.append(picker);
    picker.oncancel = () => { picker.remove(); image(spec.session, 'cancelled'); };
    picker.onchange = async () => {
      const file = picker.files?.[0]; picker.remove();
      if (!file) { image(spec.session, 'cancelled'); return; }
      try {
        const { blob, width, height } = await preparePhoto(file, maxImageBytes);
        const draft = { kind: 'image', id: crypto.randomUUID(), session: spec.session, blob, width, height };
        await stored('readwrite', store => store.put(draft, 'image'));
        image(spec.session, 'selected', { imageId: draft.id, url: urlFor(blob), width, height });
      } catch (error) { image(spec.session, 'error', { error: error.message }); }
    };
    picker.click();
  }

  async function acknowledge(accepted) {
    for (const kind of ['audio', 'image', 'file']) {
      const draft = await stored('readonly', store => store.get(kind));
      if (!draft?.metadata || !accepted.includes(draft.metadata.requestId)) continue;
      await stored('readwrite', store => store.delete(kind));
      if (kind === 'file') documentSession = undefined;
      forgetAcceptedCaption(draft.metadata.text);
      event({ action: 'pending', data: { kind, id: draft.metadata.requestId,
        thread: draft.metadata.threadId, text: draft.metadata.text,
        clipId: draft.id, durationMs: draft.durationMs, transcript: '' } });
    }
  }

  async function fileCommand(spec) {
    if (spec.action === 'open') {
      const url = sameOrigin(spec.url);
      if (!/^[a-f0-9]{64}$/.test(spec.fileId) || url.pathname !== '/api/file/' + spec.fileId || url.search || url.hash) throw Error('Invalid file link.');
      const link = document.createElement('a'); link.href = url.href; link.download = spec.name; link.rel = 'noopener'; link.click(); return;
    }
    const held = await stored('readonly', store => store.get('file'));
    if (spec.action === 'cancel') {
      if (held?.metadata?.requestId) throw Error('Check the pending send before discarding this file.');
      picker?.remove(); await stored('readwrite', store => store.delete('file')); documentSession = undefined; return;
    }
    if (spec.action !== 'pick') throw Error('Unknown file action.');
    if (held) throw Error('Send or remove the current file first.');
    documentSession = spec.session;
    picker?.remove(); picker = document.createElement('input'); picker.type = 'file';
    picker.hidden = true; document.body.append(picker);
    picker.oncancel = () => { picker.remove(); documentEvent(spec.session, 'cancelled'); };
    picker.onchange = async () => {
      const file = picker.files?.[0]; picker.remove();
      if (!file) { documentEvent(spec.session, 'cancelled'); return; }
      try {
        if (file.size > 20 * 1024 * 1024 || !file.name || file.name.length > 255 || /[\x00-\x1f\x7f/\\]/.test(file.name) || ['.', '..'].includes(file.name)) throw Error('Choose a file of at most 20 MiB with a valid filename.');
        const draft = { kind:'file', id:crypto.randomUUID(), session:spec.session, blob:file, name:file.name, mimeType:file.type || 'application/octet-stream', size:file.size, caption:spec.caption || '' };
        await stored('readwrite', store => store.put(draft, 'file'));
        documentEvent(spec.session, 'selected', { fileId:draft.id, name:draft.name, mimeType:draft.mimeType, size:draft.size });
      } catch (error) { documentEvent(spec.session, 'error', { error:error.message }); }
    };
    picker.click();
  }

  return {
    acknowledge,
    edited(caption) {
      if (!documentSession) return;
      fileEdits = fileEdits.then(async () => {
        try {
          const draft = await stored('readonly', store => store.get('file'));
          if (!draft || draft.metadata) return;
          await stored('readwrite', store => store.put({ ...draft, caption }, 'file'));
        } catch (error) { documentEvent(documentSession, 'error', { error:error.message }); }
      });
      return fileEdits;
    },
    async request(operation, spec, signal) {
      if (operation === 10) { await voiceCommand(spec); return ''; }
      if (operation === 12) { await photoCommand(spec); return ''; }
      if (operation === 16) { await fileCommand(spec); return ''; }
      const kind = operation === 17 ? 'file' : operation === 11 ? 'audio' : 'image';
      if (kind === 'file') await fileEdits;
      const draft = await stored('readonly', store => store.get(kind));
      if (!draft || draft.id !== (spec.body.clipId ?? spec.body.imageId ?? spec.body.fileId)) throw Error('The media draft is no longer available.');
      if (kind === 'file' && draft.metadata && JSON.stringify(draft.metadata) !== JSON.stringify(spec.body)) throw Error('File retries must retain their original caption and request identifier.');
      draft.metadata = spec.body;
      await stored('readwrite', store => store.put(draft, kind));
      const body = new FormData();
      const filename = kind === 'file' ? encodeURIComponent(draft.name).replace(/[!'()*]/g, c => '%' + c.charCodeAt(0).toString(16).toUpperCase()) : kind === 'image' ? 'photo.jpg' : draft.blob.type === 'audio/mp4' ? 'voice.m4a' : 'voice.webm';
      body.set(kind, draft.blob, filename);
      body.set('metadata', JSON.stringify(kind === 'file' ? { ...spec.body, name:draft.name } : spec.body));
      const text = await responseText(await fetch(sameOrigin(spec.url), { method: 'POST', body, signal, credentials: 'same-origin' }));
      await acknowledge(JSON.parse(text).acceptedRequestIds ?? []);
      return text;
    },
    async restore(accepted) {
      for (const kind of ['audio', 'image', 'file']) {
        const draft = await stored('readonly', store => store.get(kind));
        if (!draft) continue;
        if (accepted.includes(draft.metadata?.requestId)) { await stored('readwrite', store => store.delete(kind)); continue; }
        const values = { restored: true, requestId: draft.metadata?.requestId ?? '', threadId: draft.metadata?.threadId ?? '', caption: draft.metadata?.text ?? draft.caption ?? '' };
        if (kind === 'audio') {
          voice(draft.session, 'message', 'recorded', { ...values, clipId: draft.id, durationMs: draft.durationMs, transcript: '' });
          if (draft.metadata) event({ action: 'pending', data: {
            kind: 'audio', id: draft.metadata.requestId, thread: draft.metadata.threadId,
            text: draft.metadata.text, clipId: draft.id, durationMs: draft.durationMs, transcript: '',
          } });
        }
        else if (kind === 'file') { documentSession = draft.session; documentEvent(draft.session, 'selected', { ...values, fileId:draft.id, name:draft.name, mimeType:draft.mimeType, size:draft.size }); }
        else image(draft.session, 'selected', { ...values, imageId: draft.id, width: draft.width, height: draft.height, url: urlFor(draft.blob) });
      }
    },
    close() {
      closed = true; recordingGeneration++;
      if (recorder?.state === 'recording') recorder.stop();
      stopMicrophone(); endCall(); player?.pause(); picker?.remove();
      for (const url of urls) URL.revokeObjectURL(url);
    },
  };
}
