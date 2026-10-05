import { afterEach, expect, test } from "bun:test";
import { mkdtempSync, readFileSync, writeFileSync, mkdirSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createHash } from "node:crypto";
import { ClaudeCode } from "../claude.ts";
import { Sessions } from "../session.ts";
import { detachedWorker, frontOptions, prepareFrontState } from "../claude-front.ts";
import { FrontWorker, workerRequestId, workerToolCall } from "../front-worker.ts";
import { httpHandler } from "../server.ts";

const owned: { root: string; claude?: ClaudeCode; server?: ReturnType<typeof Bun.serve> }[] = [];
afterEach(async () => { for (const item of owned.splice(0)) { item.claude?.close(); item.server?.stop(true); await Bun.sleep(30); rmSync(item.root, { recursive: true, force: true }); } });
function files() {
  const root = mkdtempSync(join(tmpdir(), "dot-front-"));
  owned.push({ root });
  const workerFile = join(root, "mobile-session.json"), frontFile = join(root, "claude-front-session.json");
  const state = { version: 1, selectedThreadId: "one", threads: [{ id: "one", title: "Existing", provider: "codex", status: "working", codexId: "official", turnId: "critical-task",
    messages: [{ id: "user-old", clientId: "old", role: "user", provider: "codex", text: "Keep the critical work running" },
      { id: "assistant-old", role: "assistant", provider: "codex", text: "Historical Codex answer" }] }],
    requests: [{ id: "old", hash: "old-hash", threadId: "one", provider: "codex", turnId: "critical-task", phase: "submitted" }] };
  writeFileSync(workerFile, JSON.stringify(state));
  prepareFrontState(workerFile, frontFile);
  return { root, workerFile, frontFile, source: readFileSync(workerFile, "utf8"), state };
}
async function until(check: () => boolean) { for (let i = 0; i < 150; i++) { if (check()) return; await Bun.sleep(20); } throw Error("Test timed out"); }

test("Claude front preserves history and worker receipts while producing only new Claude speech", async () => {
  const f = files();
  const claude = new ClaudeCode([process.execPath, join(import.meta.dir, "mock-claude.ts"), join(f.root, "claude.json"), "complete"], f.root);
  owned.at(-1)!.claude = claude;
  const session = new Sessions(detachedWorker(), f.frontFile, f.root, claude, undefined, frontOptions({ ...f, origin: "http://127.0.0.1:19453", login: "owner" }));
  await session.ready;
  expect(session.snapshot().provider).toBe("claude");
  expect(session.snapshot().threads[0].status).toBe("idle");
  expect(session.snapshot().acceptedRequestIds).toContain("old");
  expect(session.snapshot().threads[0].messages.at(-1)?.text).toBe("Historical Codex answer");
  expect(() => session.setProvider({ provider: "codex" })).toThrow("conversation speaker");
  session.submit({ requestId: "new", text: "Answer this" });
  await until(() => session.snapshot().threads[0].status === "idle");
  expect(session.snapshot().threads[0].messages.at(-1)?.text).toBe("Claude reply");
  expect(readFileSync(f.workerFile, "utf8")).toBe(f.source);
  const call = JSON.parse(readFileSync(join(f.root, "claude.json"), "utf8")).calls[0];
  expect(call.input.message.content).toContain("Historical Codex answer");
  expect(call.args[call.args.indexOf("--tools") + 1]).toBe("");
  expect(call.args).toContain("--strict-mcp-config");
  expect(JSON.parse(call.args[call.args.indexOf("--mcp-config") + 1]).mcpServers.codex_worker.args.at(-1)).toBe("new");
  f.state.threads[0].messages.push({ id: "new-worker", role: "assistant", provider: "codex", text: "Worker-only follow-up" } as any);
  writeFileSync(f.workerFile, JSON.stringify(f.state));
  expect(JSON.stringify(session.snapshot())).not.toContain("Worker-only follow-up");
});

