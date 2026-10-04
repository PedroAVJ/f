# Framework preludes

Import the parts you use explicitly:

```bend
import UI
import V
```

UI supplies the output type `UI`, component functions, function
transitions, component data, AI stream/request data and Dot session records.
An app's blocks need no names, widths or languages: `screen([..])`,
`stack([..])`, `title(t)`, `caption(t)`, `input(placeholder)`, `action(label)`
(primary and enabled; `action_as(kind, label, enabled)` otherwise) and
`lines(xs)` take `Text{en, es}`, every language inline, and a `UI` is drawn
to a `Tree` (Shape/Layout) in the app's language when shown. An input owns
its state, `InputState{text, focus}`: `UI.Owned{label, view}` holds its view,
a function of that state, which the runtime keeps by the input's label and
supplies. In the browser, `UI.show(u, Rendering{lang, inputs})` renders a UI
with its buttons and textboxes live, and `Input.next()` waits for what a
person did: `Clicked{label}`, `Typed{label, value}` (the textbox's whole new
text), `Focused{label}`, `Blurred{label}`, `Navigated{address}` or
`Ignored{}`; `Input.keep(inputs, i)` is the inputs' states after it. The page
keeps each textbox's text in localStorage, by its name, and gives it back as
an edit when the textbox appears empty. A file importing UI that defines
`type Page` gets `Page.url(p)` and `Page.at(address)` from its shape: a case
is its kebab-case name, then its String and U32 fields as segments and a
nested Data type of the file (last) as its own path; an unknown address is
the first case. A one-case `State` with a `page: Page` field also gets
`State.page(s)`, `State.with_page(s, p)` and `State.lang(s)` (its
`lang: Lang` field, else English).

V supplies release/deployment declarations and plan functions, and the verbs
over a `System{releases, deployments}`. A release is one thing released:
`Code{GitHub{owner, name, OpenSource{license}}}` (or `Proprietary{}`),
`Package{..}` on the Bend hub or `Plugin{..}`. A deployment is intent:
`Mac{Tailscale{9453}, [Web{"ui"}]}` runs, on this Mac, the web app whose UI is
ui.bend's `f`, served on the tailnet at HTTPS port 9453. V derives the rest:
the app, from entries it writes beside dist/web (ui.bend defines `State`,
with a `page: Page`, its first state `s()`, `update(s, input)` and `f(s)`;
the app shows `f(s)` at its page's address in `State.lang(s)`, with its
inputs' states, waits for an `Input`, goes to the page an address names or
updates, keeps the inputs' states, and shows again), built by the fork's internal tool (`bend2/tool.ts`, `-o dist/web.web`, which
needs Emscripten; the `bend` command only runs) into dist/web, its index.html titled and prerendered with
the first screen; a launch agent
com.<user>.<repo>.web (the first word of the account's full name, the
repository's folder) serving it with python3's http.server on 127.0.0.1,
index.html for any path that is not a file; its
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

`Mac{Tailscale{9453}, [Application.MacOS{"ui"}]}` declares a native Mac
app from the same `State`, `Page`, `s`, `update` and `f` contract. It needs
no Tailscale connection or HTTP server. One native app per deployment is
supported; it can also accompany the existing `Web{"ui"}` target. Native
builds use Xcode's command-line tools to compile Bend to C and link the
fork's AppKit shell and CoreGraphics painter, for Apple silicon on macOS
14 or newer. The app's state, layout and updates stay in Bend.

Keep the application and this fork in sibling folders, with the fork named
`f`. From the application's folder, run:

```sh
bun ../f/bend2/main.ts system build
bun ../f/bend2/main.ts system diff
bun ../f/bend2/main.ts system deploy
```

The native build writes `dist/mac.macos/<name>.app`, whose name is the first
text in the first screen (the repository folder if it has none), and bundle
identifier `com.<user>.<repo>.mac`. Its manifest records the version,
compiler target, SDK and signing identity. V's stamp also checks the bundle
identity, app bytes, repository Bend files and the fork's committed and
uncommitted sources. `diff` reports the build and installed version;
`deploy` requires a current build, installs into `~/Applications`, replaces
an earlier app only with the same bundle identifier, then relaunches and
confirms it runs. Another app with the same name in `~/Applications` or
`/Applications` blocks installation. The internal tool can also emit a
bundle directly with `-o <dir>.macos --id <identifier> --name <name>`.
It signs with an available Apple Development identity, falling back to ad
hoc signing; `--identity -` explicitly selects ad hoc.

Native rendering defaults to Light, as Canvas already does. An application
can import `../f/bend2/std/F/ui/tokens.bend as T` and define
`def scheme() -> T.Scheme` to return `T.Scheme.Dark{}`. V then calls
`Native.show_canvas_in` with that scheme. A `def persist_inputs() -> Bool`
hook chooses whether the native shell restores textbox values; it runs once
before the first paint. Without these optional functions the existing
rendering and input behavior remains. The Web target does not use them.

For a resizable desktop layout, import
`../f/bend2/std/F/browser/input.bend as Native` and define
`def window() -> Native.WindowConfig` returning
`Native.WindowConfig{1000, 760, 640, 560}`. The four dimensions are initial
width and height, then minimum width and height, in content points. V
configures the window before painting. The reducer receives
`Native.Resized{width, height}` with the actual content viewport, including
changes from resizing or full screen. Store those dimensions in State and
use them to lay out the next tree. Apps without this hook retain the
original frame-sized window behavior.

Names enter the importing file's scope. For example, `UI`, `layout`,
`Session.initial`, `StreamState.reduce`, `Release` and `plan` require no UI/V
prefix. Constructors with different meanings stay under their type: use
`Geometry.Text` and `Command.Start`.
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
