# HyperTUI render target and query-only programs

Isolated implementation dated 2026-10-06. No original worker was stopped, no global harness settings were edited, and no production service was restarted.

## Implemented

- `bend2/std/F/hypertui/ui.bend` annotates ordinary F UI nodes. `render.ts` walks the same primitive tree used by the human renderer; it emits interleaved MCP text/image blocks, URI links, fenced source and current-page action schemas. The fixture's human renderer emits the same image node.
- `host.ts` serves a Bend application's `s`, `hypertui_page`, and `hypertui_action`. Two stable MCP tools navigate and invoke typed page-scoped mutations. Arguments are validated, disabled/stale actions are rejected, successful mutations invalidate the page and return a redirect URI. There are no change notifications, diffs, cursors or realtime streams.
- `gateway.ts` renders installed read-only tool results through `program.bend`. It preserves upstream structured data as fenced JSON and images as real MCP image blocks. Unknown tools and mutation/mixed entries cannot execute through this query route. Native mutation/mixed tools remain exposed.
- Workspace browsing is scoped under `hypertui://files/`. Explicit absolute file paths, `file:///` URIs, and `hypertui://file/?path=ENCODED_ABSOLUTE_PATH` additionally read bounded regular files using ordinary OS permissions, without changing permissions or sandbox settings; they do not list absolute directories. Within those routes: directories have URI links, source is fenced, images are inline, video has metadata/frame/seek links, audio has waveform/transcript-sidecar/seek links, and PDFs have rendered pages/page links. Symlink escapes are rejected. Media subprocesses have bounded time, output, input size and threads.
- `launch.ts` applies per-process policies and registers the gateway. Open Dot's Claude speaker, Codex fallback and background-worker launcher paths use it. Worker lists/status are authenticated query pages; start/submit/stop/present_ui remain native mutations. Existing remote-provider registration is retained separately.
- The isolated remote HyperTUI adapter accepts interleaved content and typed action invocation with explicit redirects. It does not emit tool-list-change notifications.

## Inventories and verified policy

[CLASSIFIED-TOOLS.md](CLASSIFIED-TOOLS.md) lists every exact name grouped by harness and class, plus Open Dot application-local tools. `catalog.json` contains every enumerated installed MCP tool: 646 total, comprising 351 query, 278 mutation and 17 mixed entries. Provenance, descriptions, input schemas, classification reason, policy key, retained exposure and replacement URI are included. These are sanitized descriptors, not transport configurations or credentials.

The Codex portion has 624 tools: 346 queries, including 304 connector methods and 42 plugin-server methods. The Claude Chrome portion has 22 tools: 5 queries and 17 mutation/mixed tools. The real owned Claude speaker has no built-in tools (`--tools ''`) as before this change. Native Codex `view_image` and web search are additionally replaced by file-image pages and `hypertui://tools/codex/codex_apps/search_service.web_run` respectively. Shell/general execution capabilities remain native.

`effective-policy.json` is a sanitized readback of the installed Codex 0.157.1 effective config. All 304 connector queries are disabled; exact per-server allowlists retain mutation/mixed tools. Plugin-scoped override syntax was ignored by this installed version, so the launcher copies each server's existing transport at runtime and applies supported top-level allowlists. Transport values are never written to these evidence artifacts. CLI dotted keys must be unquoted; quoted key segments were parsed literally and corrected before handoff.

`active-tools.json` classifies 595 public tool names exposed to the already-running worker/platform, with provenance and explicit immutable-active-session status. That current manifest cannot be retroactively edited. Internal bookkeeping is excluded; the artifact does not expose it or create page adapters for it.

## Proof

- `vision-proof.json`: real Claude and Codex both correctly described a randomized unlabeled image and text immediately before/after it through the direct F MCP renderer. Claude session `8bccacc4-9cf4-4522-af47-3ee5702be35b`; Codex thread `01a11229-3a48-7800-93ba-cfa608fa9670`.
- Real filtered Claude gateway session `8f45fd5b-9a20-4836-9803-ffbf3a0a2f86` saw all 17 retained Chrome mutation/mixed tools and the gateway, none of the five pure Chrome queries, and correctly perceived the gateway image. Its exact exposed tool list and answer are retained in `vision-proof.json`.
- Codex gateway startup is healthy: app-server enumerates hyperTUI and its URI schema with `toolsError:null`. Effective policy is verified, but two real model turns did not discover/invoke it. A supported `code_mode_host=false` trial did not help and was reverted. Model-level routing remains unverified; successful direct Codex image perception is not claimed as successful filtered-gateway use.
- `query-reroute.json` records an actual installed connector query returned through an F page, including its structured result. A separate recording-service query surfaced its real upstream bootstrap timeout without fabricating data.
- Eight F tests / 38 assertions passed: shared tree and image bytes/order; typed mutations, redirects and stale rejection; fences; path/schema denial; query-only dispatch; harness allowlists; real video/audio decoder output; explicit outside-workspace image bytes through absolute path and both file URI forms. A real PDF decoder check produced an inline rendered page.
- Open Dot's worker, speaker, fallback and worker-server modules compile; 60 existing/new Boolean checks across server_hypertui, server_provider and server_workers passed. Tests whose old contract exposed list/status or fixed the old launcher argument index were updated for the requested contract.
- Remote adapter: 24 protocol/state checks passed under the new no-push, rich-content and stable-action contract.
- Anti-slop deterministic scan: seven transport/renderer TypeScript files, no findings. Manual review checked boundaries, retained mutations, authorization, bounded media and error propagation. No subagents were used.

## Remaining boundaries

1. DOUBT: filtered Codex gateway model discovery remains unverified despite healthy MCP startup and verified config. The tests do not establish platform incapability. Exact commands, prompts and sanitized response evidence are in `proof-commands.json` and `vision-proof.json`. Do not claim both filtered harnesses are fully activated.
2. Immutable current-session platform query capabilities cannot be removed by repository edits. Future owned launches are configured, not retroactive changes to this conversation.
3. Audio transcripts are displayed when a `.txt` sidecar exists. Missing transcripts are explicitly reported; automatic transcription is not implemented here.
4. Unavailable/auth-failing upstream plugins remain unavailable. No credential or permission changes were made. An inventory is not proof that every upstream backend is healthy.
5. These sources are isolated, not deployed. Existing runtime JSON must be regenerated from the new configuration before launch; old captured runtime configs lack the query-launcher fields. Remote providers must return mutation redirects before deploying the changed remote adapter.
6. F incorporates the existing original-checkout tail-recursive `String.split` dependency as a separate commit. Parent's native F commits and worker attachment relay work must be merged, not overwritten.

## Isolated paths

- F: `/Users/pedroantoniovillanuevajuarez/Developer/f-hypertui-20261006`
- Open Dot: `/Users/pedroantoniovillanuevajuarez/Developer/hypertui-target-20261006/open-dot`
- Remote adapter: `/Users/pedroantoniovillanuevajuarez/Developer/hypertui-target-20261006/hypertui`

Open Dot's baseline snapshot `34785cf` preserves the original tracked/untracked Bend overlay and is separate from this feature change. Original source trees were not modified.
