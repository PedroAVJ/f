import { afterEach, expect, test } from "bun:test";
import { mkdtempSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { audioUpload, audioDownload, audioPath } from "../audio.ts";
import { httpHandler } from "../server.ts";
import type { Sessions } from "../session.ts";

const roots: string[] = [];
const directory = () => { const path = mkdtempSync(join(tmpdir(), "dot-web-test-")); roots.push(path); return path; };
afterEach(() => { for (const root of roots.splice(0)) rmSync(root, { recursive: true, force: true }); });

test("browser WebM uploads retain the original bytes, receipt metadata and range playback", async () => {
  const root = directory();
  const bytes = Buffer.from([0x1a, 0x45, 0xdf, 0xa3, ...Buffer.from("webm-test-audio")]);
  const form = new FormData();
  form.set("audio", new File([bytes], "voice.webm", { type: "audio/webm" }));
  form.set("metadata", JSON.stringify({ requestId: "web-audio-1", threadId: "thread-1", durationMs: 1200, text: "Caption" }));
  const result = await audioUpload(new Request("http://localhost/api/audio", { method: "POST", body: form }), root);
  expect(result.audio.mimeType).toBe("audio/webm");
  expect(result.input.requestId).toBe("web-audio-1");
  expect(result.input.text).toBe("Caption");
  expect(audioPath(root, result.audio)).toEndWith(".webm");
  const response = audioDownload(root, result.audio.id, new Request("http://localhost/api/audio", { headers: { Range: "bytes=4-7" } }), result.audio.mimeType);
  expect(response.status).toBe(206);
  expect(response.headers.get("content-type")).toBe("audio/webm");
  expect(await response.text()).toBe("webm");
});

test("browser audio rejects a MIME/container mismatch", async () => {
  const form = new FormData();
  form.set("audio", new File([Buffer.from("0000ftypM4A-this-is-not-webm")], "voice.webm", { type: "audio/webm" }));
  form.set("metadata", JSON.stringify({ durationMs: 1000 }));
  await expect(audioUpload(new Request("http://localhost/api/audio", { method: "POST", body: form }), directory())).rejects.toThrow("Invalid audio container");
});

test("web assets retain Tailscale authorization and never serve adjacent files or symlinks", async () => {
  const root = directory();
  writeFileSync(join(root, "index.html"), "<!doctype html><title>Dot</title>");
  writeFileSync(join(root, "seq.wasm"), "wasm-fixture");
  writeFileSync(join(root, "secret.txt"), "not an asset");
  symlinkSync(join(root, "secret.txt"), join(root, "private.js"));
  const handler = httpHandler({} as Sessions, { allowedLogin: "owner@test", publicHost: "mini.tail.test:9453", webDirectory: root });
  const request = (path: string, authenticated = true, method = "GET") => handler(new Request(`https://mini.tail.test:9453${path}`, { method, headers: authenticated ? { "Tailscale-User-Login": "owner@test" } : {} }));
  expect((await request("/", false)).status).toBe(403);
  const page = await request("/");
  expect(page.status).toBe(200);
  expect(page.headers.get("content-security-policy")).toContain("frame-ancestors 'none'");
  expect(await page.text()).toContain("<title>Dot</title>");
  const wasm = await request("/seq.wasm", true, "HEAD");
  expect(wasm.headers.get("content-type")).toBe("application/wasm");
  expect(await wasm.text()).toBe("");
  expect((await request("/secret.txt")).status).toBe(404);
  expect((await request("/private.js")).status).toBe(404);
  expect((await request("/%2e%2e%2fsecret.txt")).status).toBe(403);
});
