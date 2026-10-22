# Compact Claude bridge

Status: tested candidate, not activated.

## Activation

`gateway.runtime.ts` is the exact live wrapper replacement, with its original absolute imports preserved. `gateway.runtime.patch` is its exact review diff. `hashes.json` pins live originals and candidates; `live_core.before.ts` and `live_wrapper.before.ts` are reversible backups. Replace the pinned live core with candidate_core, then the pinned live wrapper with candidate_runtime_wrapper, atomically per file. No front-runtime/gateway config, account, model, provider, access scope, source-owned Bend file, launcher, or app restart is required. New bridge processes load the fix; existing processes retain their in-memory version until they finish.

The default core mode remains the legacy Codex result contract. Claude opts in via its wrapper. Do not claim all Codex page output is compact. Exact current-page schemas are served through generation-bound MCP tools/list entries; tools/list_changed is advertised and emitted. Generic hyperTUI_action remains callable using the visible compact argument signatures. Typed stale action calls fail; underlying remote generation-bound calls are preserved.

## Verification

24 gateway tests passed / 176 expectations. Exact conversation-wrapper stdio tests cover Markdown/images/metadata, full protocol schemas without appending schemas to results, parameter validation, stale tools, generic actions, redirect readback, action invalidation, list-change notification ordering, conversation archive search, local-access exclusions, and presenter forwarding. Existing default-mode tests all pass. Bun bundle build succeeded; strict TypeScript checking unavailable because no local tsc executable exists (bunx --no-install confirmed). Scanner and git diff --check passed.

Actual live read-only remote queries through the candidate core: /repos response 13,251 -> 4,162 bytes; F repository 23,970 -> 6,283 bytes. Both candidate pages have one raw Markdown page plus one compact action-signature block, zero inputSchema copies, and uri/generation metadata retained without markdown. Details in ../compact-live-probe.json. These probes do not demonstrate deployed Claude behavior or Claude's dynamic-tools refresh; verify after activation with the actual live wrapper and a fresh Claude request. No remote mutation was used for measurement.
