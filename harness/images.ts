import { createHash, randomUUID } from "node:crypto";
import { closeSync, constants, fstatSync, fsyncSync, linkSync, mkdirSync, openSync, readFileSync, unlinkSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { boundedBody } from "./audio.ts";
import { InputError, object, type ImageAttachment } from "./session.ts";

export const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
export const MAX_IMAGE_BODY = 6 * 1024 * 1024;

export async function imageUpload(request: Request, directory: string) {
  const bytes = await boundedBody(request, MAX_IMAGE_BODY);
  let form: FormData;
  try { form = await new Request(request.url, { method: "POST", headers: request.headers, body: new Uint8Array(bytes) }).formData(); }
  catch { throw new InputError("Invalid photo upload."); }
  if ([...form.keys()].length !== 2 || form.getAll("image").length !== 1 || form.getAll("metadata").length !== 1) throw new InputError("Upload one photo and its metadata.");
  const file = form.get("image"), metadata = form.get("metadata");
  if (!(file instanceof File) || typeof metadata !== "string" || metadata.length > 65_536) throw new InputError("Photo file and JSON metadata required.");
  if (!["image/jpeg", "image/png"].includes(file.type) || file.size < 24 || file.size > MAX_IMAGE_BYTES) throw new InputError("Upload a JPEG or PNG photo of at most 5 MiB.");
  let input;
  try { input = object(JSON.parse(metadata)); } catch { throw new InputError("Invalid photo metadata."); }
  if (typeof input.imageId !== "string" || !/^[A-Za-z0-9._:-]{1,160}$/.test(input.imageId)) throw new InputError("A valid imageId is required.");
  if (input.text !== undefined && (typeof input.text !== "string" || input.text.length > 32_000)) throw new InputError("Invalid photo caption.");
  const data = Buffer.from(await file.arrayBuffer());
  const info = imageInfo(data);
  if (info.mimeType !== file.type) throw new InputError("Photo type does not match its bytes.");
  if ((input.width !== undefined && input.width !== info.width) || (input.height !== undefined && input.height !== info.height)) throw new InputError("Photo dimensions do not match its bytes.");
  const id = createHash("sha256").update(data).digest("hex");
  const image: ImageAttachment = { id, url: `/api/image/${id}`, ...info };
  mkdirSync(directory, { recursive: true, mode: 0o700 });
  const path = imagePath(directory, image), temporary = join(directory, `.${id}.${randomUUID()}.tmp`);
  let descriptor: number | undefined;
  try {
    descriptor = openSync(temporary, constants.O_WRONLY | constants.O_CREAT | constants.O_EXCL | constants.O_NOFOLLOW, 0o600);
    writeFileSync(descriptor, data); fsyncSync(descriptor); closeSync(descriptor); descriptor = undefined;
    try { linkSync(temporary, path); }
    catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "EEXIST") throw error;
      readImage(directory, image);
    }
  } finally {
    if (descriptor !== undefined) closeSync(descriptor);
    try { unlinkSync(temporary); } catch (error) { if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error; }
  }
  return { input, image };
}

export function imagePath(directory: string, image: ImageAttachment) {
  if (!/^[a-f0-9]{64}$/.test(image.id) || !["image/jpeg", "image/png"].includes(image.mimeType)) throw new InputError("Photo not found.", 404);
  return join(directory, `${image.id}.${image.mimeType === "image/jpeg" ? "jpg" : "png"}`);
}

export function readImage(directory: string, image: ImageAttachment): Buffer {
  let descriptor: number | undefined;
  try {
    descriptor = openSync(imagePath(directory, image), constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK);
    const stat = fstatSync(descriptor);
    if (!stat.isFile() || stat.size < 24 || stat.size > MAX_IMAGE_BYTES) throw new Error();
    const data = readFileSync(descriptor);
    if (data.length !== stat.size || createHash("sha256").update(data).digest("hex") !== image.id) throw new Error();
    const info = imageInfo(data);
    if (info.mimeType !== image.mimeType || info.width !== image.width || info.height !== image.height) throw new Error();
    return data;
  } catch { throw new InputError("The saved photo is damaged or unavailable.", 409); }
  finally { if (descriptor !== undefined) closeSync(descriptor); }
}

