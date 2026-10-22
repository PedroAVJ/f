# Framework web backend demo.
import Base
import ../../bend2/std/F/ui/primitives.bend as P
import ../../bend2/std/F/ui/description.bend as Description
import ../../bend2/std/F/browser/scene.bend as Scene
import ../../bend2/std/F/browser/host.bend as Host
import ./ui.bend as App

def state(count: U32, data: String) -> App.State:
  App.State{count, data}
def received(count: U32, reply: Host.Reply) -> IO(App.State):
  match reply:
    case Host.Reply{1, data}: IO.pure(App.State, state(count, data))
    case Host.Reply{2, data}: IO.pure(App.State, state(count, "Error: " ++ data))
    case Host.Reply{3, data}: IO.pure(App.State, state(count, "Cancelled"))
    case _: IO.pure(App.State, state(count, "Invalid reply"))
def update(count: U32, data: String, event: Host.Reply) -> IO(App.State):
  match event:
    case Host.Reply{1, "button · increment"}: IO.pure(App.State, state(U32.add(count,1), "Ready"))
    case Host.Reply{1, "button · fetch"}:
      do IO<App.State>:
        reply : Host.Reply <- Host.fetch("./message.txt")
        received(count, reply)
    case _: IO.pure(App.State, state(count, data))
def loop(fuel: Nat, s: App.State) -> IO(Unit):
  match fuel s:
    case Zero{} _: IO.pure(Unit, Unit{})
    case Succ{n} App.State{+count, +data}:
      do IO<Unit>:
        rendered : Host.Reply <- Host.render(Scene.html(Description.root(P.Tree, App.F(App.State{count, data}))))
        event : Host.Reply <- Host.event()
        next : App.State <- update(count, data, event)
        loop(n, next)
def main() -> IO(Unit): loop(4294967295n, state(0, "Ready"))
