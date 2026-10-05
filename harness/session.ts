import { mkdirSync, readFileSync, renameSync, writeFileSync, existsSync } from "node:fs";
import { dirname } from "node:path";
import { createHash, randomUUID } from "node:crypto";
import { AppServer, RpcTimeout, type ServerCall, type Wire } from "./rpc.ts";

export type Status = "idle" | "working" | "failed";
type Message = { id: string; role: "user" | "assistant"; text: string; clientId?: string };
type Thread = {
  id: string; title: string; status: Status; messages: Message[];
  codexId?: string; turnId?: string; error?: string; cancelRequested?: boolean;
};
type Receipt = { id: string; hash: string; threadId: string; phase: "queued" | "submitted" | "completed" | "failed" | "cancelled" };
type State = { version: 1; threads: Thread[]; selectedThreadId: string; requests: Receipt[] };

export class InputError extends Error {
  constructor(message: string, readonly status = 400) { super(message); }
}

export class Sessions {
  readonly ready: Promise<void>;
  private state: State;
  private active = new Set<string>();
  private connectionError?: string;
  private model?: string;
  isReady = false;

  constructor(readonly rpc: AppServer, private path: string, private cwd: string) {
    if (existsSync(path)) {
      const state = JSON.parse(readFileSync(path, "utf8"));
      if (state.version !== 1 || !Array.isArray(state.threads) || !Array.isArray(state.requests)
        || !state.threads.every((t: Thread) => typeof t.id === "string" && Array.isArray(t.messages))
        || typeof state.selectedThreadId !== "string" || !state.threads.some((t: Thread) => t.id === state.selectedThreadId)) {
        throw new Error("Open Dot session file is invalid; preserve it before recovery.");
      }
      this.state = state;
    } else {
      const thread = this.emptyThread();
      this.state = { version: 1, threads: [thread], selectedThreadId: thread.id, requests: [] };
      this.save();
    }
    rpc.onNotification = (method, params) => this.notification(method, params);
    rpc.onRequest = (call) => this.serverRequest(call);
    rpc.onFailure = (error) => this.failConnection(error.message);
    this.ready = this.recover();
    void this.ready.catch((error) => this.failConnection(error instanceof Error ? error.message : "Codex could not reconnect."));
  }

  snapshot(before?: string) {
    if (before !== undefined && !/^(0|[1-9][0-9]{0,14})$/.test(before)) throw new InputError("Invalid history cursor.");
    const { id, title, status, messages, error } = this.thread(this.state.selectedThreadId);
    const parts = messages.flatMap(({ role, text }) => historyChunks(text).map((part) => ({ role, text: part })));
    const end = before === undefined ? parts.length : Number(before);
    if (end > parts.length) throw new InputError("History cursor is no longer available.");
    const start = Math.max(0, end - 4);
    return {
      threads: [{
        id, title, status, messages: parts.slice(start, end), ...(error ? { error } : {}),
        historyHasMore: start > 0, historyIsLatest: before === undefined,
        ...(start > 0 ? { historyBefore: String(start) } : {}),
      }],
      selectedThreadId: this.state.selectedThreadId,
      acceptedRequestIds: this.state.requests.filter((receipt) => receipt.threadId === this.state.selectedThreadId).slice(-1000).map((receipt) => receipt.id),
    };
  }

  health() {
    return { status: this.connectionError ? "failed" : this.isReady ? "ok" : "connecting", runtime: "codex-app-server", ...(this.model ? { model: this.model } : {}), ...(this.connectionError ? { error: this.connectionError } : {}) };
  }