test("front Stop cancels Claude without altering or interrupting the Codex worker", async () => {
  const f = files();
  const claude = new ClaudeCode([process.execPath, join(import.meta.dir, "mock-claude.ts"), join(f.root, "claude.json"), "hold"], f.root);
  owned.at(-1)!.claude = claude;
  const session = new Sessions(detachedWorker(), f.frontFile, f.root, claude, undefined, frontOptions({ ...f, origin: "http://127.0.0.1:19453", login: "owner" }));
  await session.ready; session.submit({ requestId: "front-stop", text: "Wait" });
  await until(() => { try { return JSON.parse(readFileSync(join(f.root, "claude.json"), "utf8")).calls.length > 0; } catch { return false; } });
  await session.stop({ threadId: "one" });
  await until(() => session.snapshot().threads[0].status === "idle");
  expect(readFileSync(f.workerFile, "utf8")).toBe(f.source);
  expect(JSON.parse(readFileSync(f.frontFile, "utf8")).requests.find((item: any) => item.id === "old").phase).toBe("submitted");
});

test("worker relay forwards exact user text once, rejects injected instructions, and reads status without sending", async () => {
  const f = files(), calls: any[] = [];
  const accepted = new Set<string>();
  const server = Bun.serve({ hostname: "127.0.0.1", port: 0, async fetch(request) {
    expect(request.headers.get("tailscale-user-login")).toBe("owner");
    if (new URL(request.url).pathname === "/health") return Response.json({ status: "ok", provider: "codex" });
    const body = await request.json() as any; calls.push(body); accepted.add(body.requestId);
    return Response.json({ acceptedRequestIds: [...accepted] });
  } }); owned.at(-1)!.server = server;
  const state = JSON.parse(readFileSync(f.frontFile, "utf8"));
  state.threads[0].messages.push({ id: "new", clientId: "relay", role: "user", text: "Deploy only the requested fix", provider: "claude" });
  state.requests.push({ id: "relay", threadId: "one", provider: "claude", phase: "submitted" });
  writeFileSync(f.frontFile, JSON.stringify(state));
  const worker = new FrontWorker({ ...f, origin: `http://127.0.0.1:${server.port}`, login: "owner" }, "relay");
  expect(await workerToolCall(worker, "worker_status", {})).toMatchObject({ status: "working" }); expect(calls).toHaveLength(0);
  await expect(workerToolCall(worker, "worker_submit", { text: "Invented destructive command" })).rejects.toThrow("no caller-supplied");
  await worker.submit(); await worker.submit();
  expect(accepted.size).toBe(1); expect(calls[0]).toEqual({ requestId: workerRequestId("relay"), threadId: "one", provider: "codex", text: "Deploy only the requested fix" });
  expect(calls[1]).toEqual(calls[0]);
  state.requests.at(-1).phase = "completed"; writeFileSync(f.frontFile, JSON.stringify(state));
  await expect(worker.submit()).rejects.toThrow("not active");
});

