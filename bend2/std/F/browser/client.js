// Raw browser IO. Application decisions and labels come from compiled Bend policy.
export function createBrowserServices(policy, options = {}) {
  if (!policy?.configuration || !policy?.policy || !policy?.notice) throw Error('Missing compiled browser policy.');
  const config = JSON.parse(policy.configuration());
  const rule = (kind, input = {}) => {
    const result = JSON.parse(policy.policy(kind, JSON.stringify(input)));
    if (result && typeof result.error === 'string') throw Error(result.error);
    return result;
  };
  const notice = key => policy.notice(key);
  const storageKey = key => options.scope ? key + ':' + encodeURIComponent(options.scope) : key;
  const descriptor = value => {
    if (!value) return null;
    const { blob, chunks, ...fields } = value;
    return fields;
  };


async function responseText(response, validate = true) {
  const reader = response.body?.getReader();
  if (!reader) throw Error(notice('empty-response'));
  const chunks = [];
  let length = 0;
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      length += value.length;
      if (length > config.responseLimit) {
        await reader.cancel();
        throw Error(notice('large-response'));
      }
      chunks.push(value);
    }
  } finally { reader.releaseLock(); }
  const bytes = new Uint8Array(length);
  let at = 0;
  for (const chunk of chunks) { bytes.set(chunk, at); at += chunk.length; }
  const text = new TextDecoder().decode(bytes);
  if (validate && !response.ok) rule('response-error', { body: text, status: response.status });
  return text;
}

function sameOrigin(value) {
  const url = new URL(value, options.origin || location.href);
  rule('endpoint', { origin: url.origin, allowedOrigin: new URL(options.origin || location.href).origin, pathname: url.pathname });
  return url;
}

function forgetAcceptedCaption(caption) {
  if (!caption) return;
  for (const name of config.storage.inputKeys) {
    const key = storageKey(name);
    if (localStorage.getItem(key) === caption) localStorage.removeItem(key);
  }
}

function database(name = storageKey(config.storage.database)) {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(name, 1);
    request.onupgradeneeded = () => request.result.createObjectStore(config.storage.store);
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(Error('Could not open saved media.'));
  });
}

async function stored(mode, operation, name) {
  const db = await database(name);
  try {
    return await new Promise((resolve, reject) => {
      const transaction = db.transaction(config.storage.store, mode);
      const request = operation(transaction.objectStore(config.storage.store));
      transaction.oncomplete = () => resolve(request.result);
      transaction.onerror = transaction.onabort = () => reject(Error('Could not save the media draft.'));
    });
  } finally { db.close(); }
}

async function preparePhoto(file, maxBytes = config.photoOutputLimit) {
  if (file.size > config.photoInputLimit) throw Error(notice('photo-input'));
  const bitmap = await createImageBitmap(file);
  try {
    const canvas = document.createElement('canvas');
    let scale = Math.min(1, config.photoMaxEdge / Math.max(bitmap.width, bitmap.height));
    for (let attempt = 0; attempt < config.photoAttempts; attempt++) {
      const width = Math.max(1, Math.round(bitmap.width * scale));
      const height = Math.max(1, Math.round(bitmap.height * scale));
      canvas.width = width; canvas.height = height;
      canvas.getContext('2d').drawImage(bitmap, 0, 0, width, height);
      const quality = Math.max(0.55, 0.88 - attempt * 0.08);
      const blob = await new Promise(resolve => canvas.toBlob(resolve, 'image/jpeg', quality));
      if (!blob) throw Error(notice('photo-encode'));
      if (blob.size <= maxBytes) return { blob, width, height };
      scale *= 0.8;
    }
    throw Error(notice('photo-output'));
  } finally { bitmap.close(); }
}

