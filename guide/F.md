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
the verbs over a `System{key, name, description, releases, deployments}`. A
release is one thing released: `Code{GitHub{owner, name, OpenSource{license}}}`
(or `Proprietary{}`), `Package{..}` on the Bend hub or `Plugin{..}`; a
deployment is an address and its nodes. An app's `system.bend` imports V,
defines `system()` and ends with `def main() -> IO(Unit): cli(system())`, so
`bend system <verb>`, run in the app's folder, runs it with the verb as its
argument (bend runs the longest `./a/b.bend` its words name and passes it the
rest): `check`, also run with no verb, observes the repository and this Mac
and prints the plan, changing nothing (exit 1 when a step is blocked); `build`
builds every artifact; `release` builds, then pushes the code and publishes
packages and plugins; `deploy` builds, then (re)loads the launchd agents,
`tailscale serve`s them and waits for each address; `ship` builds, releases and
deploys. Each verb but `check` prints the plan first and does nothing if a step
is blocked. A code release is blocked unless origin is
github.com/<owner>/<name>, the tree is clean, and GitHub's visibility is public
for open source, private for proprietary. Only `Platform.Launchd` nodes deploy
so far.

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
