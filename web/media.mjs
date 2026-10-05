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

export function createMediaHost(event) {
  let recorder, recording, microphone, recordingTimer, call, recognition, speaking, player, picker;
  let closed = false, recordingGeneration = 0;
  const urls = new Set();
  const urlFor = blob => { const url = URL.createObjectURL(blob); urls.add(url); return url; };
  const voice = (session, mode, phase, values = {}) => event({ action: 'voice', data: { session, mode, phase, ...values } });
  const image = (session, phase, values = {}) => event({ action: 'image', data: { session, phase, ...values } });
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
    if (spec.action !== 'pick') throw Error('Unknown photo action.');
    picker?.remove(); picker = document.createElement('input'); picker.type = 'file'; picker.accept = 'image/*';
    picker.hidden = true; document.body.append(picker);
    picker.oncancel = () => { picker.remove(); image(spec.session, 'cancelled'); };
    picker.onchange = async () => {
      const file = picker.files?.[0]; picker.remove();
      if (!file) { image(spec.session, 'cancelled'); return; }
      try {
        if (file.size > 32 * 1024 * 1024) throw Error('Choose a photo smaller than 32 MiB.');
        const bitmap = await createImageBitmap(file);
        let blob, width, height;
        try {
          const scale = Math.min(1, 2560 / Math.max(bitmap.width, bitmap.height));
          width = Math.max(1, Math.round(bitmap.width * scale)); height = Math.max(1, Math.round(bitmap.height * scale));
          const canvas = document.createElement('canvas'); canvas.width = width; canvas.height = height;
          canvas.getContext('2d').drawImage(bitmap, 0, 0, width, height);
          blob = await new Promise(resolve => canvas.toBlob(resolve, 'image/jpeg', 0.88));
        } finally { bitmap.close(); }
        if (!blob || blob.size > 5 * 1024 * 1024) throw Error('The photo must fit within 5 MiB after resizing.');
        const draft = { kind: 'image', id: crypto.randomUUID(), session: spec.session, blob, width, height };
        await stored('readwrite', store => store.put(draft, 'image'));
        image(spec.session, 'selected', { imageId: draft.id, url: urlFor(blob), width, height });
      } catch (error) { image(spec.session, 'error', { error: error.message }); }
    };
    picker.click();
  }

  async function acknowledge(accepted) {
    for (const kind of ['audio', 'image']) {
      const draft = await stored('readonly', store => store.get(kind));
      if (!draft?.metadata || !accepted.includes(draft.metadata.requestId)) continue;
      await stored('readwrite', store => store.delete(kind));
      forgetAcceptedCaption(draft.metadata.text);
      event({ action: 'pending', data: { kind, id: draft.metadata.requestId,
        thread: draft.metadata.threadId, text: draft.metadata.text,
        clipId: draft.id, durationMs: draft.durationMs, transcript: '' } });
    }
  }

  return {
    acknowledge,
    async request(operation, spec, signal) {
      if (operation === 10) { await voiceCommand(spec); return ''; }
      if (operation === 12) { await photoCommand(spec); return ''; }
      const kind = operation === 11 ? 'audio' : 'image';
      const draft = await stored('readonly', store => store.get(kind));
      if (!draft || draft.id !== (spec.body.clipId ?? spec.body.imageId)) throw Error('The media draft is no longer available.');
      draft.metadata = spec.body;
      await stored('readwrite', store => store.put(draft, kind));
      const body = new FormData();
      body.set(kind, draft.blob, kind === 'image' ? 'photo.jpg' : draft.blob.type === 'audio/mp4' ? 'voice.m4a' : 'voice.webm');
      body.set('metadata', JSON.stringify(spec.body));
      const text = await responseText(await fetch(sameOrigin(spec.url), { method: 'POST', body, signal, credentials: 'same-origin' }));
      await acknowledge(JSON.parse(text).acceptedRequestIds ?? []);
      return text;
    },
    async restore(accepted) {
      for (const kind of ['audio', 'image']) {
        const draft = await stored('readonly', store => store.get(kind));
        if (!draft) continue;
        if (accepted.includes(draft.metadata?.requestId)) { await stored('readwrite', store => store.delete(kind)); continue; }
        const values = { restored: true, requestId: draft.metadata?.requestId ?? '', threadId: draft.metadata?.threadId ?? '', caption: draft.metadata?.text ?? '' };
        if (kind === 'audio') {
          voice(draft.session, 'message', 'recorded', { ...values, clipId: draft.id, durationMs: draft.durationMs, transcript: '' });
          if (draft.metadata) event({ action: 'pending', data: {
            kind: 'audio', id: draft.metadata.requestId, thread: draft.metadata.threadId,
            text: draft.metadata.text, clipId: draft.id, durationMs: draft.durationMs, transcript: '',
          } });
        }
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
