# Framework web backend demo.
import Base
import ../../bend2/std/F/ui/primitives.bend as P
import ../../bend2/std/F/ui/tokens.bend as T
import ../../bend2/std/F/browser/scene.bend as Scene
import ../../bend2/std/F/browser/host.bend as Host

def text(name: String, content: String) -> P.Tree:
  P.text(name, content, P.TextType{"Body", 20, 500}, T.TextRole.Ink{}, 320, 40, P.Leading{})
def view(+count: U32, data: String) -> P.Tree:
  P.layout("App", P.Vertical{}, 8, 16, 360, 200, P.Leading{}, [text("button · increment", "Count: " ++ U32.show(count)), text("button · fetch", "Fetch message"), text("status", data)])
type State is Data:
  State{count: U32, data: String, tree: P.Tree}
def state(+count: U32, +data: String) -> State:
  State{count, data, view(count, data)}
def received(count: U32, reply: Host.Reply) -> IO(State):
  match reply:
    case Host.Reply{1, data}: IO.pure(State, state(count, data))
    case Host.Reply{2, data}: IO.pure(State, state(count, "Error: " ++ data))
    case Host.Reply{3, data}: IO.pure(State, state(count, "Cancelled"))
    case _: IO.pure(State, state(count, "Invalid reply"))
def update(count: U32, data: String, event: Host.Reply) -> IO(State):
  match event:
    case Host.Reply{1, "button · increment"}: IO.pure(State, state(U32.add(count,1), "Ready"))
    case Host.Reply{1, "button · fetch"}:
      do IO<State>:
        reply : Host.Reply <- Host.fetch("./message.txt")
        received(count, reply)
    case _: IO.pure(State, state(count, data))
def loop(fuel: Nat, s: State) -> IO(Unit):
  match fuel s:
    case Zero{} _: IO.pure(Unit, Unit{})
    case Succ{n} State{count, data, tree}:
      do IO<Unit>:
        rendered : Host.Reply <- Host.render(Scene.html(tree))
        event : Host.Reply <- Host.event()
        next : State <- update(count, data, event)
        loop(n, next)
def main() -> IO(Unit): loop(4294967295n, state(0, "Ready"))
