# Framework preludes

Import the parts you use explicitly:

```bend
import F
import State
import V
```

F supplies component functions, Shape/Layout trees and function transitions.
In the browser, `Tree.show(t)` renders a tree with its buttons and textboxes
live, and `Input.next()` waits for what a person did: `Clicked{label}`,
`Typed{label, value}` (the textbox's whole new text) or `Ignored{}`.
State supplies component data, AI stream/request data and Dot session records.
V supplies release/deployment declarations and plan functions, and the verbs
over a `System{releases, deployments}`. A release is one thing released:
`Code{GitHub{owner, name, OpenSource{license}}}` (or `Proprietary{}`),
`Package{..}` on the Bend hub or `Plugin{..}`. A deployment is intent:
`Mac{Tailscale{9453}, [Web{"ui"}]}` runs, on this Mac, the web app whose UI is
ui.bend's `f`, served on the tailnet at HTTPS port 9453. V derives the rest:
the app, from entries it writes beside dist/web (it renders `f(state)` from
state.bend's `initial()`, waits for an `Input`, applies update.bend's
`update(state, input)` and renders again), built with `-o dist/web.web` (which
needs Emscripten) into dist/web, its index.html titled and prerendered with
the first screen; a launch agent
com.<user>.<repo>.web (the first word of the account's full name, the
repository's folder) serving it with python3's http.server on 127.0.0.1; its
local port (the one Tailscale already proxies 9453 to, else the first free of
4600, 4610, .. 4990); the `tailscale serve`; and the address,
https://<tailnet name>:9453. One app per Tailscale port so far. An app's
`system.bend` imports V, defines `system()` and ends with
`def main() -> IO(Unit): cli(system())`, so `bend system <verb>`, run in the
app's folder, runs it with the verb as its argument (bend runs the longest
`./a/b.bend` its words name and passes it the rest): `diff`, also run with no
verb, compares the system with the repository and this Mac and prints the
steps that would make them agree, changing nothing (exit 1 when one is
blocked); `build` builds every app into dist/, recording beside each the hash
of its inputs (the entry, the fork's commit, the repository's Bend files);
`release` pushes the code and publishes packages and plugins; `deploy` ships
what dist/ holds, (re)loads the launch agents, `tailscale serve`s them and
waits for each address. Neither builds: a deploy is blocked ("build first")
while an app's build is missing or its inputs changed since. Each verb but
`diff` prints its steps first and does nothing if one is blocked. A code
release is blocked unless origin is github.com/<owner>/<name>, the tree is
clean, and GitHub's visibility is public for open source, private for
proprietary.

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
