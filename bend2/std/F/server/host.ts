import * as fs from "node:fs";
import * as path from "node:path";
import { spawn } from "node:child_process";
import { connect } from "node:http2";
import { createServer } from "node:net";
import { createHash, createPrivateKey, randomUUID, sign } from "node:crypto";

type JSONValue = null | boolean | number | string | JSONValue[] | { [key: string]: JSONValue };
type Effect = { type: string; id?: string; [key: string]: any };
function errorCode(error: unknown): string {
  return typeof error === "object" && error !== null && "code" in error && typeof error.code === "string" ? error.code : "";
}
const list = (xs: any[]): any => xs.reduceRight((tail, head) => ({ $: "Con", head, tail }), { $: "Nil" });
const array = (xs: any): any[] => { const out = []; while (xs?.$ === "Con") { out.push(xs.head); xs = xs.tail; } return out; };
export function encode(value: JSONValue): any {
  if (value === null) return { $: "std/F/ai/wire_json.Null" };
  if (typeof value === "boolean") return { $: "std/F/ai/wire_json.Boolean", value };
  if (typeof value === "number") return { $: "std/F/ai/wire_json.Number", text: String(value) };
  if (typeof value === "string") return { $: "std/F/ai/wire_json.Text", value };
  if (Array.isArray(value)) return { $: "std/F/ai/wire_json.Array", items: list(value.map(encode)) };
  return { $: "std/F/ai/wire_json.Object", fields: list(Object.entries(value).map(([key, value]) => ({ $: "std/F/ai/wire_json.Field", key, value: encode(value) }))) };
}
export function decode(value: any): JSONValue {
  switch (value.$.split(".").at(-1)) {
    case "Null": return null;
    case "Boolean": return value.value;
    case "Number": return Number(value.text);
    case "Text": return value.value;
    case "Array": return array(value.items).map(decode);
    case "Object": return Object.fromEntries(array(value.fields).map(({ key, value }) => [key, decode(value)]));
    default: throw new Error("Invalid Bend JSON value.");
  }
}

