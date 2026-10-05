import UI
import ../../bend2/std/F/browser/input.bend as Native
import ../../bend2/std/F/browser/host.bend as Host
import ../../bend2/std/F/browser/scene.bend as Scene
import ../../bend2/std/F/ui/kit.bend as K
import ../../bend2/std/F/ui/primitives.bend as P
import ../../bend2/std/F/ui/tokens.bend as T
import ./mobile.bend as M
import ./components/web_scene.bend as Web

def paint(+state: M.State) -> IO(Unit):
  IO.bind(Host.Reply, Unit, Host.render(Web.html(K.draw(M.f(state), K.Rendering{M.lang(state), []}))), reply => IO.pure(Unit, Unit{}))

def loop(fuel: Nat, +state: M.State) -> IO(Unit):
  match fuel:
    case 0n: IO.pure(Unit, Unit{})
    case 1n+n:
      do IO<Unit>:
        painted : Unit <- paint(state)
        event : Host.Reply <- Host.event()
        next : M.State <- M.event_step(state, event)
        loop(n, next)

def main() -> IO(Unit):
  do IO<Unit>:
    window : Host.Reply <- Host.request(9, "{}")
    +initial : M.State <- IO.pure(M.State, M.update(M.s(), Native.of(window)))
    painted : Unit <- paint(initial)
    state : M.State <- M.fetch_session(initial)
    loop(4294967295n, state)
