import Base
import UI
import V
import ../../bend2/std/F/ui/primitives.bend as P

# UI is a prelude; its Tree names primitives' UI, and a UI is drawn to one
def identity(t: Tree) -> P.UI: t
def drawn(u: UI) -> P.UI: UI.draw(u, Rendering{Lang.En{}, []})
def main() -> IO(Unit):
  IO.print("preludes:" ++ Session.phase(Session.initial()))
#|preludes:idle
