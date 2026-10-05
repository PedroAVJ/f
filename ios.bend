import UI
import ../f/bend2/std/F/browser/input.bend as Native
import ../f/bend2/std/F/browser/host.bend as Host
import ../f/bend2/std/F/ui/kit.bend as K
import ../f/bend2/std/F/ui/tokens.bend as T
import ./mobile.bend as M

def paint(state: M.State) -> IO(Unit):
  Native.show_canvas_in(M.f(state), K.Rendering{K.Lang.Es{}, []}, T.Scheme.Dark{})
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
    window : Unit <- Native.configure_window(Native.WindowConfig{390, 844, 320, 240})
    persistence : Unit <- Native.configure_input_persistence(True{})
    painted : Unit <- paint(M.s())
    state : M.State <- M.fetch_session(M.s())
    loop(4294967295n, state)
