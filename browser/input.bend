import Base
import ../ui/primitives.bend as P
import ../ai/wire_json.bend as J
import ./host.bend as Host
import ./scene.bend as Scene

# What a person did in a rendered tree: clicked a button (by its label), typed into a textbox (its label and
# its whole new text), or something an app ignores.
type Input is Data:
  Clicked{label: String}
  Typed{label: String, value: String}
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
          Bool.pick(Input, String.starts_with(data, "button · "), Clicked{String.drop(data, 9n)}, Ignored{})))

# The next Input (it waits for one).
def next() -> IO(Input):
  IO.bind(Host.Reply, Input, Host.event(), r => IO.pure(Input, of(r)))

# Show a tree in the page, its buttons and textboxes live.
def show(+tree: P.Tree) -> IO(Unit):
  IO.bind(Host.Reply, Unit, Host.render(Scene.html(tree)), r => IO.pure(Unit, Unit{}))