export function imageDownload(directory: string, image: ImageAttachment, request: Request) {
  let data: Buffer;
  try { data = readImage(directory, image); } catch { throw new InputError("Photo not found.", 404); }
  let start = 0, end = data.length - 1, status = 200;
  const range = request.headers.get("range");
  if (range) {
    const match = /^bytes=(\d+)-(\d*)$/.exec(range);
    if (!match) throw new InputError("Invalid photo range.", 416);
    start = Number(match[1]); end = match[2] ? Number(match[2]) : end;
    if (!Number.isSafeInteger(start) || !Number.isSafeInteger(end) || start > end || end >= data.length) throw new InputError("Invalid photo range.", 416);
    status = 206;
  }
  return new Response(request.method === "HEAD" ? null : new Uint8Array(data.subarray(start, end + 1)), { status, headers: {
    "Content-Type": image.mimeType, "Content-Length": String(end - start + 1), "Accept-Ranges": "bytes",
    ...(status === 206 ? { "Content-Range": `bytes ${start}-${end}/${data.length}` } : {}),
    "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff",
  } });
}

function imageInfo(data: Buffer): Pick<ImageAttachment, "mimeType" | "width" | "height"> {
  let mimeType: ImageAttachment["mimeType"], width = 0, height = 0;
  if (data.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) {
    mimeType = "image/png";
    let position = 8, sawData = false, sawEnd = false;
    while (position + 12 <= data.length) {
      const size = data.readUInt32BE(position), end = position + size + 12;
      if (end > data.length) throw new InputError("Invalid PNG photo.");
      const type = data.toString("ascii", position + 4, position + 8);
      if (crc32(data.subarray(position + 4, end - 4)) !== data.readUInt32BE(end - 4)) throw new InputError("Invalid PNG photo.");
      if (position === 8) {
        if (type !== "IHDR" || size !== 13) throw new InputError("Invalid PNG photo.");
        width = data.readUInt32BE(position + 8); height = data.readUInt32BE(position + 12);
      } else if (type === "IHDR") throw new InputError("Invalid PNG photo.");
      if (type === "IDAT") sawData = true;
      if (type === "IEND") { if (size !== 0 || end !== data.length) throw new InputError("Invalid PNG photo."); sawEnd = true; break; }
      position = end;
    }
    if (!sawData || !sawEnd) throw new InputError("Invalid PNG photo.");
  } else if (data[0] === 0xff && data[1] === 0xd8 && data.at(-2) === 0xff && data.at(-1) === 0xd9) {
    mimeType = "image/jpeg";
    let position = 2, sawScan = false;
    while (position + 4 <= data.length) {
      if (data[position++] !== 0xff) throw new InputError("Invalid JPEG photo.");
      while (data[position] === 0xff) position++;
      const marker = data[position++];
      if (marker === 0xda) { sawScan = true; break; }
      const size = data.readUInt16BE(position);
      if (size < 2 || position + size > data.length) throw new InputError("Invalid JPEG photo.");
      if ([0xc0, 0xc1, 0xc2, 0xc3, 0xc5, 0xc6, 0xc7, 0xc9, 0xca, 0xcb, 0xcd, 0xce, 0xcf].includes(marker)) {
        if (size < 8) throw new InputError("Invalid JPEG photo.");
        height = data.readUInt16BE(position + 3); width = data.readUInt16BE(position + 5);
      }
      position += size;
    }
    if (!sawScan) throw new InputError("Invalid JPEG photo.");
  } else throw new InputError("Invalid photo container.");
  if (!width || !height || width > 8000 || height > 8000 || width * height > 32_000_000) throw new InputError("Photo dimensions exceed this mobile client's image limit.");
  return { mimeType, width, height };
}

function crc32(bytes: Uint8Array): number {
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit++) crc = (crc >>> 1) ^ ((crc & 1) ? 0xedb88320 : 0);
  }
  return (crc ^ 0xffffffff) >>> 0;
}