test("relay retains original photo and audio bytes and caption, not generated replacements", async () => {
  const f = files(), uploads: { metadata: any; bytes: Buffer; mime: string }[] = [];
  const server = Bun.serve({ hostname: "127.0.0.1", port: 0, async fetch(request) {
    const form = await request.formData(), metadata = JSON.parse(String(form.get("metadata"))), file = (form.get("audio") ?? form.get("image")) as File;
    uploads.push({ metadata, bytes: Buffer.from(await file.arrayBuffer()), mime: file.type });
    return Response.json({ acceptedRequestIds: [metadata.requestId] });
  } }); owned.at(-1)!.server = server;
  const state = JSON.parse(readFileSync(f.frontFile, "utf8"));
  const image = Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC", "base64");
  const imageId = createHash("sha256").update(image).digest("hex");
  mkdirSync(join(f.root, "images")); writeFileSync(join(f.root, "images", imageId + ".png"), image);
  const audio = Buffer.from("00000018667479704d344120000000004d34412069736f6d", "hex"), audioId = createHash("sha256").update(audio).digest("hex");
  mkdirSync(join(f.root, "audio")); writeFileSync(join(f.root, "audio", audioId + ".m4a"), audio);
  state.threads[0].messages.push({ id: "photo", clientId: "photo", role: "user", text: "Original caption", image: { id: imageId, mimeType: "image/png", width: 1, height: 1 } });
  state.requests.push({ id: "photo", threadId: "one", provider: "claude", phase: "submitted" });
  state.threads[0].messages.push({ id: "audio", clientId: "audio", role: "user", text: "Transcript", audio: { id: audioId, mimeType: "audio/mp4", durationMs: 1200, caption: "Voice caption" } });
  state.requests.push({ id: "audio", threadId: "one", provider: "claude", phase: "submitted" });
  writeFileSync(f.frontFile, JSON.stringify(state));
  const config = { ...f, origin: `http://127.0.0.1:${server.port}`, login: "owner" };
  await new FrontWorker(config, "photo").submit(); await new FrontWorker(config, "audio").submit();
  expect(uploads[0].bytes).toEqual(image); expect(uploads[0].metadata.text).toBe("Original caption");
  expect(uploads[1].bytes).toEqual(audio); expect(uploads[1].metadata.text.endsWith("Latest user message:\nVoice caption")).toBe(true);
  expect(uploads[1].metadata.text).toContain("Original caption");
  expect(uploads[1].metadata).not.toHaveProperty("transcript");
});

test("front HTTP boundary and original media ownership remain enforced", async () => {
  const f = files();
  const state = JSON.parse(readFileSync(f.frontFile, "utf8"));
  state.threads[0].messages[0].audio = { id: "a".repeat(64), url: "/api/audio/" + "a".repeat(64), mimeType: "audio/mp4" };
  writeFileSync(f.frontFile, JSON.stringify(state));
  const claude = new ClaudeCode([process.execPath, join(import.meta.dir, "mock-claude.ts"), join(f.root, "claude.json"), "complete"], f.root); owned.at(-1)!.claude = claude;
  const session = new Sessions(detachedWorker(), f.frontFile, f.root, claude, undefined, frontOptions({ ...f, origin: "http://127.0.0.1:19453", login: "owner" }));
  await session.ready; expect(session.ownsAudio("a".repeat(64))).toBe(true);
  const handler = httpHandler(session, { allowedLogin: "owner", publicHost: "dot.test" });
  expect((await handler(new Request("https://dot.test/health", { headers: { host: "dot.test" } }))).status).toBe(403);
  expect((await handler(new Request("https://dot.test/health", { headers: { host: "dot.test", "tailscale-user-login": "owner" } }))).status).toBe(200);
  expect(() => prepareFrontState(f.workerFile, f.workerFile)).toThrow("never share");
});

test("cutover sync retains staging arrivals and worker completion produces one genuine Claude summary", async () => {
  const f = files();
  const claude = new ClaudeCode([process.execPath, join(import.meta.dir, "mock-claude.ts"), join(f.root, "claude.json"), "complete"], f.root); owned.at(-1)!.claude = claude;
  const session = new Sessions(detachedWorker(), f.frontFile, f.root, claude, undefined, frontOptions({ ...f, origin: "http://127.0.0.1:19453", login: "owner" }));
  await session.ready;
  f.state.threads[0].messages.push({ id: "late-user", clientId: "late", role: "user", provider: "codex", text: "Latest user message during staging" });
  f.state.requests.push({ id: "late", hash: "late-hash", threadId: "one", provider: "codex", turnId: "critical-task", phase: "submitted" });
  const source = { state: f.state, thread: f.state.threads[0] };
  session.captureFrontHistory(source);
  expect(JSON.stringify(session.snapshot())).toContain("Latest user message during staging");
  expect(session.snapshot().acceptedRequestIds).toContain("late");
  session.observeBackground(source);
  expect(session.snapshot().threads[0].status).toBe("idle");
  source.thread.status = "idle"; source.state.requests.at(-1)!.phase = "completed";
  source.thread.messages.push({ id: "worker-final", role: "assistant", provider: "codex", text: "Verified worker completion" } as any);
  session.observeBackground(source); session.observeBackground(source);
  await until(() => session.snapshot().threads[0].status === "idle");
  expect(session.snapshot().threads[0].messages.at(-1)?.text).toBe("Claude reply");
  expect(JSON.stringify(session.snapshot())).not.toContain("Verified worker completion");
  const calls = JSON.parse(readFileSync(join(f.root, "claude.json"), "utf8")).calls;
  expect(calls).toHaveLength(1); expect(calls[0].input.message.content).toContain("Verified worker completion");
  expect(calls[0].input.message.content).toContain("Never say all work is done based on worker idleness");
  expect(calls[0].input.message.content).toContain("pending OpenDot/device verification boundary");
  expect(JSON.parse(calls[0].args[calls[0].args.indexOf("--mcp-config") + 1]).mcpServers.codex_worker).toBeDefined();
  expect(readFileSync(f.workerFile, "utf8")).toBe(f.source);
});


