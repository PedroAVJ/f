import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { closeSync, constants, fstatSync, lstatSync, openSync, readFileSync } from "node:fs";
import { AppServer } from "./rpc.ts";
import { ClaudeCode } from "./claude.ts";
import { audioUpload, audioDownload, MAX_AUDIO_BODY } from "./audio.ts";
import { imageUpload, imageDownload } from "./images.ts";
import { fileUpload, fileDownload, MAX_FILE_BODY } from "./files.ts";
import { Sessions, InputError, object } from "./session.ts";
import { Notifications } from "./notifications.ts";
import { configuredPushSender } from "./apns.ts";

const MAX_BODY = 128_000;
export type HttpOptions = { allowedLogin: string; publicHost: string; iosArtifact?: string; webDirectory?: string; notifications?: Notifications };
const localHost = (hostname: string) => ["localhost", "127.0.0.1", "[::1]"].includes(hostname);

export function httpHandler(sessions: Sessions, options: HttpOptions) {
  return async (request: Request): Promise<Response> => {
    try {
      const host = request.headers.get("host") ?? new URL(request.url).host;
      let hostURL: URL;
      try { hostURL = new URL(`http://${host}`); } catch { throw new InputError("Invalid host."); }
      if (hostURL.host !== host || hostURL.username || hostURL.password) throw new InputError("Invalid host.");
      const local = localHost(hostURL.hostname);
      if ((!local && host !== options.publicHost)
        || (options.allowedLogin ? request.headers.get("tailscale-user-login")?.toLowerCase() !== options.allowedLogin.toLowerCase() : !local)) {
        throw new InputError("Connect through your authorized Tailscale account.", 403);
      }
      if (!["GET", "HEAD", "POST"].includes(request.method)) throw new InputError("Method not allowed.", 405);
      const url = new URL(request.url);
      if (request.method === "POST") {
        const origin = request.headers.get("origin");
        if (!origin || ![...(local ? [`http://${host}`] : []), `https://${host}`].includes(origin)) throw new InputError("Request origin must match the app address.", 403);
        if (url.pathname === "/api/file") {
          if (!request.headers.get("content-type")?.startsWith("multipart/form-data;")) throw new InputError("Use multipart/form-data for a file.", 415);
          const { input, file } = await fileUpload(request, sessions.fileDirectory());
          return json(sessions.submitFile(input, file), 202);
        }
        if (url.pathname === "/api/audio") {
          if (!request.headers.get("content-type")?.startsWith("multipart/form-data;")) throw new InputError("Use multipart/form-data for a voice message.", 415);
          const { input, audio } = await audioUpload(request, sessions.audioDirectory());
          return json(sessions.submitAudio(input, audio), 202);
        }
        if (url.pathname === "/api/image") {
          if (!request.headers.get("content-type")?.startsWith("multipart/form-data;")) throw new InputError("Use multipart/form-data for a photo.", 415);
          const { input, image } = await imageUpload(request, sessions.imageDirectory());
          return json(sessions.submitImage(input, image), 202);
        }
        if (request.headers.get("content-type")?.split(";")[0].trim() !== "application/json") throw new InputError("Use application/json.", 415);
        const body = object(await readBody(request));
        if (url.pathname === "/api/notifications/device") {
          if (!options.notifications) throw new InputError("Notifications are not available.", 503);
          try { return json(options.notifications.register(body)); }
          catch { throw new InputError("Invalid notification registration."); }
        }
        if (url.pathname === "/api/search") {
          if (typeof body.query !== "string") throw new InputError("Search query must be text.");
          return json(sessions.snapshot(undefined, body.query));
        }
        if (url.pathname === "/api/turn") return json(sessions.submit(body), 202);
        if (url.pathname === "/api/audio/retry") return json(sessions.retryAudio(body), 202);
        if (url.pathname === "/api/stop") return json(await sessions.stop(body));
        throw new InputError("Not found.", 404);
      }
      if (url.pathname === "/health") return json(sessions.health(), sessions.isReady ? 200 : 503);
      if (url.pathname === "/api/notifications/status") return json(options.notifications?.status() ?? { available: false, configured: false });
      if (url.pathname === "/api/session") {
        sessions.observeDisplay(url.searchParams);
        return json(sessions.snapshot(url.searchParams.get("before") ?? undefined, undefined, url.searchParams.get("call") === "1"));
      }
      if (url.pathname === "/api/search") return json(sessions.snapshot(url.searchParams.get("before") ?? undefined, url.searchParams.get("q") ?? ""));
      if (url.pathname.startsWith("/api/file/")) {
        const file = sessions.ownedFile(url.pathname.slice("/api/file/".length));
        if (!file) throw new InputError("File not found.", 404);
        return fileDownload(sessions.fileDirectory(), file, request);
      }
      if (url.pathname.startsWith("/api/audio/")) {
        const id = url.pathname.slice("/api/audio/".length);
        const audio = sessions.ownedAudio(id);
        if (!audio) throw new InputError("Voice message not found.", 404);
        return audioDownload(sessions.audioDirectory(), id, request, audio.mimeType);
      }
      if (url.pathname.startsWith("/api/image/")) {
        const id = url.pathname.slice("/api/image/".length), image = sessions.ownedImage(id);
        if (!image) throw new InputError("Photo not found.", 404);
        return imageDownload(sessions.imageDirectory(), image, request);
      }
      if (url.pathname.startsWith("/api/")) throw new InputError("Not found.", 404);
      checkedPath(url.pathname);
      if (url.pathname === "/downloads/Dot.ipa") return ipaResponse(options.iosArtifact, request.method === "HEAD");
      if (options.webDirectory) return webResponse(options.webDirectory, url.pathname, request.method === "HEAD");
      throw new InputError("Not found.", 404);
    } catch (error) {
      if (error instanceof InputError) return json({ error: error.message }, error.status);
      return json({ error: "Open Dot could not complete the request." }, 500);
    }
  };
}

