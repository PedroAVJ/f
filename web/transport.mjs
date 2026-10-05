const LIMIT = 1_048_576;

export async function responseText(response) {
  const reader = response.body?.getReader();
  if (!reader) throw Error('The server returned an empty response.');
  const chunks = [];
  let length = 0;
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      length += value.length;
      if (length > LIMIT) {
        await reader.cancel();
        throw Error('The conversation response is too large.');
      }
      chunks.push(value);
    }
  } finally { reader.releaseLock(); }
  const bytes = new Uint8Array(length);
  let at = 0;
  for (const chunk of chunks) { bytes.set(chunk, at); at += chunk.length; }
  const text = new TextDecoder().decode(bytes);
  if (!response.ok) {
    let message;
    try { message = JSON.parse(text).error; } catch { /* Non-JSON failures keep only the status. */ }
    throw Error(typeof message === 'string' ? message : `Request failed (${response.status}).`);
  }
  return text;
}

export function sameOrigin(value) {
  const url = new URL(value, location.href);
  if (url.origin !== location.origin || !url.pathname.startsWith('/api/')) throw Error('The request must use this app’s server.');
  return url;
}

export function forgetAcceptedCaption(caption) {
  if (!caption) return;
  for (const key of Object.keys(localStorage)) {
    if (key.startsWith('bend-input:textbox · ') && localStorage.getItem(key) === caption) localStorage.removeItem(key);
  }
}