test("internal Claude events can verify live status but cannot invent worker authority", async () => {
  const f = files();
  const server = Bun.serve({ hostname: "127.0.0.1", port: 0, fetch: () => Response.json({ status: "ok", provider: "codex" }) }); owned.at(-1)!.server = server;
  const state = JSON.parse(readFileSync(f.frontFile, "utf8"));
  state.requests.push({ id: "internal", threadId: "one", provider: "claude", phase: "submitted", internalPrompt: "Verify status" });
  writeFileSync(f.frontFile, JSON.stringify(state));
  const worker = new FrontWorker({ ...f, origin: `http://127.0.0.1:${server.port}`, login: "owner" }, "internal");
  expect(await worker.status()).toMatchObject({ live: true, status: "working" });
  await expect(worker.submit()).rejects.toThrow("not active");
  await expect(worker.stop()).rejects.toThrow("not active");
});

test("pronoun corrections relay unsent original dialogue as context with a stable retry envelope", async () => {
  const f = files(), calls: any[] = [];
  const server = Bun.serve({ hostname: "127.0.0.1", port: 0, async fetch(request) { const body = await request.json() as any; calls.push(body); return Response.json({ acceptedRequestIds: [body.requestId] }); } }); owned.at(-1)!.server = server;
  const state = JSON.parse(readFileSync(f.frontFile, "utf8"));
  state.threads[0].messages.push({ id: "user-layout", clientId: "layout", role: "user", provider: "claude", text: "The composer is four pieces. Makes sense right?" },
    { id: "claude-confirmation", role: "assistant", provider: "claude", text: "Do you want it to be four pieces?" },
    { id: "correction", clientId: "correction", role: "user", provider: "claude", text: "I literally just said that" });
  state.requests.push({ id: "correction", threadId: "one", provider: "claude", phase: "submitted" });
  writeFileSync(f.frontFile, JSON.stringify(state));
  const worker = new FrontWorker({ ...f, origin: `http://127.0.0.1:${server.port}`, login: "owner" }, "correction");
  await worker.submit();
  expect(calls[0].text).toContain('"role":"user","text":"The composer is four pieces. Makes sense right?"');
  expect(calls[0].text).toContain('"role":"assistant","text":"Do you want it to be four pieces?"');
  expect(calls[0].text.endsWith("Latest user message:\nI literally just said that")).toBe(true);
  state.threads[0].messages[2].text = "This older context changed after submission"; writeFileSync(f.frontFile, JSON.stringify(state));
  await worker.submit(); expect(calls[1]).toEqual(calls[0]);
});