async function readBody(request: Request): Promise<unknown> {
  const length = request.headers.get("content-length");
  if (length && (!/^\d+$/.test(length) || Number(length) > MAX_BODY)) throw new InputError("Request is too large.", 413);
  if (!request.body) throw new InputError("JSON body required.");
  const reader = request.body.getReader();
  let bytes = 0; const chunks: Uint8Array[] = [];
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      bytes += value.byteLength;
      if (bytes > MAX_BODY) { await reader.cancel(); throw new InputError("Request is too large.", 413); }
      chunks.push(value);
    }
  } finally { reader.releaseLock(); }
  try { return JSON.parse(Buffer.concat(chunks).toString("utf8")); }
  catch { throw new InputError("Invalid JSON body."); }
}

function checkedPath(pathname: string) {
  let decoded: string;
  try { decoded = decodeURIComponent(pathname); } catch { throw new InputError("Invalid path."); }
  if (decoded.includes("\0") || decoded.includes("\\") || decoded.split("/").includes("..")) throw new InputError("Invalid path.", 403);
  return decoded;
}

function ipaResponse(file: string | undefined, head: boolean) {
  if (!file) throw new InputError("Not found.", 404);
  let descriptor: number | undefined;
  try {
    if (!lstatSync(dirname(file)).isDirectory()) throw new InputError("Not found.", 404);
    // Keep the opened file stable if the artifact filename is replaced.
    descriptor = openSync(file, constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK);
    const stat = fstatSync(descriptor);
    if (!stat.isFile()) throw new InputError("Not found.", 404);
    const bytes = head ? null : readFileSync(descriptor);
    return new Response(bytes, { headers: {
      "Content-Type": "application/octet-stream",
      "Content-Disposition": 'attachment; filename="Dot.ipa"',
      "Content-Length": String(bytes?.byteLength ?? stat.size),
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
    } });
  } catch {
    throw new InputError("Not found.", 404);
  } finally {
    if (descriptor !== undefined) closeSync(descriptor);
  }
}