  submit(input: unknown) {
    const request = object(input);
    if (typeof request.text !== "string" || !request.text.trim() || request.text.length > 32_000) throw new InputError("Enter a message of at most 32,000 characters.");
    if (typeof request.requestId !== "string" || !/^[A-Za-z0-9._:-]{1,160}$/.test(request.requestId)) throw new InputError("A valid requestId is required.");
    if (request.threadId !== undefined && typeof request.threadId !== "string") throw new InputError("Invalid threadId.");
    const thread = this.thread(request.threadId ?? this.state.selectedThreadId);
    const text = request.text.trim();
    const hash = createHash("sha256").update(JSON.stringify([request.threadId ?? null, text])).digest("hex");
    const previous = this.state.requests.find((r) => r.id === request.requestId);
    if (previous) {
      if (previous.hash !== hash) throw new InputError("This requestId was already used for a different message.", 409);
      if (previous.threadId !== thread.id) throw new InputError("This requestId belongs to another saved conversation.", 409);
      return this.snapshot();
    }
    if (!this.isReady || !this.rpc.isReady || this.connectionError) throw new InputError(this.connectionError ?? "Codex is connecting. Try again in a moment.", 503);
    if (thread.status === "working" || thread.turnId || this.active.has(thread.id)) throw new InputError("This conversation is still working. Stop it or wait before sending another message.", 409);
    if (thread.messages.length === 0) thread.title = text.slice(0, 70);
    thread.messages.push({ id: `client:${request.requestId}`, clientId: request.requestId, role: "user", text });
    thread.status = "working"; delete thread.error; delete thread.cancelRequested; delete thread.turnId;
    const receipt: Receipt = { id: request.requestId, hash, threadId: thread.id, phase: "queued" };
    this.state.requests.push(receipt);
    this.save();
    this.active.add(thread.id);
    // The Mac owns the work after this durable receipt. HTTP disconnects and
    // phone backgrounding do not interrupt the app-server turn.
    void this.run(thread, receipt, text).catch((error) => {
      if (receipt.phase === "completed" || receipt.phase === "cancelled") return;
      thread.status = error instanceof RpcTimeout && receipt.phase === "submitted" ? "working" : "failed";
      thread.error = error instanceof Error ? error.message : "Codex turn failed.";
      if (thread.status !== "working") receipt.phase = "failed";
      this.save();
    }).finally(() => this.active.delete(thread.id));
    return this.snapshot();
  }

  async stop(input: unknown) {
    const request = object(input);
    if (typeof request.threadId !== "string") throw new InputError("threadId is required.");
    const thread = this.thread(request.threadId);
    if (thread.status !== "working" && !thread.turnId) return this.snapshot();
    thread.cancelRequested = true; this.save();
    if (thread.codexId && thread.turnId) {
      await this.rpc.request("turn/interrupt", { threadId: thread.codexId, turnId: thread.turnId });
    }
    return this.snapshot();
  }

  private emptyThread(): Thread { return { id: randomUUID(), title: "Conversación", status: "idle", messages: [] }; }
  private thread(id: string): Thread {
    if (id !== this.state.selectedThreadId) throw new InputError("Only the ongoing conversation is available.", 404);
    const thread = this.state.threads.find((t) => t.id === id);
    if (!thread) throw new InputError("Conversation not found.", 404);
    return thread;
  }
  private protocolThread(id: unknown) {
    const thread = this.thread(this.state.selectedThreadId);
    return thread.codexId && thread.codexId === id ? thread : undefined;
  }

  private save() {
    mkdirSync(dirname(this.path), { recursive: true, mode: 0o700 });
    const temporary = `${this.path}.${process.pid}.tmp`;
    writeFileSync(temporary, JSON.stringify(this.state), { mode: 0o600 });
    renameSync(temporary, this.path);
  }

  private async recover() {
    await this.rpc.ready;
    await this.selectModel();
    const thread = this.thread(this.state.selectedThreadId);
    if (!thread.codexId) {
      if (thread.status === "working") {
        thread.status = "failed"; thread.error = "The harness restarted before Codex acknowledged this message. It was not resent.";
      }
    } else {
      try {
        await this.rpc.request("thread/resume", this.threadParameters(thread.codexId));
        const response = await this.rpc.request("thread/read", { threadId: thread.codexId, includeTurns: true });
        delete thread.error;
        this.hydrate(thread, response.thread);
      } catch (error) {
        thread.status = "failed"; thread.error = error instanceof Error ? error.message : "Could not resume conversation.";
      }
    }
    // Persisted receipts remain deduplicated across harness restarts. Never
    // automatically replay a message whose submission outcome is uncertain.
    for (const receipt of this.state.requests) {
      if (receipt.threadId !== this.state.selectedThreadId) continue;
      if (receipt.phase === "queued" || receipt.phase === "submitted") {
        const thread = this.thread(receipt.threadId);
        if (thread.status !== "working") receipt.phase = "failed";
      }
    }
    this.save();
    this.isReady = true;
  }

