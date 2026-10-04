import Base
import ../ui/primitives.bend as P
import ../ai/wire_json.bend as J
import ./host.bend as Host
import ./scene.bend as Scene

# What a person did in a rendered tree: clicked a button (by its label), typed into a textbox (its label and
# its whole new text), went to an address (back, forward, a link: the web loop sets the page from it), or
# something an app ignores.
type Input is Data:
  Clicked{label: String}
  Typed{label: String, value: String}
  Navigated{address: String}
  Ignored{}

def field(r: Result<&1, &1, String, J.Json>, +key: String) -> String:
  match r:
    case Done{+j}:
      J.text(J.get(j, key))
    case Fail{e}:
      ""

def typed(+data: String) -> Input:
  +name = field(J.read(data), "name")
  Bool.pick(Input, String.eq(field(J.read(data), "action"), "field") && String.starts_with(name, "textbox · "),
    Typed{String.drop(name, 10n), field(J.read(data), "value")}, Ignored{})

# A browser event as an Input: a button region sends its node name, a textbox a field edit.
def of(r: Host.Reply) -> Input:
  match r:
    case Host.Reply{+status, +data}:
      Bool.pick(Input, Bool.not(U32.is_eq(status, 1)), Ignored{},
        Bool.pick(Input, String.starts_with(data, "{"), typed(data),
          Bool.pick(Input, String.starts_with(data, "button · "), Clicked{String.drop(data, 9n)},
            Bool.pick(Input, String.starts_with(data, "address · "), Navigated{String.drop(data, 10n)}, Ignored{}))))

# The next Input (it waits for one).
def next() -> IO(Input):
  IO.bind(Host.Reply, Input, Host.event(), r => IO.pure(Input, of(r)))

# Show a tree in the page, its buttons and textboxes live.
def show(+tree: P.UI) -> IO(Unit):
  IO.bind(Host.Reply, Unit, Host.render(Scene.html(tree)), r => IO.pure(Unit, Unit{}))

# Show a tree at an address: the page marks it for the browser's address bar.
def show_at(+tree: P.UI, address: String) -> IO(Unit):
  IO.bind(Host.Reply, Unit, Host.render(Scene.html(tree) ++ "<span hidden data-bend-address=\"" ++ Scene.escape(address) ++ "\"></span>"),
    r => IO.pure(Unit, Unit{}))