// This driver knows effects, never application routes, schemas or provider policy.
export async function run(modulePath: string, configuration: JSONValue) {
  await import("../../../main.ts");
  const app = (await import(path.resolve(modulePath))).default;
  let state: any, draining = false, closed = false;
  const queue: any[] = [], processes = new Map<string, ReturnType<typeof spawn>>();
  const servers = new Map<string, ReturnType<typeof Bun.serve>>(), requests = new Map<string, (r: Response) => void>();
  const timers = new Map<string, ReturnType<typeof setTimeout>>(), fetches = new Map<string, AbortController>();
  const emit = (event: any, priority = false) => { if (!closed) { const encoded = encode({ ...event, at: new Date().toISOString(), now: Date.now(), uuid: randomUUID() }); priority ? queue.unshift(encoded) : queue.push(encoded); drain(); } };
  const reply = (effect: Effect, value: any) => emit({ type: "effect", id: effect.id ?? "", operation: effect.type, ok: true, value }, true);
  const fail = (effect: Effect, error: unknown) => emit({ type: "effect", id: effect.id ?? "", operation: effect.type, ok: false, error: error instanceof Error ? error.message : String(error), code: errorCode(error) }, true);
  const execute = (effect: Effect) => {
    try {
      switch (effect.type) {
        case "file.read": { const fd = fs.openSync(effect.path, fs.constants.O_RDONLY | fs.constants.O_NOFOLLOW | fs.constants.O_NONBLOCK); try { const stat = fs.fstatSync(fd); if (!stat.isFile() || stat.size > effect.limit) throw new Error("Invalid file or file exceeds limit."); const bytes = fs.readFileSync(fd); reply(effect, { ...(effect.parseJson ? { json: JSON.parse(bytes.toString("utf8")) } : effect.parseJsonLines ? { jsonLines: bytes.toString("utf8").split("\n").filter(line => line.trim()).map(line => { try { return JSON.parse(line); } catch { return null; } }) } : { data: bytes.toString(effect.encoding ?? "utf8") }), size: stat.size, ...(effect.encodings ? { representations: Object.fromEntries(effect.encodings.map((encoding: BufferEncoding) => [encoding, bytes.toString(encoding)])) } : {}), ...(effect.hashAlgorithm ? { digest: createHash(effect.hashAlgorithm).update(bytes).digest("hex") } : {}) }); } finally { fs.closeSync(fd); } break; }
        case "file.write": { fs.mkdirSync(path.dirname(effect.path), { recursive: true, mode: 0o700 }); const temporary = `${effect.path}.${randomUUID()}.tmp`; let fd: number | undefined; try { fd = fs.openSync(temporary, "wx", effect.mode ?? 0o600); fs.writeFileSync(fd, effect.data, { encoding: effect.encoding ?? "utf8" }); fs.fsyncSync(fd); fs.closeSync(fd); fd = undefined; fs.renameSync(temporary, effect.path); const directory = fs.openSync(path.dirname(effect.path), "r"); try { fs.fsyncSync(directory); } finally { fs.closeSync(directory); } reply(effect, null); } finally { if (fd !== undefined) fs.closeSync(fd); if (fs.existsSync(temporary)) fs.unlinkSync(temporary); } break; }
        case "env.read": reply(effect, process.env[effect.name] ?? ""); break;
        case "file.mkdir": fs.mkdirSync(effect.path, { recursive: true, mode: 0o700 }); reply(effect, null); break;
        case "file.remove": fs.rmSync(effect.path, { recursive: effect.recursive === true, force: false }); reply(effect, null); break;
        case "http.cancel": fetches.get(effect.id!)?.abort(); break;
        case "file.create": { fs.mkdirSync(path.dirname(effect.path), { recursive: true, mode: 0o700 }); const temporary = `${effect.path}.${randomUUID()}.tmp`; let fd: number | undefined; try { fd = fs.openSync(temporary, "wx", effect.mode ?? 0o600); fs.writeFileSync(fd, effect.data, { encoding: effect.encoding ?? "utf8" }); fs.fsyncSync(fd); fs.closeSync(fd); fd = undefined; let created = true; try { fs.linkSync(temporary, effect.path); } catch (error) { if (errorCode(error) !== "EEXIST") throw error; created = false; } const directory = fs.openSync(path.dirname(effect.path), "r"); try { fs.fsyncSync(directory); } finally { fs.closeSync(directory); } reply(effect, { created }); } finally { if (fd !== undefined) fs.closeSync(fd); if (fs.existsSync(temporary)) fs.unlinkSync(temporary); } break; }
        case "stdio.listen": process.stdin.setEncoding("utf8"); process.stdin.on("data", data => emit({ type: "stdio.data", data })); process.stdin.on("end", () => emit({ type: "stdio.end" })); break;
        case "stdio.write": process.stdout.write(effect.data); break;
        case "crypto.hashMany": reply(effect, effect.data.map((input: string) => ({ input, digest: createHash(effect.algorithm ?? "sha256").update(input).digest(effect.encoding ?? "hex") }))); break;
        case "file.list": reply(effect, fs.readdirSync(effect.path, { withFileTypes: true }).map(item => ({ name: item.name, directory: item.isDirectory(), file: item.isFile(), symlink: item.isSymbolicLink() }))); break;
        case "crypto.hash": reply(effect, createHash(effect.algorithm ?? "sha256").update(effect.data, effect.inputEncoding ?? "utf8").digest(effect.encoding ?? "hex")); break;
        case "bytes.encodeMany": reply(effect, effect.data.map((value: string) => Buffer.from(value, effect.from ?? "utf8").toString(effect.to ?? "base64"))); break;
        case "crypto.key": { const key = createPrivateKey(fs.readFileSync(effect.path)); reply(effect, { type: key.asymmetricKeyType, curve: key.asymmetricKeyDetails?.namedCurve ?? "" }); break; }
        case "crypto.sign": reply(effect, sign(effect.algorithm, Buffer.from(effect.data, effect.encoding ?? "utf8"), { key: fs.readFileSync(effect.keyPath), dsaEncoding: "ieee-p1363" }).toString("base64url")); break;
        case "http2.fetch": { const url = new URL(effect.url), session = connect(url.origin); const request = session.request({ ":method": effect.method ?? "POST", ":path": url.pathname + url.search, ...effect.headers }); let status = 0, bytes = 0, body = "", settled = false;
          const finish = (error?: unknown) => { if (settled) return; settled = true; request.close(); session.close(); error ? fail(effect, error) : reply(effect, { status, body }); };
          session.on("error", finish); request.on("error", finish); request.on("response", headers => { status = Number(headers[":status"]); }); request.setEncoding("utf8"); request.on("data", data => { bytes += Buffer.byteLength(data); if (bytes > (effect.limit ?? 1048576)) return finish(new Error("HTTP response limit exceeded.")); body += data; }); request.on("end", () => finish()); request.on("close", () => { if (!settled) finish(new Error("HTTP/2 request closed before completion.")); }); request.setTimeout(effect.timeout ?? 30000, () => finish(new Error("HTTP/2 request timed out."))); request.end(effect.body ?? ""); break; }
        case "network.port": { const listener = createServer(); listener.once("error", error => fail(effect, error)); listener.listen(0, effect.hostname ?? "127.0.0.1", () => { const address = listener.address(); listener.close(error => error ? fail(effect, error) : reply(effect, typeof address === "object" && address ? address.port : 0)); }); break; }
        case "file.metadata": { const resolved = fs.realpathSync(effect.path), stat = fs.statSync(resolved); reply(effect, { path: resolved, directory: stat.isDirectory(), file: stat.isFile(), size: stat.size }); break; }
        case "process.detached": { const output = fs.openSync(effect.logPath, "a", 0o600); try { const child = spawn(effect.command, effect.args ?? [], { cwd: effect.cwd, env: { ...process.env, ...effect.env }, detached: true, stdio: ["ignore", output, output] }); child.once("error", error => fail(effect, error)); child.once("spawn", () => { child.unref(); reply(effect, { pid: child.pid }); }); } finally { fs.closeSync(output); } break; }
        case "process.spawn": {
          if (processes.has(effect.id!)) throw new Error("Process handle is already in use.");
          const child = spawn(effect.command, effect.args ?? [], { cwd: effect.cwd, env: { ...process.env, ...effect.env }, stdio: ["pipe", "pipe", "pipe"] });
          processes.set(effect.id!, child); let outputBytes = 0;
          child.stdout!.setEncoding("utf8"); child.stderr!.setEncoding("utf8");
          const output = (stream: string, data: string) => { outputBytes += Buffer.byteLength(data); if (effect.outputLimit && outputBytes > effect.outputLimit) { child.kill(); fail(effect, new Error("Process output limit exceeded.")); return; } emit({ type: "process.data", id: effect.id, stream, data }); };
          child.stdout!.on("data", data => output("stdout", data)); child.stderr!.on("data", data => { if (effect.stderr) output("stderr", data); });
          child.on("error", error => fail(effect, error)); child.on("close", (code, signal) => { processes.delete(effect.id!); emit({ type: "process.exit", id: effect.id, code: code ?? null, signal: signal ?? null }); });
          child.stdin!.on("error", error => fail(effect, error)); child.once("spawn", () => { if (effect.input !== undefined) child.stdin!.end(effect.input); reply(effect, { pid: child.pid }); }); break;
        }
        case "process.write": { const child = processes.get(effect.id!); if (!child) throw new Error("Process handle is unavailable."); child.stdin!.write(effect.data); break; }
        case "process.kill": processes.get(effect.id!)?.kill(effect.signal ?? "SIGTERM"); break;
        case "timer": { const old = timers.get(effect.id!); if (old) clearTimeout(old); timers.set(effect.id!, setTimeout(() => { timers.delete(effect.id!); emit({ type: "timer", id: effect.id }); }, effect.ms)); break; }
        case "timer.cancel": { const timer = timers.get(effect.id!); if (timer) clearTimeout(timer); timers.delete(effect.id!); break; }
        case "http.fetch": { if (fetches.has(effect.id!)) throw new Error("HTTP request handle is already in use."); const controller = new AbortController(); fetches.set(effect.id!, controller); let body = effect.body; if (effect.form) { body = new FormData(); for (const field of effect.form) body.append(field.name, field.text !== undefined ? field.text : new File([Buffer.from(field.data, field.encoding ?? "base64")], field.filename, { type: field.mimeType })); } void fetch(effect.url, { method: effect.method ?? "GET", headers: effect.headers, body, redirect: "error", signal: AbortSignal.any([controller.signal, AbortSignal.timeout(effect.timeout ?? 30000)]) }).then(async response => { const reader = response.body?.getReader(), chunks = []; let bytes = 0; if (reader) try { for (;;) { const part = await reader.read(); if (part.done) break; bytes += part.value.byteLength; if (bytes > (effect.limit ?? 1048576)) { await reader.cancel(); throw new Error("HTTP response limit exceeded."); } chunks.push(part.value); } } finally { reader.releaseLock(); } if (fetches.get(effect.id!) === controller) fetches.delete(effect.id!); reply(effect, { status: response.status, headers: Object.fromEntries(response.headers), body: Buffer.concat(chunks).toString(effect.encoding ?? "utf8") }); }).catch(error => { if (fetches.get(effect.id!) === controller) fetches.delete(effect.id!); fail(effect, error); }).finally(() => { if (fetches.get(effect.id!) === controller) fetches.delete(effect.id!); }); break; }
        case "http.listen": {
          const server = Bun.serve({ hostname: effect.hostname, port: effect.port, maxRequestBodySize: effect.limit,
            async fetch(request) { const id = randomUUID(), url = new URL(request.url); const response = new Promise<Response>(resolve => requests.set(id, resolve)); try { const contentType = request.headers.get("content-type") ?? ""; let body: any, bodyLength = 0;
              if (contentType.startsWith("multipart/form-data;")) { const data = await request.arrayBuffer(); bodyLength = data.byteLength; const form = await new Request(request.url, { method: "POST", headers: request.headers, body: data }).formData(); body = []; for (const [name, item] of form) body.push(typeof item === "string" ? { name, text: item } : { name, filename: item.name, mimeType: item.type, size: item.size, data: Buffer.from(await item.arrayBuffer()).toString("latin1"), encoding: "latin1" }); }
              else { const data = await request.arrayBuffer(); bodyLength = data.byteLength; body = Buffer.from(data).toString("utf8"); }
              emit({ type: "http.request", id, method: request.method, url: request.url, host: url.host, pathname: url.pathname, query: Object.fromEntries(url.searchParams), headers: Object.fromEntries(request.headers), body, bodyLength });
            } catch (error) { requests.delete(id); return new Response("Invalid request body.", { status: 400 }); } return response; }
          }); servers.set(effect.id!, server); reply(effect, { port: server.port }); break;
        }
        case "http.respond": { const respond = requests.get(effect.id!); if (!respond) break; requests.delete(effect.id!); respond(new Response(effect.body === null ? null : effect.encoding ? Buffer.from(effect.body, effect.encoding) : effect.body, { status: effect.status ?? 200, headers: effect.headers })); break; }
        case "log": console.error(effect.message); break;
        case "exit": close(); process.exitCode = effect.code ?? 0; break;
        default: throw new Error(`Unknown host effect: ${effect.type}`);
      }
    } catch (error) { fail(effect, error); }
  };
  const apply = (step: any) => { state = step.state; for (const effect of array(step.effects)) execute(decode(effect) as Effect); };
  function drain() { if (draining) return; draining = true; try { while (queue.length) apply(app.transition(state, queue.shift())); } finally { draining = false; } }
  function close() { closed = true; for (const timer of timers.values()) clearTimeout(timer); for (const controller of fetches.values()) controller.abort(); for (const server of servers.values()) server.stop(true); for (const child of processes.values()) child.kill(); for (const resolve of requests.values()) resolve(new Response("Server stopped.", { status: 503 })); }
  for (const signal of ["SIGINT", "SIGTERM", "SIGHUP", "SIGUSR1", "SIGUSR2"] as const) process.on(signal, () => emit({ type: "signal", signal }));
  draining = true; apply(app.initial(encode(configuration))); draining = false; drain();
  return { close, state: () => decode(state), emit };
}