test("verified per-issue facts reach Claude and distinguish global worker activity", async () => {
  const f = files();
  writeFileSync(join(f.root, "claude-front-facts.json"), JSON.stringify({ version: 1, verifiedAt: "2026-10-05T19:00:00Z", items: [{ issue: "TIC-143", status: "Done", boundary: "Realtime does not depend on warm deployment" }] }));
  const claude = new ClaudeCode([process.execPath, join(import.meta.dir, "mock-claude.ts"), join(f.root, "claude.json"), "complete"], f.root); owned.at(-1)!.claude = claude;
  const session = new Sessions(detachedWorker(), f.frontFile, f.root, claude, undefined, frontOptions({ ...f, origin: "http://127.0.0.1:19453", login: "owner" }));
  await session.ready; session.submit({ requestId: "delivery-question", text: "Is realtime ready?" });
  await until(() => session.snapshot().threads[0].status === "idle");
  const call = JSON.parse(readFileSync(join(f.root, "claude.json"), "utf8")).calls[0];
  expect(call.input.message.content).toContain('"issue":"TIC-143","status":"Done"');
  expect(call.input.message.content).toContain("Realtime does not depend on warm deployment");
  expect(call.args.join(" ")).toContain("Global worker activity is not a feature delivery status");
  writeFileSync(join(f.root, "claude-front-facts.json"), JSON.stringify({ version: 1, verifiedAt: "2026-10-05T20:15:00Z", items: [{ issue: "TIC-142", status: "Canceled by user", boundary: "No upgrade authorized; legacy restart is an explicit workflow step, not a mandatory image rebuild." }] }));
  session.submit({ requestId: "cancellation-question", text: "Are we done?" });
  await until(() => session.snapshot().threads[0].status === "idle");
  const followup = JSON.parse(readFileSync(join(f.root, "claude.json"), "utf8")).calls[1];
  expect(followup.args).toContain("--resume");
  expect(followup.input.message.content).toContain('"status":"Canceled by user"');
  expect(followup.input.message.content.indexOf("CURRENT VERIFIED WORKER FACTS")).toBeGreaterThan(followup.input.message.content.indexOf("Are we done?"));
  expect(followup.args.join(" ")).toContain("never treat your own prior claims as evidence");
  expect(followup.args.join(" ")).toContain("do not guess, recommend a paid plan, or promise a fix");
});

test("front retains renderer feedback across restarts without imposing a text cap", async () => {
  const f = files();
  const config = { ...f, origin: "http://127.0.0.1:19453", login: "owner" };
  const claude = new ClaudeCode([process.execPath, join(import.meta.dir, "mock-claude.ts"), join(f.root, "claude.json"), "complete"], f.root);
  owned.at(-1)!.claude = claude;
  const first = new Sessions(detachedWorker(), f.frontFile, f.root, claude, undefined, frontOptions(config));
  await first.ready;
  expect(first.health().display).toMatchObject({ inlineLines: 4, messageWidth: 238, source: "last-known-phone-width" });
  first.observeDisplay(new URLSearchParams({ inlineLines: "4", messageWidth: "266", assistantLines: "12" }));
  const restarted = new Sessions(detachedWorker(), f.frontFile, f.root, claude, undefined, frontOptions(config));
  await restarted.ready;
  expect(restarted.health().display).toMatchObject({ inlineLines: 4, messageWidth: 266, assistantLines: 12, source: "client-renderer" });
  const original = "Give all the requested details. " + "Necessary context. ".repeat(100).trimEnd();
  restarted.submit({ requestId: "brief-policy", text: original });
  await until(() => restarted.snapshot().threads[0].status === "idle");
  const call = JSON.parse(readFileSync(join(f.root, "claude.json"), "utf8")).calls[0];
  expect(call.input.message.content).toContain("up to 4 rendered lines at 266px");
  expect(call.input.message.content).toContain("12 rendered lines and exceeds that limit");
  expect(call.input.message.content).toContain("one short paragraph");
  expect(call.input.message.content).toContain("never omit necessary information");
  expect(call.input.message.content).toContain(original);
  expect(call.args.join(" ")).toContain("never demand a magic confirmation word");
  expect(JSON.parse(readFileSync(f.frontFile, "utf8")).threads[0].messages.find((m: any) => m.clientId === "brief-policy").text).toBe(original);
});
