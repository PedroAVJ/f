# Framework preludes

Import the parts you use explicitly:

```bend
import F
import State
import V
```

F supplies component functions, Shape/Layout trees and function transitions.
State supplies component data, AI stream/request data and Dot session records.
V supplies release/deployment declarations and plan/check functions, and
the verbs over a `System{releases, deployments}`. A release is one thing
released: `Code{GitHub{owner, name, OpenSource{license}}}` (or
`Proprietary{}`), `Package{..}` on the Bend hub or `Plugin{..}`. A deployment
is intent: `Mac{Tailscale{9453}, [Web{"apps/web"}]}` runs, on this Mac, a web
app built from apps/web.bend, served on the tailnet at HTTPS port 9453. V
derives the rest: the page at dist/web/index.html, a launch agent
com.<user>.<repo>.web (the first word of the account's full name, the
repository's folder) serving it with python3's http.server on 127.0.0.1, its
local port (the one Tailscale already proxies 9453 to, else the first free of
4600, 4610, .. 4990), the `tailscale serve` and the address,
https://<tailnet name>:9453. One app per Tailscale port so far. An app's
`system.bend` imports V, defines `system()` and ends with
`def main() -> IO(Unit): cli(system())`, so `bend system <verb>`, run in the
app's folder, runs it with the verb as its argument (bend runs the longest
`./a/b.bend` its words name and passes it the rest): `check`, also run with no
verb, observes the repository and this Mac and prints the plan, changing
nothing (exit 1 when a step is blocked); `release` builds, then pushes the code
and publishes packages and plugins; `deploy` builds, then (re)loads the launch
agents, `tailscale serve`s them and waits for each address; `ship` builds,
releases and deploys. Each verb but `check` prints the plan first and does
nothing if a step is blocked. A code release is blocked unless origin is
github.com/<owner>/<name>, the tree is clean, and GitHub's visibility is public
for open source, private for proprietary.

Names enter the importing file's scope. For example, `UI`, `layout`,
`Session.initial`, `StreamState.reduce`, `Release` and `plan` require no F/State/V
prefix. Constructors with different meanings stay under their type: use
`UI.Text`, `Geometry.Text` and `Command.Start`.
Private helpers in the copied source do not become bare bindings.

Direct `.bend` imports still work. Prelude bindings refer to those same canonical
types and functions, so mixing a prelude and an explicit leaf import preserves
identity. Imports are local to a file; a module does not re-export its prelude.
The loader selects the public bindings internally. There is no export syntax,
visibility keyword or Browser prelude.

The component/primitive browser bridge emits HTML/CSS or Canvas commands from
Bend values. Browser IO covers events, bounded HTTP, file selection, image decoding
and upload. Application reducers, layouts and views remain Bend functions.
See `WEB.md` for Wasm, workers and WGSL support and fallback limits.

MIT licenses and provenance remain beside the copied near-bend implementation.
