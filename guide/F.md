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
`check` and `deploy` over a `System`. An app keeps its `system()` in
`system.bend` and its commands beside it, one file each: `system/deploy.bend`
is `import V`, `import ../system` and `def main() -> IO(Unit):
deploy(system())`, and `bend system deploy`, run in the app's folder, runs it
(bend runs the longest `./a/b.bend` its words name, and passes it the rest).
`check` observes the repository and this Mac and prints the plan; `deploy`
then pushes, builds, (re)loads the launchd agents and `tailscale serve`s them.
Only `Platform.Launchd` nodes deploy so far. A `System` ends with its releases,
one per thing released: `Code{GitHub{owner, name, OpenSource{license}}}` (or
`Proprietary{}`), `Package{..}` on the Bend hub and `Plugin{..}`; a code release
is blocked unless origin is github.com/<owner>/<name> and GitHub's visibility
is public for open source, private for proprietary.

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
