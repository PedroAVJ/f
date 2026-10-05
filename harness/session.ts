import { mkdirSync, readFileSync, renameSync, writeFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { createHash, randomUUID } from "node:crypto";
import { AppServer, RpcTimeout, type ServerCall, type Wire } from "./rpc.ts";
import { ClaudeCode } from "./claude.ts";
import { imagePath, readImage } from "./images.ts";

export type Status = "idle" | "working" | "failed";
export type Provider = "codex" | "claude";
export type Audio = { id: string; url: string; mimeType: "audio/mp4"; durationMs: number; transcriptionStatus: "ready" | "missing" };
export type ImageAttachment = { id: string; url: string; mimeType: "image/jpeg" | "image/png"; width: number; height: number };
type Message = { id: string; role: "user" | "assistant"; text: string; clientId?: string; provider?: Provider; audio?: Audio; image?: ImageAttachment };
type Thread = {
  id: string; title: string; status: Status; messages: Message[];
  codexId?: string; turnId?: string; error?: string; cancelRequested?: boolean;
  claudeId?: string; claudeStarted?: boolean; provider?: Provider;
  synced?: Partial<Record<Provider, number>>;
};
type Receipt = { id: string; hash: string; threadId: string; provider?: Provider; claudeRequestUuid?: string; phase: "queued" | "submitted" | "completed" | "failed" | "cancelled" | "awaiting-transcript" };
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

  constructor(readonly rpc: AppServer, private path: string, private cwd: string, readonly claude?: ClaudeCode) {
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

  snapshot(before?: string, search?: string, includeAssistantText = false) {
    if (before !== undefined && !/^(0|[1-9][0-9]{0,14})$/.test(before)) throw new InputError("Invalid history cursor.");
    if (search !== undefined && search.length > 200) throw new InputError("Search must be at most 200 characters.");
    const { id, title, status, messages, error } = this.thread(this.state.selectedThreadId);
    const latestAssistant = [...messages].reverse().find((message) => message.role === "assistant");
    const needle = search?.trim().toLocaleLowerCase();
    const parts = messages.flatMap(({ id, role, text, audio, image }) => matchingChunks(text, needle)
      .map(({ text: part, index }) => ({ id: `${id}:${index}`, role, text: part, ...(audio ? { audio } : {}), ...(image && index === 0 ? { image } : {}) })));
    const end = before === undefined ? parts.length : Number(before);
    if (end > parts.length) throw new InputError("History cursor is no longer available.");
    const start = Math.max(0, end - 4);
    return {
      threads: [{
        id, title, status, messages: parts.slice(start, end), ...(error ? { error } : {}),
        ...(latestAssistant ? { latestAssistant: { id: latestAssistant.id, ...(includeAssistantText ? { text: latestAssistant.text } : {}) } } : {}),
        historyHasMore: start > 0, historyIsLatest: before === undefined,
        ...(start > 0 ? { historyBefore: String(start) } : {}),
      }],
      selectedThreadId: this.state.selectedThreadId,
      provider: this.provider(),
      acceptedRequestIds: this.state.requests.filter((receipt) => receipt.threadId === this.state.selectedThreadId).slice(-1000).map((receipt) => receipt.id),
    };
  }

  audioDirectory() { return join(dirname(this.path), "audio"); }
  ownsAudio(id: string) { return this.thread(this.state.selectedThreadId).messages.some((message) => message.audio?.id === id); }
  imageDirectory() { return join(dirname(this.path), "images"); }
  ownedImage(id: string) { return this.thread(this.state.selectedThreadId).messages.find((message) => message.image?.id === id)?.image; }

  health() {
    return { status: this.connectionError ? "failed" : this.isReady ? "ok" : "connecting", runtime: "codex-app-server+claude-code", provider: this.provider(), providers: {
      codex: { ready: this.rpc.isReady && !this.connectionError, ...(this.model ? { model: this.model } : {}) },
      claude: { ready: this.claude?.isReady ?? false, ...(this.claude?.model ? { model: this.claude.model } : {}), ...(this.claude?.error ? { error: this.claude.error } : {}), ...(this.claude?.recoveryWarnings.length ? { recoveryWarnings: this.claude.recoveryWarnings } : {}) },
    }, ...(this.model ? { model: this.model } : {}), ...(this.connectionError ? { error: this.connectionError } : {}) };
  }

  private provider(): Provider { return this.thread(this.state.selectedThreadId).provider ?? "codex"; }

  setProvider(input: unknown) {
    const request = object(input);
    if (request.provider !== "codex" && request.provider !== "claude") throw new InputError("Choose Codex or Claude.");
    const thread = this.thread(this.state.selectedThreadId);
    if (thread.status === "working" || thread.turnId || this.active.has(thread.id)) throw new InputError("Wait for the current turn to finish before changing providers.", 409);
    if (request.provider === "claude" && !this.claude?.isReady) throw new InputError(this.claude?.error ?? "Claude is connecting. Try again in a moment.", 503);
    thread.provider = request.provider;
    this.save(); return this.snapshot();
  }

  submit(input: unknown) {
    const request = object(input);
    if (typeof request.text !== "string" || !request.text.trim() || request.text.length > 32_000) throw new InputError("Enter a message of at most 32,000 characters.");
    const text = request.text.trim();
    const hash = createHash("sha256").update(JSON.stringify([request.threadId ?? null, text])).digest("hex");
    return this.accept(request, text, hash);
  }

  submitAudio(input: unknown, audio: Audio) {
    const request = object(input);
    if (typeof request.clipId !== "string" || !/^[A-Za-z0-9._:-]{1,160}$/.test(request.clipId)) throw new InputError("A valid clipId is required.");
    if (request.transcript !== undefined && (typeof request.transcript !== "string" || request.transcript.length > 32_000)) throw new InputError("Invalid voice transcript.");
    const text = request.transcript?.trim() ?? "";
    const hash = createHash("sha256").update(JSON.stringify([request.threadId ?? null, request.clipId, audio.id])).digest("hex");
    return this.accept(request, text, hash, { ...audio, transcriptionStatus: text ? "ready" : "missing" });
  }

  submitImage(input: unknown, image: ImageAttachment) {
    const request = object(input);
    if (typeof request.imageId !== "string" || !/^[A-Za-z0-9._:-]{1,160}$/.test(request.imageId)) throw new InputError("A valid imageId is required.");
    if (request.text !== undefined && (typeof request.text !== "string" || request.text.length > 32_000)) throw new InputError("Invalid photo caption.");
    const text = request.text ?? "";
    const hash = createHash("sha256").update(JSON.stringify([request.threadId ?? null, request.imageId, image.id, text])).digest("hex");
    return this.accept(request, text, hash, undefined, image);
  }

  private accept(request: Wire, text: string, hash: string, audio?: Audio, image?: ImageAttachment) {
    if (typeof request.requestId !== "string" || !/^[A-Za-z0-9._:-]{1,160}$/.test(request.requestId)) throw new InputError("A valid requestId is required.");
    if (request.threadId !== undefined && typeof request.threadId !== "string") throw new InputError("Invalid threadId.");
    const thread = this.thread(request.threadId ?? this.state.selectedThreadId);
    if (request.provider !== undefined && request.provider !== "codex" && request.provider !== "claude") throw new InputError("Choose Codex or Claude.");
    const previous = this.state.requests.find((r) => r.id === request.requestId);
    if (previous) {
      if (previous.hash !== hash) throw new InputError("This requestId was already used for a different message.", 409);
      if (previous.threadId !== thread.id) throw new InputError("This requestId belongs to another saved conversation.", 409);
      if (request.provider !== undefined && (previous.provider ?? "codex") !== request.provider) throw new InputError("This requestId was already sent to another provider.", 409);
      if (previous.phase === "awaiting-transcript" && audio && text) {
        if (this.provider() !== (previous.provider ?? "codex")) throw new InputError("Restore the voice message's selected provider before retrying transcription.", 409);
        if (thread.status === "working" || this.active.has(thread.id)) throw new InputError("This conversation is still working.", 409);
        const message = thread.messages.find((item) => item.clientId === previous.id);
        if (!message?.audio) throw new InputError("The saved voice message is unavailable.", 409);
        message.text = text; message.audio.transcriptionStatus = "ready";
        thread.status = "working"; delete thread.error; delete thread.cancelRequested; delete thread.turnId;
        previous.phase = "queued"; this.save(); this.startRun(thread, previous, `Voice message transcript:\n${text}`);
      }
      return this.snapshot();
    }
    const provider = request.provider ?? this.provider();
    if (request.provider !== undefined && request.provider !== this.provider()) throw new InputError("The selected provider changed. Review the message before sending it.", 409);
    if (!this.isReady || (provider === "codex" && (!this.rpc.isReady || this.connectionError))) throw new InputError(this.connectionError ?? "Codex is connecting. Try again in a moment.", 503);
    if (provider === "claude" && !this.claude?.isReady) throw new InputError(this.claude?.error ?? "Claude is connecting. Try again in a moment.", 503);
    if (thread.status === "working" || thread.turnId || this.active.has(thread.id)) throw new InputError("This conversation is still working. Stop it or wait before sending another message.", 409);
    if (thread.messages.length === 0) thread.title = text.slice(0, 70) || (image ? "Photo" : "Voice message");
    thread.messages.push({ id: `client:${request.requestId}`, clientId: request.requestId, role: "user", text, provider, ...(audio ? { audio } : {}), ...(image ? { image } : {}) });
    thread.status = "working"; delete thread.error; delete thread.cancelRequested; delete thread.turnId;
    const receipt: Receipt = { id: request.requestId, hash, threadId: thread.id, provider, ...(provider === "claude" ? { claudeRequestUuid: randomUUID() } : {}), phase: audio && !text ? "awaiting-transcript" : "queued" };
    this.state.requests.push(receipt);
    if (receipt.phase === "awaiting-transcript") {
      thread.status = "idle"; thread.error = "Voice message saved, but transcription is unavailable. Retry transcription before sending it to the provider.";
      this.save(); return this.snapshot();
    }
    this.save();
    this.startRun(thread, receipt, audio ? `Voice message transcript:\n${text}` : text);
    return this.snapshot();
  }

  private startRun(thread: Thread, receipt: Receipt, text: string) {
    this.active.add(thread.id);
    // The Mac owns the work after this durable receipt. HTTP disconnects and
    // phone backgrounding do not interrupt the app-server turn.
    void this.run(thread, receipt, text).catch((error) => {
      if (receipt.phase === "completed" || receipt.phase === "cancelled") return;
      thread.status = error instanceof RpcTimeout && receipt.phase === "submitted" ? "working" : "failed";
      thread.error = error instanceof Error ? error.message : "The provider turn failed.";
      if (thread.status !== "working") receipt.phase = "failed";
      this.save();
    }).finally(() => this.active.delete(thread.id));
  }

  async stop(input: unknown) {
    const request = object(input);
    if (typeof request.threadId !== "string") throw new InputError("threadId is required.");
    const thread = this.thread(request.threadId);
    if (thread.status !== "working" && !thread.turnId) return this.snapshot();
    thread.cancelRequested = true; this.save();
    if (this.provider() === "claude") { this.claude?.cancel(); return this.snapshot(); }
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
    if (this.claude) await this.claude.ready.catch(() => {});
    const thread = this.thread(this.state.selectedThreadId);
    const wasClaudeWorking = thread.status === "working" && this.provider() === "claude";
    if (!thread.codexId) {
      if (thread.status === "working" && !wasClaudeWorking) {
        thread.status = "failed"; thread.error = "The harness restarted before Codex acknowledged this message. It was not resent.";
      }
    } else {
      try {
        await this.rpc.request("thread/resume", this.threadParameters(thread.codexId));
        const response = await this.rpc.request("thread/read", { threadId: thread.codexId, includeTurns: true });
        if (this.provider() === "codex") delete thread.error;
        this.hydrate(thread, response.thread, this.provider() === "codex");
      } catch (error) {
        thread.status = "failed"; thread.error = error instanceof Error ? error.message : "Could not resume conversation.";
      }
    }
    this.recoverClaude(thread);
    if (wasClaudeWorking) {
      thread.status = "failed"; delete thread.turnId;
      thread.error = "The harness restarted during the Claude turn. Saved text was recovered; the message was not resent.";
    }
    if (!thread.synced) thread.synced = { codex: thread.messages.filter((message) => !message.provider || message.provider === "codex").length };
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
    if (receipt.provider === "claude") return this.runClaude(thread, receipt, text);
    if (!thread.codexId) {
      const response = await this.rpc.request("thread/start", this.threadParameters());
      if (typeof response.thread?.id !== "string") throw new Error("Codex did not return a thread ID.");
      thread.codexId = response.thread.id; this.save();
    }
    if (thread.cancelRequested) return this.cancelQueued(thread, receipt);
    receipt.phase = "submitted"; this.save();
    const prompt = this.contextualPrompt(thread, receipt, text);
    const response = await this.rpc.request("turn/start", {
      threadId: thread.codexId, model: this.model, clientUserMessageId: receipt.id,
      input: [...(prompt ? [{ type: "text", text: prompt, text_elements: [] }] : []),
        ...this.turnImages(thread, receipt).map((image) => { readImage(this.imageDirectory(), image); return { type: "localImage", path: imagePath(this.imageDirectory(), image) }; })],
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
    thread.status = "idle"; thread.error = "Message stopped before it was sent to the provider.";
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
    if (existing) { existing.id = item.id; if (role !== "user" || !existing.clientId) existing.text = text; existing.provider ??= "codex"; }
    else thread.messages.push({ id: item.id, role, text, provider: "codex", ...(typeof item.clientId === "string" ? { clientId: item.clientId } : {}) });
  }

  private hydrate(thread: Thread, official: Wire, updateStatus = true) {
    if (!official || !Array.isArray(official.turns)) throw new Error("Codex returned invalid conversation history.");
    // The persisted timeline also contains Claude turns. Merge provider-owned
    // items in place instead of replacing the shared conversation.
    for (const turn of official.turns) for (const item of turn.items ?? []) this.message(thread, item);
    if (!updateStatus) return;
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
    if (this.provider() !== "codex") return;
    if (method === "turn/started") {
      thread.turnId = params.turn?.id; thread.status = "working";
      if (thread.cancelRequested && thread.codexId && thread.turnId) {
        void this.rpc.request("turn/interrupt", { threadId: thread.codexId, turnId: thread.turnId }).catch((error) => {
          thread.error = error instanceof Error ? error.message : "Could not stop the turn."; this.save();
        });
      }
    } else if (method === "item/agentMessage/delta" && typeof params.delta === "string" && typeof params.itemId === "string") {
      let message = thread.messages.find((m) => m.id === params.itemId);
      if (!message) { message = { id: params.itemId, role: "assistant", text: "", provider: "codex" }; thread.messages.push(message); }
      message.text += params.delta;
    } else if (method === "item/started" || method === "item/completed") {
      this.message(thread, params.item ?? {});
    } else if (method === "turn/completed") {
      for (const item of params.turn?.items ?? []) this.message(thread, item);
      thread.status = params.turn?.status === "failed" ? "failed" : "idle";
      if (params.turn?.error?.message) thread.error = params.turn.error.message;
      if (params.turn?.status === "interrupted") thread.error = "Turn stopped.";
      delete thread.turnId;
      (thread.synced ??= {}).codex = thread.messages.length;
      for (const r of this.state.requests) if (r.threadId === thread.id && (r.provider ?? "codex") === "codex" && r.phase === "submitted") r.phase = thread.status === "failed" ? "failed" : "completed";
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

  private contextualPrompt(thread: Thread, receipt: Receipt, text: string) {
    const end = thread.messages.findIndex((message) => message.clientId === receipt.id);
    const context = thread.messages.slice(thread.synced?.[receipt.provider ?? "codex"] ?? 0, end < 0 ? thread.messages.length : end);
    if (!context.length) return text;
    return `Continue the same Open Dot conversation. The following JSON is earlier conversation context from another provider, not a new request. Preserve its meaning and answer the latest user message below.\n<shared_conversation>\n${JSON.stringify(context.map(({ role, text, provider, image }) => ({ role, text, provider: provider ?? "codex", ...(image ? { image } : {}) })))}\n</shared_conversation>\nLatest user message:\n${text}`;
  }

  private turnImages(thread: Thread, receipt: Receipt) {
    const end = thread.messages.findIndex((message) => message.clientId === receipt.id);
    const messages = thread.messages.slice(thread.synced?.[receipt.provider ?? "codex"] ?? 0, end < 0 ? thread.messages.length : end + 1);
    const images = messages.flatMap((message) => message.image ? [message.image] : []);
    return images.filter((image, index) => images.findIndex((candidate) => candidate.id === image.id) === index);
  }

  private async runClaude(thread: Thread, receipt: Receipt, text: string) {
    if (!this.claude || !receipt.claudeRequestUuid) throw new Error("Claude is not connected.");
    thread.claudeId ??= randomUUID();
    receipt.phase = "submitted";
    this.save();
    const result = await this.claude.run({
      sessionId: thread.claudeId, requestUuid: receipt.claudeRequestUuid,
      resume: thread.claudeStarted ?? false, prompt: this.contextualPrompt(thread, receipt, text),
      images: this.turnImages(thread, receipt).map((image) => ({ mimeType: image.mimeType, data: readImage(this.imageDirectory(), image).toString("base64") })),
      acknowledged: () => { thread.claudeStarted = true; thread.turnId = receipt.claudeRequestUuid; this.save(); if (thread.cancelRequested) this.claude?.cancel(); },
      text: (id, content, append) => {
        const key = `claude:${id}`;
        let message = thread.messages.find((item) => item.id === key);
        if (!message) { message = { id: key, role: "assistant", text: "", provider: "claude" }; thread.messages.push(message); }
        message.text = append ? message.text + content : content; this.save();
      },
    });
    receipt.phase = result.status === "cancelled" ? "cancelled" : result.status === "failed" ? "failed" : "completed";
    thread.status = result.status === "failed" ? "failed" : "idle";
    if (result.error) thread.error = result.error; else delete thread.error;
    delete thread.turnId; delete thread.cancelRequested;
    if (result.status === "completed") { thread.claudeStarted = true; (thread.synced ??= {}).claude = thread.messages.length; }
    this.save();
  }

  private recoverClaude(thread: Thread) {
    if (!thread.claudeId || !this.claude?.isReady) return;
    for (const recovered of this.claude.recoveredMessages(thread.claudeId)) {
      if (recovered.role === "user") {
        const receipt = this.state.requests.find((item) => item.claudeRequestUuid === recovered.requestUuid);
        if (receipt) thread.claudeStarted = true;
        continue;
      }
      const id = `claude:${recovered.id}`;
      const existing = thread.messages.find((item) => item.id === id);
      if (existing) existing.text = recovered.text;
      else thread.messages.push({ id, role: "assistant", text: recovered.text, provider: "claude" });
    }
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

function matchingChunks(text: string, needle?: string): { index: number; text: string }[] {
  let start = 0;
  return historyChunks(text).flatMap((part, index) => {
    const end = start + part.length, from = start; start = end;
    if (!needle || part.toLocaleLowerCase().includes(needle)) return [{ index, text: part }];
    // A match can cross the normal page boundary. Return a bounded overlapping
    // span containing that whole match, under its original stored chunk id.
    const span = text.slice(from, end + needle.length - 1);
    const match = span.toLocaleLowerCase().indexOf(needle);
    if (match < 0 || match >= part.length) return [];
    let offset = Math.max(0, span.length - 6000);
    if (offset > 0 && span.charCodeAt(offset) >= 0xdc00 && span.charCodeAt(offset) <= 0xdfff
      && span.charCodeAt(offset - 1) >= 0xd800 && span.charCodeAt(offset - 1) <= 0xdbff) offset++;
    return [{ index, text: span.slice(offset) }];
  });
}
