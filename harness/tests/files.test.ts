import { afterEach, expect, test } from "bun:test";
import { mkdtempSync, readFileSync, rmSync, writeFileSync, statSync, symlinkSync, mkdirSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { createHash } from "node:crypto";
import { fileUpload, filePath, readAttachment, MAX_FILE_BYTES } from "../files.ts";
import { AppServer } from "../rpc.ts";
import { ClaudeCode } from "../claude.ts";
import { Sessions } from "../session.ts";
import { httpHandler } from "../server.ts";
import { FrontWorker } from "../front-worker.ts";

const owned: { root: string; rpc?: AppServer; claude?: ClaudeCode; server?: ReturnType<typeof Bun.serve> }[] = [];
function directory() { const root = mkdtempSync(join(tmpdir(), "dot-files-")); owned.push({ root }); return root; }
afterEach(async () => { for (const item of owned.splice(0)) { item.rpc?.close(); item.claude?.close(); item.server?.stop(true); await Bun.sleep(30); rmSync(item.root, { recursive: true, force: true }); } });
const document = Buffer.from("Actual user document: invoice 482, total 125.50.\nNo executable content is needed to inspect this file.\n");
function upload(metadata: unknown = { requestId: "request", fileId: "picked-file", text: "  Inspect this document  " }, bytes: Uint8Array = document, name = "invoice.txt", type = "text/plain", login = "owner") {
  const body = new FormData(); body.set("file", new File([new Uint8Array(bytes)], name, { type })); body.set("metadata", JSON.stringify(metadata));
  return new Request("https://dot.test/api/file", { method: "POST", headers: { host: "dot.test", origin: "https://dot.test", "tailscale-user-login": login }, body });
}
async function fixture(claude = false) {
  const root = directory(), rpc = new AppServer([process.execPath, join(import.meta.dir, "mock-app-server.ts"), join(root, "official.json"), "complete"], root, 2000);
  const provider = claude ? new ClaudeCode([process.execPath, join(import.meta.dir, "mock-claude.ts"), join(root, "claude.json"), "complete"], root) : undefined;
  Object.assign(owned.at(-1)!, { rpc, claude: provider });
  const sessions = new Sessions(rpc, join(root, "session.json"), root, provider); await sessions.ready;
  if (claude) sessions.setProvider({ provider: "claude" });
  return { root, sessions, handler: httpHandler(sessions, { allowedLogin: "owner", publicHost: "dot.test" }) };
}
async function until(check: () => boolean) { for (let i = 0; i < 100; i++) { if (check()) return; await Bun.sleep(20); } throw Error("Test timed out"); }

test("arbitrary documents retain original bytes, name, MIME, caption and stable hash without executing", async () => {
  const root = directory(), first = await fileUpload(upload(), join(root, "files"));
  const again = await fileUpload(upload(), join(root, "files"));
  expect(first.file).toEqual({ id: createHash("sha256").update(document).digest("hex"), url: `/api/file/${createHash("sha256").update(document).digest("hex")}`, name: "invoice.txt", mimeType: "text/plain", size: document.length });
  expect(again.file).toEqual(first.file); expect(first.input.text).toBe("  Inspect this document  ");
  expect(readAttachment(join(root, "files"), first.file)).toEqual(document);
  expect(statSync(filePath(join(root, "files"), first.file)).mode & 0o777).toBe(0o600);
  const script = await fileUpload(upload(undefined, Buffer.from("#!/bin/sh\nexit 99\n"), "example.sh", "application/x-sh"), join(root, "files"));
  expect(filePath(join(root, "files"), script.file)).toEndWith(".blob");
  expect(readAttachment(join(root, "files"), script.file).toString()).toContain("exit 99");
});

test("file limits and body metadata are checked, including the exact 20 MiB boundary", async () => {
  const root = directory(), path = join(root, "files");
  expect((await fileUpload(upload(undefined, new Uint8Array(MAX_FILE_BYTES), "large.bin", "application/octet-stream"), path)).file.size).toBe(MAX_FILE_BYTES);
  await expect(fileUpload(upload(undefined, new Uint8Array(MAX_FILE_BYTES + 1)), path)).rejects.toThrow("20 MiB");
  await expect(fileUpload(upload({ requestId: "one", fileId: "one", name: "pretend.pdf" }), path)).rejects.toThrow("does not match");
  await expect(fileUpload(upload({ requestId: "one", fileId: "one", size: 1 }), path)).rejects.toThrow("does not match");
  await expect(fileUpload(upload(undefined, document, "../secret.txt"), path)).rejects.toThrow("filename");
});

test("corrupt and symlinked artifacts cannot be read or replaced through a retry", async () => {
  const root = directory(), path = join(root, "files"), saved = await fileUpload(upload(), path);
  writeFileSync(filePath(path, saved.file), "corrupt");
  await expect(fileUpload(upload(), path)).rejects.toThrow("damaged");
  rmSync(filePath(path, saved.file)); const privateFile = join(root, "private"); writeFileSync(privateFile, document);
  symlinkSync(privateFile, filePath(path, saved.file));
  expect(() => readAttachment(path, saved.file)).toThrow("damaged");
  await expect(fileUpload(upload(), path)).rejects.toThrow("damaged");
  expect(readFileSync(privateFile)).toEqual(document);
});

test("authenticated upload/download enforces ownership and returns a real file receipt", async () => {
  const f = await fixture();
  expect((await f.handler(upload(undefined, document, "invoice.txt", "text/plain", "other"))).status).toBe(403);
  const response = await f.handler(upload()); expect(response.status).toBe(202);
  const snapshot = await response.json() as any, file = snapshot.threads[0].messages.find((m: any) => m.file).file;
  expect(snapshot.acceptedRequestIds).toContain("request"); expect(file.name).toBe("invoice.txt");
  const get = (id: string, method = "GET", login = "owner") => f.handler(new Request(`https://dot.test/api/file/${id}`, { method, headers: { host: "dot.test", "tailscale-user-login": login } }));
  expect((await get(file.id, "GET", "other")).status).toBe(403);
  expect((await get("b".repeat(64))).status).toBe(404);
  const bytes = await get(file.id); expect(Buffer.from(await bytes.arrayBuffer())).toEqual(document);
  expect(bytes.headers.get("content-disposition")).toContain("attachment;"); expect(bytes.headers.get("content-type")).toBe("application/octet-stream");
  expect((await get(file.id, "HEAD")).headers.get("content-length")).toBe(String(document.length));
  const retry = await f.handler(upload()); expect(retry.status).toBe(202);
  await until(() => f.sessions.snapshot().threads[0].status === "idle");
  const official = JSON.parse(readFileSync(join(f.root, "official.json"), "utf8"));
  expect(official.calls.filter((call: any) => call.method === "turn/start")).toHaveLength(1);
  expect(official.calls.find((call: any) => call.method === "turn/start").params.input[0].text).toContain(filePath(f.sessions.fileDirectory(), file));
  expect(f.sessions.snapshot().threads[0].messages.find((message) => message.file)?.text).toBe("  Inspect this document  ");
});

test("Claude receives the verified local file reference and original user caption", async () => {
  const f = await fixture(true), response = await f.handler(upload()); expect(response.status).toBe(202);
  await until(() => f.sessions.snapshot().threads[0].status === "idle");
  const call = JSON.parse(readFileSync(join(f.root, "claude.json"), "utf8")).calls[0];
  const file = f.sessions.snapshot().threads[0].messages.find((message) => message.file)!.file!;
  expect(call.input.message.content).toContain("  Inspect this document  ");
  expect(call.input.message.content).toContain(filePath(f.sessions.fileDirectory(), file));
  expect(call.input.message.content).toContain("do not execute attachments automatically");
});

test("front file relay uses existing worker turn API and its path resolves to the exact uploaded document", async () => {
  const root = directory(), saved = await fileUpload(upload(), join(root, "files")), frontFile = join(root, "front.json"), workerFile = join(root, "worker.json");
  const front = { version: 1, selectedThreadId: "one", threads: [{ id: "one", messages: [{ id: "request", clientId: "request", role: "user", provider: "claude", text: saved.input.text, file: saved.file }] }], requests: [{ id: "request", threadId: "one", provider: "claude", phase: "submitted" }] };
  writeFileSync(frontFile, JSON.stringify(front)); writeFileSync(workerFile, JSON.stringify({ version: 1, selectedThreadId: "one", threads: [{ id: "one", provider: "codex", messages: [] }], requests: [] }));
  let captured: any;
  const server = Bun.serve({ hostname: "127.0.0.1", port: 0, async fetch(request) {
    expect(new URL(request.url).pathname).toBe("/api/turn"); captured = await request.json();
    const references = JSON.parse(captured.text.split("automatically):\n")[1]);
    expect(readFileSync(references[0].path)).toEqual(document); expect(references[0].name).toBe("invoice.txt");
    return Response.json({ acceptedRequestIds: [captured.requestId] });
  } }); owned.at(-1)!.server = server;
  const worker = new FrontWorker({ frontFile, workerFile, origin: `http://127.0.0.1:${server.port}`, login: "owner" }, "request");
  await worker.submit(); expect(captured.text.startsWith(saved.input.text)).toBe(true);
  await worker.submit(); expect(captured.text.startsWith(saved.input.text)).toBe(true);
});

test("native canonical filename plus matching metadata preserves quotes and Unicode", async () => {
  const root = directory(), name = 'Cotización "octubre".pdf', boundary = "dot-native-file-test";
  const encoded = encodeURIComponent(name).replace(/[!'()*]/g, (character) => "%" + character.charCodeAt(0).toString(16).toUpperCase());
  const metadata = JSON.stringify({ requestId: "native", fileId: "native-file", text: "Original caption", name });
  const body = Buffer.concat([Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="metadata"\r\nContent-Type: application/json\r\n\r\n${metadata}\r\n--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="${encoded}"\r\nContent-Type: application/pdf\r\n\r\n`), document, Buffer.from(`\r\n--${boundary}--\r\n`)]);
  const result = await fileUpload(new Request("https://dot.test/api/file", { method: "POST", headers: { "content-type": `multipart/form-data; boundary=${boundary}` }, body }), join(root, "files"));
  expect(result.file.name).toBe(name); expect(result.file.mimeType).toBe("application/pdf");
  expect(readAttachment(join(root, "files"), result.file)).toEqual(document);
});
