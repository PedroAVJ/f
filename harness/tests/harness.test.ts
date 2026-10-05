import { test, expect, afterEach } from "bun:test";
import { mkdtempSync, readFileSync, writeFileSync, mkdirSync, symlinkSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { AppServer } from "../rpc.ts";
import { Sessions } from "../session.ts";
import { httpHandler } from "../server.ts";

const owned: { rpc: AppServer; root: string }[] = [];
afterEach(async () => {
  for (const item of owned.splice(0)) { item.rpc.close(); await Bun.sleep(50); rmSync(item.root, { recursive: true, force: true }); }
});
async function fixture(mode = "complete", existingRoot?: string, timeoutMs = 2_000) {
  const root = existingRoot ?? mkdtempSync(join(tmpdir(), "dot-harness-test-"));
  const rpc = new AppServer([process.execPath, join(import.meta.dir, "mock-app-server.ts"), join(root, "official.json"), mode], root, timeoutMs);
  owned.push({ rpc, root });
  const sessions = new Sessions(rpc, join(root, "session.json"), root);
  await sessions.ready;
  const official = () => JSON.parse(readFileSync(join(root, "official.json"), "utf8"));
  return { root, rpc, sessions, official };
}
async function until(check: () => boolean) {
  const deadline = Date.now() + 2_000;
  while (!check()) { if (Date.now() > deadline) throw new Error("Timed out waiting for test event"); await Bun.sleep(10); }
}
const selected = (sessions: Sessions) => {
  const snapshot = sessions.snapshot(); return snapshot.threads.find((t) => t.id === snapshot.selectedThreadId)!;
};

test("acknowledges immediately, streams real items, deduplicates and resumes official history", async () => {
  const f = await fixture(); const id = selected(f.sessions).id;
  const input = { threadId: id, requestId: "phone-1", text: "Hello" };
  const accepted = f.sessions.submit(input);
  expect(accepted.acceptedRequestIds).toEqual(["phone-1"]);
  expect(accepted.threads[0].status).toBe("working");
  expect(accepted.threads[0].messages).toEqual([{ role: "user", text: "Hello" }]);
  f.sessions.submit(input);
  await until(() => selected(f.sessions).status === "idle");
  expect(selected(f.sessions).messages).toEqual([{ role: "user", text: "Hello" }, { role: "assistant", text: "Hello world" }]);
  expect(f.official().calls.filter((x: any) => x.method === "turn/start")).toHaveLength(1);
  const params = f.official().calls.find((x: any) => x.method === "thread/start").params;
  expect(params).toMatchObject({ sandbox: "workspace-write", approvalPolicy: "on-request", approvalsReviewer: "auto_review" });
  expect(params.model).toBe("canonical-test-model");
  expect(f.official().calls.find((x: any) => x.method === "turn/start").params.model).toBe("canonical-test-model");
  expect(f.sessions.health().model).toBe("canonical-test-model");
  f.rpc.close(); owned.pop(); await Bun.sleep(50);
  const resumed = await fixture("complete", f.root);
  expect(selected(resumed.sessions).messages).toHaveLength(2);
  resumed.sessions.submit(input);
  expect(resumed.official().calls.filter((x: any) => x.method === "turn/start")).toHaveLength(1);
  expect(resumed.official().calls.map((x: any) => x.method)).toContain("thread/resume");
  expect(resumed.official().calls.map((x: any) => x.method)).toContain("thread/read");
  expect(() => resumed.sessions.submit({ ...input, text: "Different" })).toThrow("different message");
});

test("stop interrupts only this session and blocks overlapping sends", async () => {
  const f = await fixture("hold"); const id = selected(f.sessions).id;
  f.sessions.submit({ threadId: id, requestId: "hold-1", text: "Wait" });
  await until(() => f.official().calls.some((x: any) => x.method === "turn/start"));
  expect(() => f.sessions.submit({ threadId: id, requestId: "hold-2", text: "Second" })).toThrow("still working");
  await f.sessions.stop({ threadId: id });
  await until(() => selected(f.sessions).status === "idle");
  expect(selected(f.sessions).error).toBe("Turn stopped.");
  expect(f.official().calls.find((x: any) => x.method === "turn/interrupt").params).toEqual({ threadId: "codex-1", turnId: "turn-1" });
});

test("queued stop never starts a turn; restarting never replays an uncertain submission", async () => {
  const f = await fixture("hold"); const id = selected(f.sessions).id;
  f.sessions.submit({ threadId: id, requestId: "queue-stop", text: "Cancel me" });
  await f.sessions.stop({ threadId: id });
  await until(() => selected(f.sessions).status === "idle");
  expect(f.official().calls.filter((x: any) => x.method === "turn/start")).toHaveLength(0);
  await Bun.sleep(10);
  f.sessions.submit({ threadId: id, requestId: "uncertain", text: "Hold" });
  await until(() => f.official().calls.some((x: any) => x.method === "turn/start"));
  f.rpc.close(); owned.pop(); await Bun.sleep(50);
  const resumed = await fixture("hold", f.root);
  expect(selected(resumed.sessions).status).toBe("idle");
  expect(selected(resumed.sessions).error).toContain("not resent");
  resumed.sessions.submit({ threadId: id, requestId: "uncertain", text: "Hold" });
  expect(resumed.official().calls.filter((x: any) => x.method === "turn/start")).toHaveLength(1);
});

test("surfaces provider failure and declines unsupported interactive approval", async () => {
  const failed = await fixture("fail");
  failed.sessions.submit({ requestId: "failed-1", text: "Hello" });
  await until(() => selected(failed.sessions).status === "failed");
  expect(selected(failed.sessions).error).toBe("Provider unavailable");
  const approval = await fixture("approval");
  approval.sessions.submit({ requestId: "approval-1", text: "Hello" });
  await until(() => approval.official().replies.length > 0);
  expect(approval.official().replies[0]).toEqual({ id: "approval-1", result: { decision: "decline" } });
  expect(selected(approval.sessions).error).toContain("declined");
});

test("a missing turn acknowledgement does not permit overlapping work or replay", async () => {
  const f = await fixture("timeout", undefined, 80); const id = selected(f.sessions).id;
  const input = { threadId: id, requestId: "timeout-1", text: "Hold" };
  f.sessions.submit(input);
  await until(() => !!selected(f.sessions).error);
  expect(selected(f.sessions).status).toBe("working");
  expect(selected(f.sessions).error).toContain("unknown");
  f.sessions.submit(input);
  expect(() => f.sessions.submit({ ...input, requestId: "timeout-2" })).toThrow("still working");
  await f.sessions.stop({ threadId: id });
  await until(() => selected(f.sessions).status === "idle");
  expect(f.official().calls.filter((x: any) => x.method === "turn/start")).toHaveLength(1);
});

test("completed notification wins over a later missing acknowledgement timeout", async () => {
  const f = await fixture("complete-no-ack", undefined, 80);
  f.sessions.submit({ requestId: "complete-no-ack-1", text: "Hello" });
  await until(() => selected(f.sessions).status === "idle");
  await Bun.sleep(80);
  expect(selected(f.sessions).status).toBe("idle");
  expect(selected(f.sessions).error).toBeUndefined();
  expect(selected(f.sessions).messages.at(-1)?.text).toBe("Hello world");
});

test("HTTP authenticates remote requests, enforces origin/body limits and confines static files", async () => {
  const f = await fixture(); const root = join(f.root, "static"); mkdirSync(root);
  writeFileSync(join(root, "index.html"), "<p>Dot</p>");
  writeFileSync(join(f.root, "outside.txt"), "private fixture"); symlinkSync(join(f.root, "outside.txt"), join(root, "escape.txt"));
  const host = "mini.tail.test:9453";
  const handler = httpHandler(f.sessions, { allowedLogin: "owner@test", publicHost: host, staticRoot: root });
  const request = (path: string, init: RequestInit = {}, remote = false) => {
    const headers = new Headers(init.headers);
    if (!remote) headers.set("Tailscale-User-Login", "owner@test");
    return handler(new Request(`${remote ? `https://${host}` : "http://127.0.0.1:19453"}${path}`, { ...init, headers }));
  };
  expect((await handler(new Request("http://localhost:19453/api/session"))).status).toBe(403);
  expect((await handler(new Request(`https://${host}/api/session`, { headers: { Host: "127.0.0.1:19453" } }))).status).toBe(403);
  expect((await request("/api/session", {}, true)).status).toBe(403);
  expect((await request("/api/session", { headers: { "Tailscale-User-Login": "other@test" } }, true)).status).toBe(403);
  expect((await request("/health", { headers: { "Tailscale-User-Login": "owner@test" } }, true)).status).toBe(200);
  expect((await request("/api/new", { method: "POST", headers: { "content-type": "application/json", origin: "https://evil.test" }, body: "{}" })).status).toBe(403);
  const headers = { "content-type": "application/json", origin: "http://127.0.0.1:19453" };
  expect((await request("/api/new", { method: "POST", headers, body: "{" })).status).toBe(400);
  expect((await request("/api/new", { method: "POST", headers, body: JSON.stringify({ text: "x".repeat(128_001) }) })).status).toBe(413);
  const response = await request("/api/new", { method: "POST", headers, body: "{}" });
  expect(response.status).toBe(201); expect((await response.json() as any).threads).toHaveLength(2);
  const first = f.sessions.snapshot().threads[0].id;
  const select = await request("/api/select", { method: "POST", headers, body: JSON.stringify({ threadId: first }) });
  expect((await select.json() as any).selectedThreadId).toBe(first);
  expect((await request("/api/select", { method: "POST", headers, body: JSON.stringify({ threadId: "unknown" }) })).status).toBe(404);
  expect((await request("/escape.txt")).status).toBe(404);
  expect((await request("/%2e%2e%2foutside.txt")).status).toBe(403);
  expect(await (await request("/")).text()).toBe("<p>Dot</p>");
});

test("large aggregate history stays usable and every selected chunk can be paged without loss", async () => {
  const root = mkdtempSync(join(tmpdir(), "dot-harness-test-"));
  const source = "START🧩" + "x".repeat(1_048_576) + "END🧩";
  writeFileSync(join(root, "session.json"), JSON.stringify({
    version: 1, selectedThreadId: "empty", requests: [{ id: "old-receipt", hash: "test", threadId: "large", phase: "completed" }], threads: [
      { id: "large", title: "Long conversation", status: "idle", messages: [{ id: "message", role: "assistant", text: source }] },
      { id: "empty", title: "Empty", status: "idle", messages: [] },
    ],
  }));
  const f = await fixture("complete", root);
  const handler = httpHandler(f.sessions, { allowedLogin: "", publicHost: "", staticRoot: root });
  const response = await handler(new Request("http://localhost:19453/api/session"));
  expect(response.status).toBe(200);
  const initial = await response.json() as any;
  expect(initial.threads.every((t: any) => t.messages.length === 0)).toBe(true);
  const created = await handler(new Request("http://localhost:19453/api/new", { method: "POST", headers: { "Content-Type": "application/json", Origin: "http://localhost:19453" }, body: "{}" }));
  expect(created.status).toBe(201);
  f.sessions.select({ threadId: "large" });
  const restored: string[] = []; let before: string | undefined;
  do {
    const page = await handler(new Request(`http://localhost:19453/api/session${before ? `?before=${before}` : ""}`));
    expect(page.status).toBe(200);
    const encoded = await page.text(); expect(encoded.length).toBeLessThan(30_000);
    const snapshot = JSON.parse(encoded);
    expect(snapshot.acceptedRequestIds).toEqual(["old-receipt"]);
    const selected = snapshot.threads.find((t: any) => t.id === "large");
    expect(selected.messages.length).toBeLessThanOrEqual(4);
    expect(selected.messages.every((m: any) => m.role === "assistant" && m.text.length <= 6000)).toBe(true);
    restored.unshift(...selected.messages.map((m: any) => m.text));
    before = selected.historyBefore;
    expect(selected.historyHasMore).toBe(before !== undefined);
  } while (before !== undefined);
  expect(restored.join("")).toBe(source);
  expect(JSON.parse(readFileSync(join(root, "session.json"), "utf8")).threads[0].messages[0].text).toBe(source);
  expect((await handler(new Request("http://localhost:19453/api/session?before=-1"))).status).toBe(400);
});
