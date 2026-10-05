import UI
import ../f/bend2/std/F/browser/input.bend as Native
import ../f/bend2/std/F/browser/host.bend as Host
import ../f/bend2/std/F/ui/kit.bend as K
import ../f/bend2/std/F/ui/tokens.bend as T
import ./mobile.bend as M
import ../f/bend2/std/F/browser/scene.bend as Scene

def paint(+state: M.State) -> IO(Unit):
  Native.show_canvas_in(M.f(state), K.Rendering{M.lang(state), []}, T.Scheme.Dark{})
def commit_refresh(previous: M.State, next: M.State, reply: Host.Reply) -> M.State:
  match reply:
    case Host.Reply{1, data}: next
    case Host.Reply{3, "conversation refresh deferred"}: previous
    case Host.Reply{status, data}: M.State.with_error(previous, data)
def is_refresh(event: Host.Reply) -> Bool:
  match event:
    case Host.Reply{1, "{\"action\":\"refresh\"}"}: True{}
    case _: False{}
def step(+state: M.State, +event: Host.Reply) -> IO(M.State):
  do IO<M.State>:
    +next : M.State <- M.event_step(state, event)
    Bool.pick(IO(M.State), is_refresh(event) && Bool.not(M.is_calling(M.State.panel(state))),
      IO.bind(Host.Reply, M.State, Host.request(14, Scene.canvas_in(K.draw(M.f(next), K.Rendering{M.lang(next), []}), T.Scheme.Dark{})), reply => IO.pure(M.State, commit_refresh(state, next, reply))), IO.pure(M.State, next))
def loop(fuel: Nat, +state: M.State) -> IO(Unit):
  match fuel:
    case 0n: IO.pure(Unit, Unit{})
    case 1n+n:
      do IO<Unit>:
        painted : Unit <- paint(state)
        event : Host.Reply <- Host.event()
        next : M.State <- step(state, event)
        loop(n, next)
def main() -> IO(Unit):
  do IO<Unit>:
    window : Host.Reply <- Host.request(9, "{\"width\":390,\"height\":844,\"min_width\":320,\"min_height\":240}")
    +initial : M.State <- IO.pure(M.State, M.update(M.s(), Native.of(window)))
    persistence : Unit <- Native.configure_input_persistence(True{})
    painted : Unit <- paint(initial)
    state : M.State <- M.fetch_session(initial)
    loop(4294967295n, state)