// Resume keeps complete encoded segments; joining decoded PCM also works after reload.
async function joinedRecording(previous, segment) {
  if (!previous) return segment;
  const decoder = new OfflineAudioContext(1, 1, 16000);
  const buffers = await Promise.all([previous, segment].map(async blob => decoder.decodeAudioData(await blob.arrayBuffer())));
  const frames = Math.ceil(buffers.reduce((sum, buffer) => sum + buffer.duration, 0) * 16000);
  if (frames > Math.ceil(config.recordingMs * 16) + 16000) throw Error(notice('record-size'));
  const mixer = new OfflineAudioContext(1, frames, 16000);
  let position = 0;
  for (const buffer of buffers) { const source = mixer.createBufferSource(); source.buffer = buffer; source.connect(mixer.destination); source.start(position); position += buffer.duration; }
  const pcm = (await mixer.startRendering()).getChannelData(0);
  const bytes = new ArrayBuffer(44 + pcm.length * 2), view = new DataView(bytes);
  const ascii = (at, text) => [...text].forEach((char, index) => view.setUint8(at + index, char.charCodeAt(0)));
  ascii(0, 'RIFF'); view.setUint32(4, bytes.byteLength - 8, true); ascii(8, 'WAVEfmt ');
  view.setUint32(16, 16, true); view.setUint16(20, 1, true); view.setUint16(22, 1, true);
  view.setUint32(24, 16000, true); view.setUint32(28, 32000, true); view.setUint16(32, 2, true); view.setUint16(34, 16, true);
  ascii(36, 'data'); view.setUint32(40, pcm.length * 2, true);
  for (let index = 0; index < pcm.length; index++) view.setInt16(44 + index * 2, Math.round(Math.max(-1, Math.min(1, pcm[index])) * 32767), true);
  return new Blob([bytes], { type: 'audio/wav' });
}

