import { existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";
import { randomUUID } from "node:crypto";
import type { PushDevice, PushNotice, PushSender } from "./apns.ts";

export type NotificationObservation = { threadId: string; receiptId?: string; phase?: string; failed: boolean; cancelled: boolean };
type Delivery = { deviceId: string; notice: PushNotice; attempt: number; nextAt: number };
type NotificationState = { version: 1; devices: PushDevice[]; seen: string[];
  observations: Record<string, NotificationObservation>; pending: Delivery[] };

const uuid = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;
const tokenPattern = /^[a-f0-9]{64,512}$/i;
function validState(state: NotificationState) {
  return state?.version === 1 && Array.isArray(state.devices) && state.devices.length <= 10
    && state.devices.every((device) => device && uuid.test(device.id) && tokenPattern.test(device.token)
      && ["development", "production"].includes(device.environment) && ["en", "es"].includes(device.language))
    && Array.isArray(state.seen) && state.seen.length <= 1000 && state.seen.every((key) => typeof key === "string")
    && state.observations && typeof state.observations === "object" && !Array.isArray(state.observations)
    && Object.values(state.observations).every((value) => value && typeof value.threadId === "string"
      && typeof value.failed === "boolean" && typeof value.cancelled === "boolean")
    && Array.isArray(state.pending) && state.pending.length <= 100 && state.pending.every((delivery) => delivery
      && uuid.test(delivery.deviceId) && Number.isInteger(delivery.attempt) && delivery.attempt >= 0 && delivery.attempt <= 3
      && Number.isFinite(delivery.nextAt) && delivery.notice && uuid.test(delivery.notice.id)
      && typeof delivery.notice.threadId === "string" && delivery.notice.threadId.length > 0
      && ["completed", "attention"].includes(delivery.notice.kind) && Number.isFinite(delivery.notice.createdAt));
}

export class Notifications {
  private state: NotificationState;
  private timer?: ReturnType<typeof setTimeout>;
  private sending = false;
  private closed = false;
  private failed = false;
  private storageFailed = false;

  constructor(private file: string, private sender?: PushSender) {
    this.state = { version: 1, devices: [], seen: [], observations: {}, pending: [] };
    if (existsSync(file)) {
      const state = JSON.parse(readFileSync(file, "utf8"));
      if (!validState(state)) throw new Error("Invalid saved notification state.");
      this.state = state;
    }
    this.schedule();
  }

  status() { return { available: !!this.sender && !this.failed && !this.storageFailed, configured: !!this.sender }; }

  register(input: Record<string, unknown>) {
    const { deviceId, enabled, token, environment, language } = input;
    if (typeof deviceId !== "string" || !uuid.test(deviceId) || typeof enabled !== "boolean")
      throw new Error("Invalid notification device.");
    if (enabled && (typeof token !== "string" || !tokenPattern.test(token)
      || !["development", "production"].includes(String(environment)) || !["en", "es"].includes(String(language))))
      throw new Error("Invalid notification registration.");
    const id = deviceId.toLowerCase(), normalizedToken = String(token).toLowerCase();
    const devices = this.state.devices.filter((device) => device.id.toLowerCase() !== id && (!enabled || device.token.toLowerCase() !== normalizedToken));
    if (enabled) {
      if (devices.length >= 10) throw new Error("Too many notification devices.");
      devices.push({ id, token: normalizedToken, environment: environment as PushDevice["environment"], language: language as PushDevice["language"] });
    }
    this.state.devices = devices;
    this.state.pending = this.state.pending.filter((delivery) => devices.some((device) => device.id === delivery.deviceId));
    try { this.persist(); } catch (error) { this.storageFailed = true; throw error; }
    this.schedule();
    return this.status();
  }

  observe(observation: NotificationObservation) {
    const previous = this.state.observations[observation.threadId];
    if (JSON.stringify(previous) === JSON.stringify(observation)) return;
    this.state.observations[observation.threadId] = observation;
    const terminal = observation.cancelled ? undefined : observation.failed || observation.phase === "awaiting-transcript"
      ? "attention" : observation.phase === "completed" ? "completed" : undefined;
    const key = terminal && observation.receiptId ? `${observation.threadId}:${observation.receiptId}:${terminal}` : undefined;
    // Seed an existing conversation quietly. Recovered in-flight receipts still produce their terminal transition.
    if (!previous && key) this.state.seen.push(key);
    else if (key) this.publish(key, observation.threadId, terminal!);
    this.persistSafely();
    this.schedule();
  }

  attention(id: string, threadId: string) {
    this.publish(`${threadId}:attention:${id}`, threadId, "attention");
    this.persistSafely();
    this.schedule();
  }

  private publish(key: string, threadId: string, kind: PushNotice["kind"]) {
    if (this.state.seen.includes(key)) return;
    this.state.seen = [...this.state.seen, key].slice(-1000);
    if (!this.sender) return;
    const notice = { id: randomUUID(), threadId, kind, createdAt: Date.now() };
    this.state.pending.push(...this.state.devices.map((device) => ({ deviceId: device.id, notice, attempt: 0, nextAt: Date.now() })));
    this.state.pending = this.state.pending.slice(-100);
  }

  private persist() {
    mkdirSync(dirname(this.file), { recursive: true, mode: 0o700 });
    const temporary = `${this.file}.${process.pid}.tmp`;
    writeFileSync(temporary, JSON.stringify(this.state), { mode: 0o600 });
    renameSync(temporary, this.file);
    this.storageFailed = false;
  }

  private persistSafely() {
    try { this.persist(); }
    catch { this.storageFailed = true; console.error("Dot notifications: state could not be saved."); }
  }

  private schedule() {
    if (this.closed || this.storageFailed || this.sending || !this.sender || !this.state.pending.length) return;
    if (this.timer) clearTimeout(this.timer);
    const nextAt = Math.min(...this.state.pending.map((delivery) => delivery.nextAt));
    this.timer = setTimeout(() => { this.timer = undefined; void this.flush(); }, Math.max(0, nextAt - Date.now()));
    this.timer.unref?.();
  }

  async flush() {
    if (this.closed || this.storageFailed || this.sending || !this.sender) return;
    this.sending = true;
    try {
      for (const delivery of [...this.state.pending]) {
        if (this.closed || this.storageFailed) break;
        if (delivery.nextAt > Date.now()) continue;
        const device = this.state.devices.find((item) => item.id === delivery.deviceId);
        const expired = Date.now() - delivery.notice.createdAt > 60 * 60_000;
        const result = !device || expired ? "invalid-device" : await this.sender.send(device, delivery.notice).catch(() => "retry" as const);
        if (result === "retry" && delivery.attempt < 3 && !expired) {
          delivery.attempt++; delivery.nextAt = Date.now() + 30_000 * 2 ** (delivery.attempt - 1);
        } else {
          this.state.pending = this.state.pending.filter((item) => item !== delivery);
          if (result === "invalid-device" && device && !expired) this.state.devices = this.state.devices.filter((item) => item !== device);
          if (result === "unavailable" || result === "retry") this.failed = true;
        }
        this.persistSafely();
      }
    } finally { this.sending = false; this.schedule(); }
  }

  close() { this.closed = true; if (this.timer) clearTimeout(this.timer); this.sender?.close(); }
}