  private threadParameters(threadId?: string) {
    return { ...(threadId ? { threadId } : {}), model: this.model, cwd: this.cwd, sandbox: "workspace-write", approvalPolicy: "on-request", approvalsReviewer: "auto_review" };
  }

  private async selectModel() {
    let cursor: string | undefined;
    const seen = new Set<string>();
    for (let page = 0; page < 20; page++) {
      const catalog = await this.rpc.request("model/list", { includeHidden: false, limit: 100, ...(cursor ? { cursor } : {}) });
      if (!Array.isArray(catalog.data)) throw new Error("Codex returned an invalid model catalog.");
      const model = catalog.data.find((m: Wire) => m.isDefault === true && m.hidden !== true && typeof m.model === "string" && m.model.length > 0);
      if (model) { this.model = model.model; return; }
      if (typeof catalog.nextCursor !== "string" || !catalog.nextCursor || seen.has(catalog.nextCursor)) break;
      cursor = catalog.nextCursor; seen.add(cursor);
    }
    throw new Error("Codex did not provide an available default model. Open Dot did not change your global model configuration.");
  }

  private async run(thread: Thread, receipt: Receipt, text: string) {
    await this.ready;
    if (thread.cancelRequested) return this.cancelQueued(thread, receipt);
    if (!thread.codexId) {
      const response = await this.rpc.request("thread/start", this.threadParameters());
      if (typeof response.thread?.id !== "string") throw new Error("Codex did not return a thread ID.");
      thread.codexId = response.thread.id; this.save();
    }
    if (thread.cancelRequested) return this.cancelQueued(thread, receipt);
    receipt.phase = "submitted"; this.save();
    const response = await this.rpc.request("turn/start", {
      threadId: thread.codexId, model: this.model, clientUserMessageId: receipt.id,
      input: [{ type: "text", text, text_elements: [] }],
    });
    if (typeof response.turn?.id !== "string") throw new Error("Codex did not acknowledge a turn ID. The message was not resent.");
    // Notifications can complete the turn before its RPC response arrives.
    if (receipt.phase === "submitted") thread.turnId = response.turn.id;
    this.save();
    if (thread.cancelRequested && receipt.phase === "submitted") {
      await this.rpc.request("turn/interrupt", { threadId: thread.codexId, turnId: response.turn.id });
    }
  }

  private cancelQueued(thread: Thread, receipt: Receipt) {
    thread.status = "idle"; thread.error = "Message stopped before it was sent to Codex.";
    receipt.phase = "cancelled"; this.save();
  }

  private message(thread: Thread, item: Wire) {
    if (typeof item.id !== "string") return;
    let role: "user" | "assistant", text: string;
    if (item.type === "agentMessage" && typeof item.text === "string") { role = "assistant"; text = item.text; }
    else if (item.type === "userMessage" && Array.isArray(item.content)) {
      role = "user"; text = item.content.filter((c: Wire) => c.type === "text" && typeof c.text === "string").map((c: Wire) => c.text).join("\n");
    } else return;
    const existing = thread.messages.find((m) => m.id === item.id || (typeof item.clientId === "string" && m.clientId === item.clientId));
    if (existing) { existing.id = item.id; existing.text = text; }
    else thread.messages.push({ id: item.id, role, text, ...(typeof item.clientId === "string" ? { clientId: item.clientId } : {}) });
  }

  private hydrate(thread: Thread, official: Wire) {
    if (!official || !Array.isArray(official.turns)) throw new Error("Codex returned invalid conversation history.");
    const pending = thread.messages.filter((m) => m.id.startsWith("client:"));
    thread.messages = [];
    for (const turn of official.turns) for (const item of turn.items ?? []) this.message(thread, item);
    for (const message of pending) {
      if (!thread.messages.some((m) => m.clientId === message.clientId)) thread.messages.push(message);
    }
    const last = official.turns.at(-1);
    if (last?.status === "inProgress") { thread.status = "working"; thread.turnId = last.id; }
    else if (last?.status === "failed") { thread.status = "failed"; thread.error = last.error?.message ?? "Codex turn failed."; delete thread.turnId; }
    else {
      const wasWorking = thread.status === "working";
      thread.status = "idle"; delete thread.turnId;
      if (wasWorking && last?.status !== "completed") thread.error = "The previous turn was interrupted when the harness restarted. It was not resent.";
    }
  }

