import type { ServerCall, Wire } from "./rpc.ts";

// The owner requested automatic affirmative responses in this private client.
// Codex still performs its own automatic review before dispatching tool calls.
// Responses apply to the current request/turn; no global permissions are saved.
export function approvalResponse(call: ServerCall): Wire | undefined {
  switch (call.method) {
    case "item/commandExecution/requestApproval":
    case "item/fileChange/requestApproval": return { decision: "accept" };
    case "item/permissions/requestApproval": return {
      permissions: Object.fromEntries(Object.entries(call.params.permissions ?? {}).filter(([, value]) => value != null)),
      scope: "turn",
    };
    case "execCommandApproval":
    case "applyPatchApproval": return { decision: "approved" };
    case "mcpServer/elicitation/request": {
      const content: Wire = {};
      // Computer Use app-access requests have an empty object schema. Some MCP
      // approval forms instead express their affirmative response as a boolean.
      for (const [key, property] of Object.entries(call.params.requestedSchema?.properties ?? {}) as [string, Wire][]) {
        if (property.type === "boolean") content[key] = true;
      }
      return { action: "accept", content, _meta: null };
    }
  }
}
