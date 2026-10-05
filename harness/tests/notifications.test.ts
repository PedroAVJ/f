import { afterEach, expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { Notifications, type NotificationObservation } from "../notifications.ts";
import { pushPayload, type PushDevice, type PushNotice, type PushResult, type PushSender } from "../apns.ts";
import { httpHandler } from "../server.ts";
import type { Sessions } from "../session.ts";

const fixtures: { root: string; notices: Notifications }[] = [];
const device = { deviceId: "73aba266-38b1-4a9d-99a4-9e0c7253a67a", token: "a".repeat(64), environment: "development", language: "en", enabled: true };
function fixture(result: PushResult = "sent") {
  const root = mkdtempSync(join(tmpdir(), "dot-notifications-"));
  const sent: { device: PushDevice; notice: PushNotice }[] = [];
  const sender: PushSender = { async send(device, notice) { sent.push({ device, notice }); return result; }, close() {} };
  const file = join(root, "notifications.json"), notices = new Notifications(file, sender);
  fixtures.push({ root, notices });
  notices.register(device);
  const observe = (phase: string, overrides: Partial<NotificationObservation> = {}) => notices.observe({ threadId: "thread-1", receiptId: "request-1", phase, failed: false, cancelled: false, ...overrides });
  return { root, file, notices, sender, sent, observe };
}
afterEach(() => { for (const { root, notices } of fixtures.splice(0)) { notices.close(); rmSync(root, { recursive: true, force: true }); } });

test("completed replies alert once, not while streaming, and never replay on restart", async () => {
  const f = fixture();
  f.observe("queued"); f.observe("submitted");
  for (let token = 0; token < 100; token++) f.observe("submitted");
  await f.notices.flush(); expect(f.sent).toHaveLength(0);
  f.observe("completed"); f.observe("completed");
  await f.notices.flush();
  expect(f.sent).toHaveLength(1); expect(f.sent[0].notice.kind).toBe("completed");
  f.notices.close();
  const restarted = new Notifications(f.file, f.sender); fixtures.push({ root: f.root, notices: restarted });
  restarted.observe({ threadId: "thread-1", receiptId: "request-1", phase: "completed", failed: false, cancelled: false });
  await restarted.flush(); expect(f.sent).toHaveLength(1);
});

test("existing terminal history seeds quietly; failures and failed transcription need attention", async () => {
  const f = fixture();
  f.observe("completed"); await f.notices.flush(); expect(f.sent).toHaveLength(0);
  f.observe("queued", { receiptId: "request-2" });
  f.observe("failed", { receiptId: "request-2", failed: true });
  f.observe("failed", { receiptId: "request-2", failed: true });
  await f.notices.flush(); expect(f.sent).toHaveLength(1); expect(f.sent[0].notice.kind).toBe("attention");
  f.observe("processing-audio", { receiptId: "request-3" });
  f.observe("awaiting-transcript", { receiptId: "request-3" });
  await f.notices.flush(); expect(f.sent).toHaveLength(2);
  f.observe("submitted", { receiptId: "request-4" });
  f.observe("cancelled", { receiptId: "request-4", cancelled: true });
  await f.notices.flush(); expect(f.sent).toHaveLength(2);
});

test("explicit pending-user-input hook deduplicates by stable request ID", async () => {
  const f = fixture();
  f.notices.attention("question-1", "thread-1"); f.notices.attention("question-1", "thread-1");
  await f.notices.flush(); expect(f.sent).toHaveLength(1); expect(f.sent[0].notice.kind).toBe("attention");
});

test("token replacement, invalid-token retirement, opt out, and registration bounds", async () => {
  const f = fixture("invalid-device");
  f.notices.register({ ...device, token: "b".repeat(64) });
  f.observe("submitted"); f.observe("completed"); await f.notices.flush();
  expect(f.sent[0].device.token).toBe("b".repeat(64));
  expect(JSON.parse(readFileSync(f.file, "utf8")).devices).toHaveLength(0);
  f.notices.register(device); f.notices.attention("pending", "thread-1");
  f.notices.register({ deviceId: device.deviceId, enabled: false });
  await f.notices.flush(); expect(f.sent).toHaveLength(1);
  expect(() => f.notices.register({ ...device, token: "../../bad" })).toThrow();
  expect(() => f.notices.register({ ...device, environment: "other" })).toThrow();
});

test("retryable deliveries remain durable with the same APNs identity", async () => {
  const f = fixture("retry"); f.observe("submitted"); f.observe("completed"); await f.notices.flush();
  const saved = JSON.parse(readFileSync(f.file, "utf8"));
  expect(saved.pending).toHaveLength(1); expect(saved.pending[0].attempt).toBe(1);
  expect(saved.pending[0].notice.id).toBe(f.sent[0].notice.id);
  expect(saved.pending[0].nextAt).toBeGreaterThan(Date.now());
  const payload = pushPayload(f.sent[0].device, f.sent[0].notice);
  expect(payload.aps.alert.body).toBe("Near’s reply is ready.");
  expect(Object.keys(payload)).toEqual(["aps", "dot"]);
  expect(payload.dot.eventId).toBe(f.sent[0].notice.id);
});

test("notification endpoints retain Tailscale authorization and same-origin writes", async () => {
  const f = fixture();
  const handler = httpHandler({} as Sessions, { allowedLogin: "owner@example.com", publicHost: "dot.example", notifications: f.notices });
  const request = (headers: Record<string, string>, body: unknown = device) => new Request("https://dot.example/api/notifications/device", {
    method: "POST", headers: { host: "dot.example", "content-type": "application/json", ...headers }, body: JSON.stringify(body),
  });
  expect((await handler(request({ origin: "https://dot.example" }))).status).toBe(403);
  expect((await handler(request({ origin: "https://other.example", "tailscale-user-login": "owner@example.com" }))).status).toBe(403);
  expect((await handler(request({ origin: "https://dot.example", "tailscale-user-login": "owner@example.com" }))).status).toBe(200);
  expect((await handler(request({ origin: "https://dot.example", "tailscale-user-login": "owner@example.com" }, { ...device, token: "bad" }))).status).toBe(400);
});


test("registration canonicalizes token identity and rejects malformed UUIDs", () => {
  const f = fixture();
  f.notices.register({ ...device, deviceId: "d0dc7b49-28a9-4568-b6c7-5d7ae9bd4fe2", token: device.token.toUpperCase() });
  const saved = JSON.parse(readFileSync(f.file, "utf8"));
  expect(saved.devices).toHaveLength(1);
  expect(saved.devices[0].token).toBe(device.token);
  expect(() => f.notices.register({ ...device, deviceId: "-".repeat(36) })).toThrow();
});

test("a failed outbox write never sends an undurable notification", async () => {
  const f = fixture();
  f.observe("submitted");
  rmSync(f.file); mkdirSync(f.file);
  f.observe("completed");
  await f.notices.flush();
  expect(f.sent).toHaveLength(0);
  expect(f.notices.status().available).toBe(false);
});


test("corrupt saved deliveries fail closed before a timer can send", () => {
  const f = fixture();
  const state = JSON.parse(readFileSync(f.file, "utf8"));
  state.pending = [{ deviceId: device.deviceId, nextAt: 0 }];
  writeFileSync(f.file, JSON.stringify(state));
  expect(() => new Notifications(f.file, f.sender)).toThrow("Invalid saved notification state.");
  expect(f.sent).toHaveLength(0);
});
