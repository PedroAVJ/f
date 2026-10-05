import { createHash, randomUUID } from "node:crypto";
import { closeSync, constants, fstatSync, fsyncSync, linkSync, mkdirSync, openSync, readFileSync, unlinkSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { InputError, object, type Audio } from "./session.ts";

export const MAX_AUDIO_BODY = 17 * 1024 * 1024;

export async function audioUpload(request: Request, directory: string) {
  const bytes = await boundedBody(request, MAX_AUDIO_BODY);
  let form: FormData;
  try { form = await new Request(request.url, { method: "POST", headers: request.headers, body: new Uint8Array(bytes) }).formData(); }
  catch { throw new InputError("Invalid voice message upload."); }
  if ([...form.keys()].length !== 2 || form.getAll("audio").length !== 1 || form.getAll("metadata").length !== 1) throw new InputError("Upload one audio file and its metadata.");
  const clip = form.get("audio"), metadata = form.get("metadata");
  if (!(clip instanceof File) || typeof metadata !== "string" || metadata.length > 65_536) throw new InputError("Audio file and JSON metadata required.");
  if (!["audio/mp4", "audio/x-m4a"].includes(clip.type) || clip.size < 12 || clip.size > 16 * 1024 * 1024) throw new InputError("Upload an M4A voice message of at most 16 MiB.");
  const data = Buffer.from(await clip.arrayBuffer());
  if (data.toString("ascii", 4, 8) !== "ftyp") throw new InputError("Invalid M4A audio container.");
  let input;
  try { input = object(JSON.parse(metadata)); } catch { throw new InputError("Invalid voice message metadata."); }
  if (input.transcript !== undefined && (typeof input.transcript !== "string" || input.transcript.length > 32_000)) throw new InputError("Invalid voice transcript.");
  if (!Number.isFinite(input.durationMs) || input.durationMs <= 0 || input.durationMs > 900_000) throw new InputError("Voice message duration must be at most 15 minutes.");
  const id = createHash("sha256").update(data).digest("hex");
  mkdirSync(directory, { recursive: true, mode: 0o700 });
  const path = join(directory, `${id}.m4a`);
  const temporary = join(directory, `.${id}.${randomUUID()}.tmp`);
  let descriptor: number | undefined;
  try {
    // Publish only complete bytes. A crash while writing leaves an unowned
    // temporary file rather than a partial artifact named by a valid hash.
    descriptor = openSync(temporary, constants.O_WRONLY | constants.O_CREAT | constants.O_EXCL | constants.O_NOFOLLOW, 0o600);
    writeFileSync(descriptor, data);
    fsyncSync(descriptor); closeSync(descriptor); descriptor = undefined;
    try { linkSync(temporary, path); }
    catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "EEXIST") throw error;
      // Retries must verify the saved artifact rather than trusting its name.
      const saved = verifiedAudio(path, id);
      if (saved.length !== data.length) throw new InputError("The saved voice message is damaged.", 409);
    }
  } finally {
    if (descriptor !== undefined) closeSync(descriptor);
    try { unlinkSync(temporary); } catch (error) { if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error; }
  }
  const audio: Audio = { id, url: `/api/audio/${id}`, mimeType: "audio/mp4", durationMs: Math.round(input.durationMs), transcriptionStatus: input.transcript?.trim() ? "ready" : "missing" };
  return { input, audio };
}

export function audioDownload(directory: string, id: string, request: Request) {
  if (!/^[a-f0-9]{64}$/.test(id)) throw new InputError("Voice message not found.", 404);
  let descriptor: number | undefined;
  try {
    descriptor = openSync(join(directory, `${id}.m4a`), constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK);
    const stat = fstatSync(descriptor);
    if (!stat.isFile() || stat.size < 12 || stat.size > 16 * 1024 * 1024) throw new InputError("Voice message not found.", 404);
    const data = readFileSync(descriptor);
    if (createHash("sha256").update(data).digest("hex") !== id) throw new InputError("Voice message not found.", 404);
    let start = 0, end = stat.size - 1, status = 200;
    const range = request.headers.get("range");
    if (range) {
      const match = /^bytes=(\d+)-(\d*)$/.exec(range);
      if (!match) throw new InputError("Invalid audio range.", 416);
      start = Number(match[1]); end = match[2] ? Number(match[2]) : end;
      if (!Number.isSafeInteger(start) || !Number.isSafeInteger(end) || start > end || end >= stat.size) throw new InputError("Invalid audio range.", 416);
      status = 206;
    }
    const bytes = request.method === "HEAD" ? null : data.subarray(start, end + 1);
    return new Response(bytes, { status, headers: {
      "Content-Type": "audio/mp4", "Content-Length": String(end - start + 1), "Accept-Ranges": "bytes",
      ...(status === 206 ? { "Content-Range": `bytes ${start}-${end}/${stat.size}` } : {}),
      "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff",
    } });
  } catch (error) {
    if (error instanceof InputError) throw error;
    throw new InputError("Voice message not found.", 404);
  } finally { if (descriptor !== undefined) closeSync(descriptor); }
}

function verifiedAudio(path: string, id: string): Buffer {
  let descriptor: number | undefined;
  try {
    descriptor = openSync(path, constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK);
    const stat = fstatSync(descriptor);
    if (!stat.isFile() || stat.size < 12 || stat.size > 16 * 1024 * 1024) throw new Error();
    const data = readFileSync(descriptor);
    if (data.length !== stat.size || createHash("sha256").update(data).digest("hex") !== id) throw new Error();
    return data;
  } catch { throw new InputError("The saved voice message is damaged.", 409); }
  finally { if (descriptor !== undefined) closeSync(descriptor); }
}

export async function boundedBody(request: Request, limit: number): Promise<Buffer> {
  const length = request.headers.get("content-length");
  if (length && (!/^\d+$/.test(length) || Number(length) > limit)) throw new InputError("Request is too large.", 413);
  if (!request.body) throw new InputError("Request body required.");
  const reader = request.body.getReader();
  let bytes = 0; const chunks: Uint8Array[] = [];
  try {
    for (;;) {
      const { done, value } = await reader.read(); if (done) break;
      bytes += value.byteLength;
      if (bytes > limit) { await reader.cancel(); throw new InputError("Request is too large.", 413); }
      chunks.push(value);
    }
  } finally { reader.releaseLock(); }
  return Buffer.concat(chunks);
}