function createMediaHost(event, { maxImageBytes = config.photoOutputLimit } = {}) {
  let recorder, recording, microphone, recordingTimer, meterContext, analyser, call, recognition, speaking, player, picker;
  let camera, cameraGeneration = 0, cameraDraft, previewDraft;
  let closed = false, recordingGeneration = 0;
  const urls = new Set();
  const urlFor = blob => { const url = URL.createObjectURL(blob); urls.add(url); return url; };
  const voice = (session, mode, phase, values = {}) => event(rule('media-event', { kind: 'audio', session, mode, phase, values }));
  const image = (session, phase, values = {}) => event(rule('media-event', { kind: 'image', session, phase, values }));
  const documentEvent = (session, phase, values = {}) => event(rule('media-event', { kind: 'file', session, phase, values }));
  let fileEdits = Promise.resolve(), documentSession;
  const stopMicrophone = () => { microphone?.getTracks().forEach(track => track.stop()); microphone = undefined; clearInterval(recordingTimer); meterContext?.close().catch(() => {}); meterContext = analyser = undefined; };

  async function saveRecording(held) {
    if (held.cancelled) return;
    voice(held.session, 'message', 'saving', { clipId: held.id, durationMs: held.durationMs });
    try {
      const segment = new Blob(held.chunks, { type: held.mimeType.split(';')[0] });
      const blob = await joinedRecording(held.previous?.blob, segment);
      if (!blob.size || blob.size > config.recordingLimit) throw Error(notice('record-size'));
      const draft = { kind: 'audio', id: held.id, session: held.session, blob, durationMs: held.durationMs, waveform: held.waveform };
      await stored('readwrite', store => store.put(draft, 'audio'));
      held.saved = true;
      if (!closed) voice(held.session, 'message', held.final ? 'recorded' : 'paused', { clipId: draft.id, durationMs: draft.durationMs, waveform: draft.waveform, transcript: '' });
    } catch (error) { if (!closed) voice(held.session, 'message', 'save-failed', { clipId: held.id, durationMs: held.durationMs, error: error.message }); }
  }
  async function record(spec, previous) {
    if (recorder?.state === 'recording') throw Error(notice('record-active'));
    if (!navigator.mediaDevices?.getUserMedia || !globalThis.MediaRecorder) throw Error(notice('record-unavailable'));
    const mimeType = ['audio/mp4', 'audio/webm;codecs=opus'].find(type => MediaRecorder.isTypeSupported(type));
    if (!mimeType) throw Error(notice('record-format'));
    const generation = ++recordingGeneration;
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    if (closed || generation !== recordingGeneration) { stream.getTracks().forEach(track => track.stop()); return; }
    microphone = stream;
    recording = { id: previous?.id ?? crypto.randomUUID(), session: spec.session, started: Date.now(), chunks: [], cancelled: false, mimeType, previous, waveform: previous?.waveform ?? [] };
    const held = recording;
    try {
      recorder = new MediaRecorder(microphone, { mimeType, audioBitsPerSecond: config.recordingBitsPerSecond });
      meterContext = new AudioContext(); analyser = meterContext.createAnalyser(); analyser.fftSize = 256;
      meterContext.createMediaStreamSource(microphone).connect(analyser); await meterContext.resume();
    } catch (error) { stopMicrophone(); throw error; }
    recorder.ondataavailable = e => { if (e.data.size) held.chunks.push(e.data); };
    recorder.onerror = () => { stopMicrophone(); voice(held.session, 'message', 'error', { error: notice('record-failed') }); };
    recorder.onstop = async () => {
      held.durationMs = Math.min(config.recordingMs, (held.previous?.durationMs ?? 0) + Math.max(1, Date.now() - held.started));
      stopMicrophone(); await saveRecording(held);
    };
    recorder.start(500);
    voice(held.session, 'message', 'recording', { clipId: held.id, durationMs: previous?.durationMs ?? 0 });
    recordingTimer = setInterval(() => {
      const elapsedMs = (held.previous?.durationMs ?? 0) + Date.now() - held.started;
      const sample = new Uint8Array(analyser.fftSize); analyser.getByteTimeDomainData(sample);
      const level = Math.min(100, Math.round(Math.sqrt(sample.reduce((sum, value) => sum + ((value - 128) / 128) ** 2, 0) / sample.length) * 300));
      held.waveform = [...held.waveform.slice(-63), level];
      voice(held.session, 'message', 'elapsed', { elapsedMs, level, waveform: held.waveform });
      if (elapsedMs >= config.recordingMs && recorder.state === 'recording') { held.final = true; recorder.stop(); }
    }, 200);
  }
  const stopPreview = (silent = false) => {
    player?.pause();
    if (previewDraft && !silent) voice(previewDraft.session, 'message', 'paused', { clipId: previewDraft.id, durationMs: previewDraft.durationMs, waveform: previewDraft.waveform });
    previewDraft = undefined;
  };

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
      voice(held.session, 'call', 'error', { error: notice('recognition') });
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
    if (spec.action === 'record-stop' || spec.action === 'record-pause') {
      if (recording) recording.final = spec.action === 'record-stop';
      if (recorder?.state === 'recording') recorder.stop();
      else if (recording && !recording.saved) await saveRecording(recording);
      return;
    }
    if (spec.action === 'record-resume') {
      stopPreview(true);
      const draft = await stored('readonly', store => store.get('audio'));
      if (!draft) throw Error(notice('record-missing'));
      rule('cancel-draft', { draft: descriptor(draft), label: 'recording' });
      return record(spec, draft);
    }
    if (spec.action === 'record-preview-stop') { stopPreview(spec.silent === true); return; }
    if (spec.action === 'record-preview') {
      stopPreview(true);
      const draft = await stored('readonly', store => store.get('audio'));
      if (!draft) throw Error(notice('record-missing'));
      previewDraft = draft; player = new Audio(urlFor(draft.blob));
      player.onended = () => { if (previewDraft === draft) stopPreview(); };
      player.ontimeupdate = () => { if (previewDraft === draft) voice(draft.session, 'message', 'playhead', { positionMs: Math.round(player.currentTime * 1000) }); };
      await player.play();
      voice(draft.session, 'message', 'previewing', { clipId: draft.id, durationMs: draft.durationMs, waveform: draft.waveform });
      return;
    }
    if (spec.action === 'record-cancel') {
      recordingGeneration++; stopPreview(true);
      const draft = await stored('readonly', store => store.get('audio'));
      rule('cancel-draft', { draft: descriptor(draft), label: 'recording' });
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
        if (!draft || draft.id !== spec.clipId) throw Error(notice('record-missing'));
        source = urlFor(draft.blob);
      }
      player = new Audio(source);
      await player.play(); return;
    }
    if (spec.action === 'call') {
      if (!(globalThis.SpeechRecognition ?? globalThis.webkitSpeechRecognition) || !globalThis.speechSynthesis) throw Error(notice('call-unavailable'));
      endCall();
      call = { session: spec.session, started: Date.now(), locale: rule('speech-locale', spec), muted: false, speaker: true, awaitingReply: false };
      const held = call;
      held.timer = setInterval(() => voice(held.session, 'call', 'elapsed', { elapsedMs: Date.now() - held.started, muted: held.muted, speaker: true }), 1000);
      listen(); return;
    }
    if (spec.action === 'end') { endCall(); return; }
    if (!call || call.session !== spec.session) throw Error(notice('call-missing'));
    if (spec.action === 'mute' || spec.action === 'unmute') {
      call.muted = spec.action === 'mute';
      if (call.muted) recognition?.abort(); else listen();
      voice(call.session, 'call', 'elapsed', { elapsedMs: Date.now() - call.started, muted: call.muted, speaker: true }); return;
    }
    if (spec.action === 'speaker') {
      endCall();
      throw Error(notice('call-output'));
    }
    if (spec.action === 'listen') { call.awaitingReply = false; listen(); return; }
    if (spec.action === 'speak') {
      recognition?.abort();
      speaking = new SpeechSynthesisUtterance(spec.text); speaking.lang = call.locale;
      const held = call, utterance = speaking;
      speaking.onend = () => { if (call !== held || speaking !== utterance) return; speaking = undefined; voice(held.session, 'call', 'spoken', { elapsedMs: Date.now() - held.started }); };
      speaking.onerror = () => { if (call !== held || speaking !== utterance) return; speaking = undefined; voice(held.session, 'call', 'error', { error: notice('call-playback') }); endCall(); };
      speechSynthesis.speak(speaking); return;
    }
    throw Error(notice('voice-action'));
  }

  const closeCamera = () => {
    cameraGeneration++;
    camera?.stream?.getTracks().forEach(track => track.stop()); camera?.video?.remove(); camera = undefined; cameraDraft = undefined;
  };
  async function openCamera(spec) {
    closeCamera();
    const generation = cameraGeneration;
    if (!navigator.mediaDevices?.getUserMedia) { image(spec.session, 'camera-unavailable', { error: notice('camera-unavailable') }); return; }
    const video = document.createElement('video'); video.muted = true; video.autoplay = true; video.playsInline = true;
    video.style.cssText = 'width:100%;height:100%;object-fit:cover;pointer-events:none;display:block';
    camera = { session: spec.session, video };
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: { ideal: 'environment' }, width: { ideal: 1920 }, height: { ideal: 1440 } }, audio: false });
      if (closed || generation !== cameraGeneration) { stream.getTracks().forEach(track => track.stop()); return; }
      camera.stream = stream; video.srcObject = stream; await video.play();
      if (generation !== cameraGeneration) return;
      image(spec.session, 'camera-ready');
    } catch (error) {
      if (generation !== cameraGeneration) return;
      closeCamera(); image(spec.session, 'camera-unavailable', { error: notice(error.name === 'NotAllowedError' ? 'camera-permission' : 'camera-unavailable') });
    }
  }
  async function photoCommand(spec) {
    if (spec.action === 'camera') return openCamera(spec);
    if (spec.action === 'camera-cancel') { closeCamera(); image(spec.session, 'cancelled'); return; }
    if (spec.action === 'camera-capture') {
      const held = camera;
      if (!held || held.session !== spec.session || !held.video.videoWidth) throw Error(notice('camera-unavailable'));
      image(spec.session, 'camera-capturing');
      const canvas = document.createElement('canvas'); canvas.width = held.video.videoWidth; canvas.height = held.video.videoHeight;
      canvas.getContext('2d').drawImage(held.video, 0, 0);
      const captured = await new Promise(resolve => canvas.toBlob(resolve, 'image/jpeg', 0.92));
      if (!captured) throw Error(notice('photo-encode'));
      const prepared = await preparePhoto(captured, maxImageBytes);
      if (camera !== held) return;
      cameraDraft = { kind: 'image', id: crypto.randomUUID(), session: spec.session, ...prepared };
      image(spec.session, 'camera-preview', { imageId: cameraDraft.id, url: urlFor(prepared.blob), width: prepared.width, height: prepared.height });
      return;
    }
    if (spec.action === 'camera-attach') {
      const draft = cameraDraft;
      if (!draft || draft.session !== spec.session) throw Error(notice('photo-missing'));
      await stored('readwrite', store => store.put(draft, 'image'));
      closeCamera(); image(spec.session, 'selected', { imageId: draft.id, url: urlFor(draft.blob), width: draft.width, height: draft.height }); return;
    }
    if (spec.action === 'cancel') {
      const draft = await stored('readonly', store => store.get('image'));
      rule('cancel-draft', { draft: descriptor(draft), label: 'photo' });
      picker?.remove(); await stored('readwrite', store => store.delete('image')); return;
    }
    if (spec.action === 'load') {
      image(spec.session, 'loaded', { imageId: spec.imageId, url: sameOrigin(spec.url).href }); return;
    }
    if (spec.action !== 'pick') throw Error(notice('photo-action'));
    closeCamera();
    picker?.remove(); picker = document.createElement('input'); picker.type = 'file'; picker.accept = 'image/*';
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
      const decision = rule('acknowledge-media', { kind, draft: descriptor(draft), accepted });
      if (!decision.accepted) continue;
      await stored('readwrite', store => store.delete(kind));
      if (kind === 'file') documentSession = undefined;
      forgetAcceptedCaption(decision.caption);
      if (decision.event) event(decision.event);
    }
  }

  async function fileCommand(spec) {
    if (spec.action === 'open') {
      const url = sameOrigin(spec.url);
      rule('file-link', { fileId: spec.fileId, pathname: url.pathname, search: url.search, hash: url.hash });
      const link = document.createElement('a'); link.href = url.href; link.download = spec.name; link.rel = 'noopener'; link.click(); return;
    }
    const held = await stored('readonly', store => store.get('file'));
    if (spec.action === 'cancel') {
      rule('cancel-draft', { draft: descriptor(held), label: 'file' });
      picker?.remove(); await stored('readwrite', store => store.delete('file')); documentSession = undefined; return;
    }
    if (spec.action !== 'pick') throw Error(notice('file-action'));
    rule('pick-file', { draft: descriptor(held) });
    documentSession = spec.session;
    picker?.remove(); picker = document.createElement('input'); picker.type = 'file';
    picker.hidden = true; document.body.append(picker);
    picker.oncancel = () => { picker.remove(); documentEvent(spec.session, 'cancelled'); };
    picker.onchange = async () => {
      const file = picker.files?.[0]; picker.remove();
      if (!file) { documentEvent(spec.session, 'cancelled'); return; }
      try {
        rule('file-admission', { size: file.size, name: file.name });
        const draft = { kind:'file', id:crypto.randomUUID(), session:spec.session, blob:file, name:file.name, mimeType:file.type || 'application/octet-stream', size:file.size, caption:spec.caption || '' };
        await stored('readwrite', store => store.put(draft, 'file'));
        documentEvent(spec.session, 'selected', { fileId:draft.id, name:draft.name, mimeType:draft.mimeType, size:draft.size });
      } catch (error) { documentEvent(spec.session, 'error', { error:error.message }); }
    };
    picker.click();
  }

  return {
    acknowledge,
    rendered(root) {
      if (camera) {
        const surface = [...root.querySelectorAll('[data-bend-shape]')].find(node => node.dataset.bendShape === 'Camera preview · ' + camera.session);
        if (surface && camera.video.parentNode !== surface) surface.append(camera.video);
        if (surface && !camera.animated) {
          camera.animated = true;
          const origin = root.querySelector('[data-bend-shape="Motion origin · camera"]');
          if (origin && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
            const from = origin.getBoundingClientRect(), to = surface.getBoundingClientRect();
            surface.animate([{ transform: `translate(${from.x + from.width / 2 - to.x - to.width / 2}px,${from.y + from.height / 2 - to.y - to.height / 2}px) scale(${from.width / to.width},${from.height / to.height})`, opacity: 0.4 }, { transform: 'none', opacity: 1 }], { duration: 360, easing: 'cubic-bezier(.2,.9,.25,1)' });
          }
        }

      }
    },
    busy() { return !!call || recorder?.state === 'recording' || !!microphone; },
    edited(caption) {
      if (!documentSession) return;
      fileEdits = fileEdits.then(async () => {
        try {
          const draft = await stored('readonly', store => store.get('file'));
          if (!rule('editable-draft', { draft: descriptor(draft) })) return;
          await stored('readwrite', store => store.put({ ...draft, caption }, 'file'));
        } catch (error) { documentEvent(documentSession, 'error', { error:error.message }); }
      });
      return fileEdits;
    },
    async request(operation, spec, signal, context) {
      const route = rule('route', { operation });
      if (route.kind !== 'media') throw Error('Unsupported media effect.');
      const kind = route.media;
      if (route.mode === 'command') {
        await ({ audio: voiceCommand, image: photoCommand, file: fileCommand })[kind](spec);
        return '';
      }
      if (kind === 'file') await fileEdits;
      const draft = await stored('readonly', store => store.get(kind));
      const prepared = rule('request', { body: spec.body, held: draft?.metadata ? { ...draft.metadata, id: draft.metadata.requestId } : undefined, ...context });
      const decision = rule('upload', { kind, draft: descriptor(draft), body: prepared.body });
      draft.metadata = decision.metadata;
      await stored('readwrite', store => store.put(draft, kind));
      const body = new FormData();
      const filename = kind === 'file' ? encodeURIComponent(draft.name).replace(/[!'()*]/g, c => '%' + c.charCodeAt(0).toString(16).toUpperCase()) : kind === 'image' ? 'photo.jpg' : draft.blob.type === 'audio/mp4' ? 'voice.m4a' : draft.blob.type === 'audio/wav' ? 'voice.wav' : 'voice.webm';
      body.set(decision.field, draft.blob, filename);
      body.set('metadata', JSON.stringify(decision.includeName ? { ...decision.metadata, name:draft.name } : decision.metadata));
      const text = await responseText(await fetch(sameOrigin(spec.url), { method: 'POST', body, signal, credentials: 'same-origin' }));
      await acknowledge(rule('snapshot', JSON.parse(text)).accepted ?? []);
      return text;
    },
    async restore(accepted) {
      for (const kind of ['audio', 'image', 'file']) {
        const draft = await stored('readonly', store => store.get(kind));
        if (!draft) continue;
        const decision = rule('restore', { kind, draft: descriptor(draft), accepted });
        if (decision.delete) { await stored('readwrite', store => store.delete(kind)); continue; }
        const values = decision.values;
        if (kind === 'audio') {
          voice(draft.session, 'message', 'recorded', { ...values, clipId: draft.id, durationMs: draft.durationMs, transcript: '' });
          if (decision.pending) event(decision.pending);
        }
        else if (kind === 'file') { documentSession = draft.session; documentEvent(draft.session, 'selected', { ...values, fileId:draft.id, name:draft.name, mimeType:draft.mimeType, size:draft.size }); }
        else image(draft.session, 'selected', { ...values, imageId: draft.id, width: draft.width, height: draft.height, url: urlFor(draft.blob) });
      }
    },
    close() {
      closed = true; recordingGeneration++; closeCamera();
      if (recorder?.state === 'recording') recorder.stop();
      stopMicrophone(); endCall(); player?.pause(); picker?.remove();
      for (const url of urls) URL.revokeObjectURL(url);
    },
  };
}

async function importLegacy() {
  if (!options.scope || localStorage.getItem(storageKey(config.storage.migrated))) return;
  for (const name of [config.storage.pending, ...config.storage.inputKeys]) {
    const saved = localStorage.getItem(name);
    if (saved !== null && localStorage.getItem(storageKey(name)) === null) localStorage.setItem(storageKey(name), saved);
  }
  for (const kind of ['audio', 'image', 'file']) {
    const saved = await stored('readonly', store => store.get(kind), config.storage.database);
    if (saved && !await stored('readonly', store => store.get(kind))) await stored('readwrite', store => store.put(saved, kind));
  }
  localStorage.setItem(storageKey(config.storage.migrated), '1');
}
return { config, rule, notice, storageKey, importLegacy, responseText, sameOrigin, forgetAcceptedCaption, preparePhoto, createMediaHost };
}

