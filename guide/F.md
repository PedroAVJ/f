# Framework preludes

Import the parts you use explicitly:

```bend
import F
import State
```

V needs no import: it is in every file named `system.bend`, and only there.

F supplies component functions, Shape/Layout trees and function transitions.
State supplies component data, AI stream/request data and Dot session records.
V supplies release/deployment declarations and plan/check functions, and
`check` and `deploy` over a `System`. `bend check` and `bend deploy`, run in an
app's folder, apply them to `./system.bend`'s `system()` (its own `main`, if it
has one, runs instead): observe the repository and this Mac, print the plan, and
for `deploy` push, build, (re)load the launchd agents and `tailscale serve`
them. Only `Platform.Launchd` nodes deploy so far.

Names enter the importing file's scope. For example, `UI`, `layout`,
`Session.initial`, `StreamState.reduce`, `Release` and `plan` require no F/State/V
prefix. Constructors with different meanings stay under their type: use
`UI.Text`, `Geometry.Text` and `Command.Start`.
Private helpers in the copied source do not become bare bindings.

Direct `.bend` imports still work. Prelude bindings refer to those same canonical
types and functions, so mixing a prelude and an explicit leaf import preserves
identity. Imports are local to a file; a module does not re-export its prelude.
The loader selects the public bindings internally. There is no export syntax,
visibility keyword, extensionless module resolver or Browser prelude.

The component/primitive browser bridge emits HTML/CSS or Canvas commands from
Bend values. Browser IO covers events, bounded HTTP, file selection, image decoding
and upload. Application reducers, layouts and views remain Bend functions.
See `WEB.md` for Wasm, workers and WGSL support and fallback limits.

MIT licenses and provenance remain beside the copied near-bend implementation.
