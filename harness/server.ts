import { homedir } from "node:os";
import { join, resolve, sep } from "node:path";
import { realpathSync, statSync } from "node:fs";
import { AppServer } from "./rpc.ts";
import { Sessions, InputError, object } from "./session.ts";

const MAX_BODY = 128_000;
export type HttpOptions = { allowedLogin: string; publicHost: string; staticRoot: string };
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
        if (request.headers.get("content-type")?.split(";")[0].trim() !== "application/json") throw new InputError("Use application/json.", 415);
        const body = object(await readBody(request));
        if (url.pathname === "/api/turn") return json(sessions.submit(body), 202);
        if (url.pathname === "/api/new") return json(sessions.newThread(), 201);
        if (url.pathname === "/api/stop") return json(await sessions.stop(body));
        if (url.pathname === "/api/select") return json(sessions.select(body));
        throw new InputError("Not found.", 404);
      }
      if (url.pathname === "/health") return json(sessions.health(), sessions.isReady ? 200 : 503);
      if (url.pathname === "/api/session") return json(sessions.snapshot(url.searchParams.get("before") ?? undefined));
      if (url.pathname.startsWith("/api/")) throw new InputError("Not found.", 404);
      return staticResponse(url.pathname, options.staticRoot, request.method === "HEAD");
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

function staticResponse(pathname: string, root: string, head: boolean) {
  let decoded: string;
  try { decoded = decodeURIComponent(pathname); } catch { throw new InputError("Invalid path."); }
  if (decoded.includes("\0") || decoded.includes("\\") || decoded.split("/").includes("..")) throw new InputError("Invalid path.", 403);
  let actualRoot: string, file: string;
  try {
    actualRoot = realpathSync(root);
    file = realpathSync(resolve(actualRoot, `.${decoded === "/" ? "/index.html" : decoded}`));
    if (!file.startsWith(actualRoot + sep) || !statSync(file).isFile()) throw new InputError("Not found.", 404);
  } catch (error) {
    if (error instanceof InputError) throw error;
    throw new InputError("Not found.", 404);
  }
  const asset = Bun.file(file);
  return new Response(head ? null : asset, { headers: { "Content-Type": asset.type, "X-Content-Type-Options": "nosniff", "Cache-Control": "no-cache" } });
}

function json(value: unknown, status = 200) {
  let encoded = JSON.stringify(value);
  if (Buffer.byteLength(encoded) > 1_048_576) {
    status = 413; encoded = JSON.stringify({ error: "Conversation history exceeds this mobile client's response limit. The full history remains saved on the Mac." });
  }
  return new Response(encoded, { status, headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff" } });
}

if (import.meta.main) {
  const cwd = join(homedir(), "Developer", "Chat");
  const rpc = new AppServer([process.env.DOT_CODEX_BIN ?? join(homedir(), ".local/bin/codex"), "app-server", "--stdio"], cwd);
  const sessions = new Sessions(rpc, join(homedir(), "Library/Application Support/OpenDot/mobile-session.json"), cwd);
  const port = Number(process.env.DOT_PORT ?? "19453");
  if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error("Invalid DOT_PORT.");
  const server = Bun.serve({
    hostname: "127.0.0.1", port, maxRequestBodySize: MAX_BODY,
    fetch: httpHandler(sessions, {
      allowedLogin: process.env.DOT_ALLOWED_TAILSCALE_LOGIN ?? "",
      publicHost: process.env.DOT_PUBLIC_HOST ?? "pedros-mac-mini.tail90fb4c.ts.net:9453",
      staticRoot: process.env.DOT_STATIC_ROOT ?? resolve(import.meta.dir, "../dist/mobile"),
    }),
  });
  const recordFailure = rpc.onFailure;
  rpc.onFailure = (error) => {
    recordFailure(error);
    server.stop(true);
    process.exit(1);
  };
  void sessions.ready.catch(() => {
    server.stop(true); rpc.close(); process.exit(1);
  });
  console.log(`Open Dot listening on http://127.0.0.1:${server.port}`);
  const shutdown = () => { server.stop(true); rpc.close(); process.exit(0); };
  process.on("SIGTERM", shutdown); process.on("SIGINT", shutdown);
}