function webResponse(directory: string, pathname: string, head: boolean) {
  const name = pathname === "/" ? "index.html" : pathname.slice(1);
  const types: Record<string, string> = { html: "text/html; charset=utf-8", js: "text/javascript; charset=utf-8", mjs: "text/javascript; charset=utf-8", css: "text/css; charset=utf-8", wasm: "application/wasm", png: "image/png" };
  const extension = name.split(".").at(-1) ?? "";
  if (!/^[a-zA-Z0-9._-]+$/.test(name) || !types[extension]) throw new InputError("Not found.", 404);
  let descriptor: number | undefined;
  try {
    descriptor = openSync(join(directory, name), constants.O_RDONLY | constants.O_NOFOLLOW | constants.O_NONBLOCK);
    const stat = fstatSync(descriptor);
    if (!stat.isFile()) throw new Error();
    return new Response(head ? null : readFileSync(descriptor), { headers: {
      "Content-Type": types[extension], "Content-Length": String(stat.size),
      "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff",
      "Referrer-Policy": "no-referrer",
      "Content-Security-Policy": "default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' blob:; media-src 'self' blob:; connect-src 'self'; worker-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'",
    } });
  } catch { throw new InputError("Not found.", 404); }
  finally { if (descriptor !== undefined) closeSync(descriptor); }
}

function json(value: unknown, status = 200) {
  let encoded = JSON.stringify(value);
  if (Buffer.byteLength(encoded) > 1_048_576) {
    status = 413; encoded = JSON.stringify({ error: "Conversation history exceeds this mobile client's response limit. The full history remains saved on the Mac." });
  }
  return new Response(encoded, { status, headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff" } });
}

if (import.meta.main) {
  const cwd = process.env.DOT_WORKSPACE ? resolve(process.env.DOT_WORKSPACE) : join(homedir(), "Developer", "Chat");
  const dataDirectory = process.env.DOT_DATA_DIRECTORY ? resolve(process.env.DOT_DATA_DIRECTORY) : join(homedir(), "Library/Application Support/OpenDot");
  const rpc = new AppServer([process.env.DOT_CODEX_BIN ?? join(homedir(), ".local/bin/codex"), "app-server", "--stdio"], cwd);
  const claude = new ClaudeCode([process.env.DOT_CLAUDE_BIN ?? join(homedir(), ".local/bin/claude")], cwd);
  const sessions = new Sessions(rpc, join(dataDirectory, "mobile-session.json"), cwd, claude);
  let notifications: Notifications | undefined;
  try {
    notifications = new Notifications(join(dataDirectory, "notifications.json"), configuredPushSender());
    sessions.observeNotifications((observation) => notifications!.observe(observation));
  } catch { console.error("Dot notifications are unavailable; conversation service is unchanged."); }
  const port = Number(process.env.DOT_PORT ?? "19453");
  if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error("Invalid DOT_PORT.");
  const server = Bun.serve({
    hostname: "127.0.0.1", port, maxRequestBodySize: Math.max(MAX_AUDIO_BODY, MAX_FILE_BODY),
    fetch: httpHandler(sessions, {
      allowedLogin: process.env.DOT_ALLOWED_TAILSCALE_LOGIN ?? "",
      publicHost: process.env.DOT_PUBLIC_HOST ?? "pedros-mac-mini.tail90fb4c.ts.net:9453",
      iosArtifact: resolve(import.meta.dir, "../dist/ios-device/Dot.ipa"),
      webDirectory: process.env.DOT_WEB_DIRECTORY ? resolve(process.env.DOT_WEB_DIRECTORY) : resolve(import.meta.dir, "../dist/dot.web"),
      notifications,
    }),
  });
  const recordFailure = rpc.onFailure;
  rpc.onFailure = (error) => {
    recordFailure(error);
    notifications?.close();
    claude.close();
    server.stop(true);
    process.exit(1);
  };
  void sessions.ready.catch(() => {
    notifications?.close(); server.stop(true); rpc.close(); claude.close(); process.exit(1);
  });
  console.log(`Open Dot listening on http://127.0.0.1:${server.port}`);
  const shutdown = () => { notifications?.close(); server.stop(true); rpc.close(); claude.close(); process.exit(0); };
  process.on("SIGTERM", shutdown); process.on("SIGINT", shutdown);
}
