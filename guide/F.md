# Framework preludes

Import the parts you use explicitly:

```bend
import Base
import F
import State
import V
```

F supplies component functions, Shape/Layout trees and function transitions.
State supplies component data, AI stream/request data and Dot session records.
V supplies release/deployment declarations and plan/check functions.

Names enter the importing file's scope. For example, `Component`, `layout`,
`Session.initial`, `StreamState.reduce`, `Release` and `plan` require no F/State/V
prefix. Constructors with different meanings stay under their type: use
`Component.Text`, `Geometry.Text` and `Command.Start`.
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

`ui/description.bend` supplies a generic `UI<Description>` result containing
one renderer description, such as `Tree` or `Component`. Import it explicitly:

```bend
import ./bend2/std/F/ui/description.bend as Description
```

The relative path above assumes an application at the repository root. This
API is not yet a bare binding selected by `import F`. The library import alias
`Description` stays distinct from the application function `F`. A local type
alias specializes the generic result to the renderer vocabulary:

```bend
law UI: Data
def UI(): Description.UI<Tree>
```

The application can then declare `def F(state: State) -> UI` with a composed,
type-checked body. Pass `Description.root(Tree, F(state))` to `Tree.html`.

See `demos/browser/ui.bend` for the complete typed `F(state: State) -> UI` example.
Its application State holds count and fetched data. Counter takes its input
explicitly; the local status closure captures data and passes through StatusPanel
without giving that panel a data parameter. The closure is affine and called
once; it is recreated for each F evaluation. The result holds a pure description,
with no persistent component state or effects. The browser loop and reducer
remain Bend functions in `demos/browser/main.bend`.

MIT licenses and provenance remain beside the copied near-bend implementation.