export function createBrowserClient({ root, deliver, policy, catalog = [] }) {
  const base = createBrowserServices(policy);
  let storedSelection;
  try { storedSelection = localStorage.getItem(base.config.storage.selection); } catch { /* Storage may be unavailable in private contexts. */ }
  const selectedCatalog = base.rule('catalog', { dots: catalog, selectedDotId: storedSelection });
  const selected = selectedCatalog.selected;
  const origin = new URL(selected?.origin || location.href);
  if (origin.username || origin.password || !['https:', 'http:'].includes(origin.protocol)) throw Error('Invalid browser service origin.');
  const scope = selected?.id ? selected.id + '@' + origin.origin : '';
  const services = createBrowserServices(policy, { origin: origin.href, scope });
  const { config, rule, notice, storageKey, createMediaHost, responseText, sameOrigin, forgetAcceptedCaption } = services;
  const PENDING = storageKey(config.storage.pending);
  let activeRequests = 0;
  const ready = (async () => {
    if (!scope) return;
    let owner = localStorage.getItem(config.storage.owner);
    if (!owner && catalog[0]?.id) {
      owner = catalog[0].id + '@' + new URL(catalog[0].origin || location.href).origin;
      localStorage.setItem(config.storage.owner, owner);
    }
    if (owner === scope) await services.importLegacy();
  })();
  const event = value => deliver(JSON.stringify(value));
  const imageLimit = Number(root.dataset.maxImageBytes);
  const media = createMediaHost(event, {
    maxImageBytes: rule('image-limit', { bytes: Number.isSafeInteger(imageLimit) ? imageLimit : 0 }),
  });
  let restored = false, initialized = false, refreshQueued = false, thread, atBottom = true, lastHeight = 0, prepend = false;
  let displayedContext, pendingContext, browserSession, processingContext, processingRefresh = false;
  const sendContexts = [];
  const isSend = name => rule('is-send', { name });
  const observeSnapshot = text => {
    const snapshot = JSON.parse(text);
    pendingContext = rule('snapshot', snapshot).review;
    return snapshot;
  };
  const viewport = () => rule('viewport', { width: Math.floor(root.clientWidth), height: Math.floor(globalThis.visualViewport?.height ?? innerHeight) });
  const resize = () => { if (initialized) event(viewport()); };
  const refresh = () => {
    if (!document.hidden && !refreshQueued) { refreshQueued = true; event(rule('refresh-event')); }
  };
  const interval = setInterval(refresh, config.refreshMs);
  const observer = new ResizeObserver(resize);
  observer.observe(root);
  globalThis.visualViewport?.addEventListener('resize', resize);
  window.addEventListener('online', refresh);
  document.addEventListener('visibilitychange', refresh);
  const recordScroll = () => { atBottom = thread.scrollHeight - thread.scrollTop - thread.clientHeight < config.scrollMargin; };
  const click = e => {
    const button = e.target.closest('[data-bend-event]');
    if (button && !button.disabled && isSend(button.dataset.bendEvent)) sendContexts.push({ ...displayedContext });
    const prefix = rule('link-prefix');
    if (!button?.dataset.bendEvent.startsWith(prefix)) return;
    e.stopImmediatePropagation();
    const url = new URL(button.dataset.bendEvent.slice(prefix.length), location.href);
    if (['http:', 'https:'].includes(url.protocol)) window.open(url.href, '_blank', 'noopener,noreferrer');
  };
  const keydown = e => {
    if (e.key !== 'Enter' || e.shiftKey || e.isComposing || !e.target.matches(config.selectors.message)) return;
    if (root.querySelector(config.selectors.editor)) return;
    const send = root.querySelector(config.selectors.send);
    if (send && !send.disabled) { e.preventDefault(); send.click(); }
  };
  root.addEventListener('click', click, true);
  root.addEventListener('keydown', keydown);
  const edited = e => { if (e.target.matches(config.selectors.message)) media.edited(e.target.value); };
  root.addEventListener('input', edited);

  async function request(operation, data, signal) {
    const route = rule('route', { operation });
    if (route.kind === 'initialize') {
      if (!initialized) {
        initialized = true;
        browserSession = crypto.randomUUID();
        const startup = rule('initialize', { session: browserSession, language: navigator.language, width: Math.floor(root.clientWidth), height: Math.floor(globalThis.visualViewport?.height ?? innerHeight) });
        for (const value of startup.events) event(value);
      }
      return JSON.stringify(viewport());
    }
    if (route.kind === 'catalog') {
      const spec = JSON.parse(data);
      if (rule('catalog-request', spec) === 'select') {
        const next = rule('select-dot', { ...spec, dots: catalog, busy: activeRequests > 0 || media.busy() || !!localStorage.getItem(PENDING) });
        localStorage.setItem(config.storage.selection, next.selectedDotId);
        location.reload();
        return JSON.stringify(rule('catalog-public', next));
      }
      return JSON.stringify(rule('catalog-public', selectedCatalog));
    }
    if (route.kind === 'ignore') return '';
    if (route.kind === 'notifications') return rule('notification-note', { locale: navigator.language });
    if (route.kind === 'media') {
      const spec = rule('prepare-media', { kind: route.media, spec: JSON.parse(data), session: browserSession });
      const text = await media.request(operation, spec, signal, { displayed: displayedContext, clicked: processingContext ?? displayedContext });
      if (route.mode === 'upload') observeSnapshot(text);
      return text;
    }
    if (route.kind !== 'http') return undefined;
    const spec = route.method === 'GET' ? { url: data } : JSON.parse(data);
    const url = sameOrigin(spec.url);
    if (url.searchParams.has('before')) prepend = true;
    const plan = rule('http-plan', { pathname: url.pathname, method: route.method });
    if (plan.persist) {
      // Preserve the displayed review across retries as well as the receipt ID.
      let held;
      try { held = JSON.parse(localStorage.getItem(PENDING)); } catch { /* Invalid saved context cannot override the displayed review. */ }
      const prepared = rule('request', { body: spec.body, held, displayed: displayedContext, clicked: processingContext });
      spec.body = prepared.body;
      localStorage.setItem(PENDING, JSON.stringify(prepared.pending));
    }
    const response = await fetch(url, { signal, credentials: 'same-origin', ...(route.method === 'POST' ? {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(spec.body),
    } : {}) });
    const text = await responseText(response, false);
    const outcome = rule('http-result', { body: text, status: response.status, pathname: url.pathname, requestId: spec.body?.requestId });
    if (outcome.clearPending) {
      let held;
      try { held = JSON.parse(localStorage.getItem(PENDING)); } catch { /* Invalid receipt cannot match. */ }
      if (held?.id === outcome.clearPending) localStorage.removeItem(PENDING);
      if (outcome.event) event(outcome.event);
    }
    if (!response.ok) rule('response-error', { body: text, status: response.status });
    const snapshot = observeSnapshot(text);
    let pending;
    try { pending = JSON.parse(localStorage.getItem(PENDING)); } catch { /* A malformed local receipt is not sent. */ }
    const accepted = rule('snapshot', snapshot).accepted ?? [];
    const receipt = rule('acknowledged', { saved: pending, accepted });
    if (receipt.accepted) {
      localStorage.removeItem(PENDING); forgetAcceptedCaption(receipt.caption);
    }
    await media.acknowledge(accepted);
    if (!restored && plan.restore) {
      restored = true;
      if (receipt.pending) event(receipt.pending);
      await media.restore(accepted);
    }
    return text;
  }

  return {
    storageKey,
    async request(operation, data, signal) {
      await ready;
      const tracked = rule('route', { operation }).kind !== 'catalog';
      if (tracked) activeRequests++;
      try { return await request(operation, data, signal); }
      finally { if (tracked) activeRequests--; }
    },
    eventConsumed(text) {
      const consumed = rule('consumed', { name: text });
      processingContext = consumed.send ? sendContexts.shift() : undefined;
      processingRefresh = consumed.refresh;
    },
    rendered() {
      if (processingRefresh) { refreshQueued = false; processingRefresh = false; }
      if (pendingContext) { displayedContext = pendingContext; pendingContext = undefined; }
      for (const button of root.querySelectorAll(config.selectors.speaker)) {
        button.disabled = true;
        button.title = notice('speaker');
      }
      const next = root.querySelector(config.selectors.thread);
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
      media.rendered(root);
      root.setAttribute('aria-busy', 'false');
    },
    close() {
      clearInterval(interval); observer.disconnect();
      globalThis.visualViewport?.removeEventListener('resize', resize);
      window.removeEventListener('online', refresh);
      document.removeEventListener('visibilitychange', refresh);
      root.removeEventListener('click', click, true); root.removeEventListener('keydown', keydown);
      root.removeEventListener('input', edited);
      thread?.removeEventListener('scroll', recordScroll);
      media.close();
    },
  };
}