  private notification(method: string, params: Wire) {
    const thread = this.protocolThread(params.threadId);
    if (!thread) return;
    if (method === "turn/started") {
      thread.turnId = params.turn?.id; thread.status = "working";
      if (thread.cancelRequested && thread.codexId && thread.turnId) {
        void this.rpc.request("turn/interrupt", { threadId: thread.codexId, turnId: thread.turnId }).catch((error) => {
          thread.error = error instanceof Error ? error.message : "Could not stop the turn."; this.save();
        });
      }
    } else if (method === "item/agentMessage/delta" && typeof params.delta === "string" && typeof params.itemId === "string") {
      let message = thread.messages.find((m) => m.id === params.itemId);
      if (!message) { message = { id: params.itemId, role: "assistant", text: "" }; thread.messages.push(message); }
      message.text += params.delta;
    } else if (method === "item/started" || method === "item/completed") {
      this.message(thread, params.item ?? {});
    } else if (method === "turn/completed") {
      for (const item of params.turn?.items ?? []) this.message(thread, item);
      thread.status = params.turn?.status === "failed" ? "failed" : "idle";
      if (params.turn?.error?.message) thread.error = params.turn.error.message;
      if (params.turn?.status === "interrupted") thread.error = "Turn stopped.";
      delete thread.turnId;
      for (const r of this.state.requests) if (r.threadId === thread.id && r.phase === "submitted") r.phase = thread.status === "failed" ? "failed" : "completed";
    } else if (method === "error") {
      thread.error = String(params.error?.message ?? "Codex reported an error.");
      if (!params.willRetry) thread.status = "failed";
    } else if (method === "thread/status/changed" && params.status?.type === "systemError") {
      thread.status = "failed"; thread.error = "Codex reported a conversation error.";
    } else return;
    this.save();
  }

  private serverRequest(call: ServerCall) {
    const thread = this.protocolThread(call.params.threadId);
    // Automatic review is enabled. If an action still needs interactive input,
    // decline it rather than granting invisible permissions from a phone client.
    if (thread) { thread.error = `Codex requested ${call.method}. Open Dot declined because this mobile client cannot review that request yet.`; this.save(); }
    switch (call.method) {
      case "item/commandExecution/requestApproval":
      case "item/fileChange/requestApproval": this.rpc.respond(call.id, { decision: "decline" }); break;
      case "item/permissions/requestApproval": this.rpc.respond(call.id, { permissions: {}, scope: "turn" }); break;
      case "item/tool/requestUserInput": this.rpc.respond(call.id, { answers: {} }); break;
      case "mcpServer/elicitation/request": this.rpc.respond(call.id, { action: "decline" }); break;
      case "execCommandApproval":
      case "applyPatchApproval": this.rpc.respond(call.id, { decision: "denied" }); break;
      default: this.rpc.reject(call.id, "Open Dot does not support this interactive request.");
    }
  }

  private failConnection(message: string) {
    this.isReady = false;
    this.connectionError = message;
    const thread = this.thread(this.state.selectedThreadId);
    thread.status = "failed"; thread.error = message;
    this.save();
  }
}

export function object(value: unknown): Wire {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new InputError("Request must be a JSON object.");
  return value as Wire;
}

function historyChunks(text: string): string[] {
  if (!text) return [""];
  const chunks: string[] = [];
  for (let start = 0; start < text.length;) {
    let end = Math.min(start + 6000, text.length);
    if (end < text.length && text.charCodeAt(end - 1) >= 0xd800 && text.charCodeAt(end - 1) <= 0xdbff
      && text.charCodeAt(end) >= 0xdc00 && text.charCodeAt(end) <= 0xdfff) end--;
    chunks.push(text.slice(start, end)); start = end;
  }
  return chunks;
}
