import { readFileSync } from "node:fs";
import { createPrivateKey, sign, type KeyObject } from "node:crypto";
import { connect, type ClientHttp2Session } from "node:http2";

export type PushDevice = { id: string; token: string; environment: "development" | "production"; language: "en" | "es" };
export type PushNotice = { id: string; threadId: string; kind: "completed" | "attention"; createdAt: number };
export type PushResult = "sent" | "invalid-device" | "retry" | "unavailable";
export interface PushSender { send(device: PushDevice, notice: PushNotice): Promise<PushResult>; close(): void }

export function pushPayload(device: PushDevice, notice: PushNotice) {
  const body = device.language === "es"
    ? notice.kind === "completed" ? "La respuesta de Near está lista." : "Dot necesita tu atención."
    : notice.kind === "completed" ? "Near’s reply is ready." : "Dot needs your attention.";
  return { aps: { alert: { title: "Dot", body }, sound: "default", "thread-id": notice.threadId },
    dot: { eventId: notice.id, threadId: notice.threadId, kind: notice.kind } };
}

export class ApnsSender implements PushSender {
  private key: KeyObject;
  private jwt?: { value: string; createdAt: number };
  private connections = new Map<string, ClientHttp2Session>();

  constructor(private teamId: string, private keyId: string, pem: string) {
    if (!/^[A-Z0-9]{10}$/.test(teamId) || !/^[A-Z0-9]{10}$/.test(keyId)) throw new Error("Invalid APNs identity.");
    this.key = createPrivateKey(pem);
    if (this.key.asymmetricKeyType !== "ec" || this.key.asymmetricKeyDetails?.namedCurve !== "prime256v1")
      throw new Error("APNs requires a P-256 signing key.");
  }

  private authorization(now = Date.now()) {
    if (!this.jwt || now - this.jwt.createdAt >= 50 * 60_000) {
      const header = Buffer.from(JSON.stringify({ alg: "ES256", kid: this.keyId })).toString("base64url");
      const claims = Buffer.from(JSON.stringify({ iss: this.teamId, iat: Math.floor(now / 1000) })).toString("base64url");
      const content = `${header}.${claims}`;
      const signature = sign("sha256", Buffer.from(content), { key: this.key, dsaEncoding: "ieee-p1363" }).toString("base64url");
      this.jwt = { value: `${content}.${signature}`, createdAt: now };
    }
    return this.jwt.value;
  }

  async send(device: PushDevice, notice: PushNotice): Promise<PushResult> {
    const origin = device.environment === "development" ? "https://api.sandbox.push.apple.com" : "https://api.push.apple.com";
    let session = this.connections.get(origin);
    if (!session || session.closed || session.destroyed) {
      session = connect(origin); session.unref();
      session.on("error", () => {}); // Each affected request reports its transport failure below.
      this.connections.set(origin, session);
    }
    try {
      return await new Promise<PushResult>((resolve) => {
        const request = session!.request({ ":method": "POST", ":path": `/3/device/${device.token}`,
          authorization: `bearer ${this.authorization()}`, "apns-topic": "com.pedroavj.opendot.ios",
          "apns-push-type": "alert", "apns-priority": "10", "apns-id": notice.id,
          "apns-collapse-id": notice.id, "apns-expiration": String(Math.floor(notice.createdAt / 1000) + 3600) });
        let status = 0, response = "", settled = false;
        const finish = (result: PushResult) => { if (!settled) { settled = true; resolve(result); } };
        request.on("response", (headers) => { status = Number(headers[":status"]); });
        request.on("data", (chunk) => { if (response.length < 4096) response += chunk.toString(); });
        request.on("error", () => finish("retry"));
        request.on("close", () => finish("retry"));
        request.setTimeout(10_000, () => { finish("retry"); request.close(); });
        request.on("end", () => {
          if (status === 200) return finish("sent");
          let reason: unknown;
          try { reason = JSON.parse(response).reason; } catch { /* An unreadable APNs response is retryable. */ }
          if (status === 410 || ["BadDeviceToken", "DeviceTokenNotForTopic", "Unregistered"].includes(String(reason))) return finish("invalid-device");
          finish(status === 429 || status >= 500 || !status ? "retry" : "unavailable");
        });
        request.end(JSON.stringify(pushPayload(device, notice)));
      });
    } catch { return "retry"; }
  }

  close() { for (const session of this.connections.values()) session.destroy(); this.connections.clear(); }
}

export function configuredPushSender(environment: NodeJS.ProcessEnv = process.env): PushSender | undefined {
  const { DOT_APNS_TEAM_ID: team, DOT_APNS_KEY_ID: key, DOT_APNS_KEY_FILE: file } = environment;
  if (!team && !key && !file) return undefined;
  if (!team || !key || !file) { console.error("Dot notifications: APNs configuration is incomplete."); return undefined; }
  try { return new ApnsSender(team, key, readFileSync(file, "utf8")); }
  catch { console.error("Dot notifications: APNs configuration could not be loaded."); return undefined; }
}
