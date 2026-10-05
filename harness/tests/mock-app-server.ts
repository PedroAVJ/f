import { createInterface } from "node:readline";
import { readFileSync, writeFileSync, existsSync } from "node:fs";

// A test-only child implementing the installed JSON-RPC shapes. No provider or
// live filesystem tools run in protocol tests.
const path = process.argv[2];
const mode = process.argv[3] ?? "complete";
const state: any = existsSync(path) ? JSON.parse(readFileSync(path, "utf8")) : { threads: {}, calls: [], replies: [] };
for (const thread of Object.values(state.threads) as any[]) {
  for (const turn of thread.turns) if (turn.status === "inProgress") turn.status = "interrupted";
}
const save = () => writeFileSync(path, JSON.stringify(state));
const emit = (message: any) => process.stdout.write(JSON.stringify(message) + "\n");
const notify = (method: string, params: any) => emit({ method, params });
save();

createInterface({ input: process.stdin }).on("line", (line) => {
  const message = JSON.parse(line);
  if (!message.method) { state.replies.push(message); save(); return; }
  state.calls.push(message); save();
  const params = message.params ?? {};
  const reply = (result: any) => emit({ id: message.id, result });
  switch (message.method) {
    case "initialize": {
      const wire = JSON.stringify({ id: message.id, result: { userAgent: "mock" } }) + "\n";
      process.stdout.write(wire.slice(0, 9)); setTimeout(() => process.stdout.write(wire.slice(9)), 5);
      break;
    }
    case "initialized": break;
    case "model/list": reply({ data: [{ id: "desktop-alias", model: "canonical-test-model", isDefault: true, hidden: false }], nextCursor: null }); break;
    case "thread/start": {
      const id = `codex-${Object.keys(state.threads).length + 1}`;
      state.threads[id] = { id, status: { type: "idle" }, turns: [] };
      save(); reply({ thread: state.threads[id] }); break;
    }
    case "thread/resume":
    case "thread/read": reply({ thread: state.threads[params.threadId] }); break;
    case "turn/start": {
      const thread = state.threads[params.threadId];
      const turn = { id: `turn-${thread.turns.length + 1}`, status: "inProgress", items: [
        { id: `user-${thread.turns.length + 1}`, type: "userMessage", clientId: params.clientUserMessageId, content: params.input },
      ] };
      thread.turns.push(turn); save(); if (!["timeout", "complete-no-ack"].includes(mode)) reply({ turn });
      notify("turn/started", { threadId: thread.id, turn });
      notify("item/started", { threadId: thread.id, turnId: turn.id, startedAtMs: Date.now(), item: turn.items[0] });
      if (mode === "hold" || mode === "timeout") break;
      if (mode === "approval") emit({ id: "approval-1", method: "item/commandExecution/requestApproval", params: { threadId: thread.id, turnId: turn.id, itemId: "command-1", startedAtMs: Date.now(), command: "touch /forbidden", reason: "Outside workspace" } });
      if (mode === "fail") {
        turn.status = "failed"; (turn as any).error = { message: "Provider unavailable" }; save();
        notify("turn/completed", { threadId: thread.id, turn }); break;
      }
      setTimeout(() => notify("item/agentMessage/delta", { threadId: thread.id, turnId: turn.id, itemId: `assistant-${thread.turns.length}`, delta: "Hello " }), 15);
      setTimeout(() => notify("item/agentMessage/delta", { threadId: thread.id, turnId: turn.id, itemId: `assistant-${thread.turns.length}`, delta: "world" }), 25);
      setTimeout(() => {
        const item = { id: `assistant-${thread.turns.length}`, type: "agentMessage", text: "Hello world" };
        (turn.items as any[]).push(item); turn.status = "completed"; save();
        notify("item/completed", { threadId: thread.id, turnId: turn.id, completedAtMs: Date.now(), item });
        notify("turn/completed", { threadId: thread.id, turn });
      }, 45);
      break;
    }
    case "turn/interrupt": {
      const thread = state.threads[params.threadId];
      const turn = thread.turns.find((t: any) => t.id === params.turnId);
      turn.status = "interrupted"; save(); reply({});
      notify("turn/completed", { threadId: thread.id, turn }); break;
    }
    default: emit({ id: message.id, error: { code: -32601, message: "Mock method unsupported" } });
  }
});
