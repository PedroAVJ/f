import Base
import ../ui/primitives.bend as P
import ../ui/kit.bend as K
import ../ui/tokens.bend as T
import ../ai/wire_json.bend as J
import ./host.bend as Host
import ./scene.bend as Scene

# What a person did in a rendered tree: clicked a button (by its label), typed into a textbox (its label and
# its whole new text), focused or left a textbox, went to an address (back, forward, a link: the web loop
# sets the page from it), or something an app ignores.
type Input is Data:
  Clicked{label: String}
  Typed{label: String, value: String}
  Focused{label: String}
  Blurred{label: String}
  Navigated{address: String}
  Ignored{}
  Resized{width: U32, height: U32}

# Native window dimensions are content points, before any Canvas layout.
# Apps without a window() hook keep the original frame-sized shell.
type WindowConfig is Data:
  WindowConfig{width: U32, height: U32, min_width: U32, min_height: U32}

def field(r: Result<&1, &1, String, J.Json>, +key: String) -> String:
  match r:
    case Done{+j}:
      J.text(J.get(j, key))
    case Fail{e}:
      ""

def typed(+data: String) -> Input:
  +name = field(J.read(data), "name")
  +action = field(J.read(data), "action")
  +label = String.drop(name, 10n)
  Bool.pick(Input, Bool.not(String.starts_with(name, "textbox · ")), Ignored{},
    Bool.pick(Input, String.eq(action, "field"), Typed{label, field(J.read(data), "value")},
      Bool.pick(Input, String.eq(action, "focus"), Focused{label},
        Bool.pick(Input, String.eq(action, "blur"), Blurred{label}, Ignored{}))))

def dimension(value: Maybe<&2, J.Json>) -> Maybe<&2, U32>:
  match value:
    case Some{J.Number{text}}: U32.read(text)
    case _: None{}

def resized_dimensions(w: Maybe<&2, U32>, h: Maybe<&2, U32>) -> Input:
  match w:
    case Some{+width}:
      match h:
        case Some{+height}:
          Bool.pick(Input, (width > 0 : U32) && (height > 0 : U32), Resized{width, height}, Ignored{})
        case _: Ignored{}
    case _: Ignored{}

def resized(r: Result<&1, &1, String, J.Json>) -> Input:
  match r:
    case Done{+j}:
      resized_dimensions(dimension(J.get(j, "width")), dimension(J.get(j, "height")))
    case _: Ignored{}

def json_input(+data: String) -> Input:
  Bool.pick(Input, String.eq(field(J.read(data), "action"), "resize"), resized(J.read(data)), typed(data))

# A browser event as an Input: a button region sends its node name, a textbox a field edit.
def of(r: Host.Reply) -> Input:
  match r:
    case Host.Reply{+status, +data}:
      Bool.pick(Input, Bool.not(U32.is_eq(status, 1)), Ignored{},
        Bool.pick(Input, String.starts_with(data, "{"), json_input(data),
          Bool.pick(Input, String.starts_with(data, "button · "), Clicked{String.drop(data, 9n)},
            Bool.pick(Input, String.starts_with(data, "address · "), Navigated{String.drop(data, 10n)}, Ignored{}))))

# The next Input (it waits for one).
def next() -> IO(Input):
  IO.bind(Host.Reply, Input, Host.event(), r => IO.pure(Input, of(r)))

# The inputs' states after an Input: an edit sets its textbox's text; focusing or leaving it, its focus.
def with_text(xs: List<&2, K.Held>, +label: String, +text: String) -> List<&2, K.Held>:
  match xs:
    case []: [K.Held{label, K.InputState{text, K.Focus.Blurred{}}}]
    case K.Held{+l, K.InputState{t, +f}} <> +rest:
      Bool.pick(List<&2, K.Held>, String.eq(l, label), K.Held{l, K.InputState{text, f}} <> rest, K.Held{l, K.InputState{t, f}} <> with_text(rest, label, text))
def with_focus(xs: List<&2, K.Held>, +label: String, +focus: K.Focus) -> List<&2, K.Held>:
  match xs:
    case []: [K.Held{label, K.InputState{"", focus}}]
    case K.Held{+l, K.InputState{+t, f}} <> +rest:
      Bool.pick(List<&2, K.Held>, String.eq(l, label), K.Held{l, K.InputState{t, focus}} <> rest, K.Held{l, K.InputState{t, f}} <> with_focus(rest, label, focus))
def keep(xs: List<&2, K.Held>, i: Input) -> List<&2, K.Held>:
  match i:
    case Typed{l, v}: with_text(xs, l, v)
    case Focused{l}: with_focus(xs, l, K.Focus.Focused{})
    case Blurred{l}: with_focus(xs, l, K.Focus.Blurred{})
    case _: xs

# A UI as HTML or Canvas commands in a language, its inputs empty (a first screen).
def html(u: K.UI, +lang: K.Lang) -> String:
  Scene.html(K.draw(u, K.Rendering{lang, []}))
def canvas(u: K.UI, +lang: K.Lang) -> String:
  Scene.canvas(K.draw(u, K.Rendering{lang, []}))

# Show a UI in the page, its buttons and textboxes live, in the app's language with its inputs' states.
def show(u: K.UI, r: K.Rendering) -> IO(Unit):
  IO.bind(Host.Reply, Unit, Host.render(Scene.html(K.draw(u, r))), x => IO.pure(Unit, Unit{}))

# Show a UI at an address: the page marks it for the browser's address bar.
def show_at(u: K.UI, r: K.Rendering, address: String) -> IO(Unit):
  IO.bind(Host.Reply, Unit, Host.render(Scene.html(K.draw(u, r)) ++ "<span hidden data-bend-address=\"" ++ Scene.escape(address) ++ "\"></span>"),
    x => IO.pure(Unit, Unit{}))

# Show a UI as Canvas commands (what a native shell paints, or the browser's canvas renderer), its buttons and
# textboxes live regions, in the app's language with its inputs' states.
def show_canvas(u: K.UI, r: K.Rendering) -> IO(Unit):
  IO.bind(Host.Reply, Unit, Host.canvas(Scene.canvas(K.draw(u, r))), x => IO.pure(Unit, Unit{}))

# Choose the Canvas tokens explicitly; HTML and show_canvas keep their defaults.
def scheme_name(s: T.Scheme) -> String:
  match s:
    case T.Scheme.Dark{}: "dark"
    case T.Scheme.Light{}: "light"
def show_canvas_in(u: K.UI, r: K.Rendering, +scheme: T.Scheme) -> IO(Unit):
  IO.bind(Host.Reply, Unit, Host.request(8, scheme_name(scheme)), configured =>
    IO.bind(Host.Reply, Unit, Host.canvas(Scene.canvas_in(K.draw(u, r), scheme)), x => IO.pure(Unit, Unit{})))

# A native app may let its State own draft persistence. Configure this before
# its first paint; the browser keeps its existing input-storage behavior.
def configure_input_persistence(enabled: Bool) -> IO(Unit):
  IO.bind(Host.Reply, Unit, Host.request(7, Bool.pick(String, enabled, "1", "0")), x => IO.pure(Unit, Unit{}))

def configure_window(w: WindowConfig) -> IO(Unit):
  match w:
    case WindowConfig{width, height, min_width, min_height}:
      IO.bind(Host.Reply, Unit, Host.request(9,
        "{\"width\":" ++ U32.show(width) ++ ",\"height\":" ++ U32.show(height) ++
        ",\"min_width\":" ++ U32.show(min_width) ++ ",\"min_height\":" ++ U32.show(min_height) ++ "}"),
        x => IO.pure(Unit, Unit{}))
