import Base
import UI
import V
import ../../bend2/std/F/ui/primitives.bend as P

# UI is a prelude and its output type: the type names primitives' UI
def identity(u: UI) -> P.UI: u
def main() -> IO(Unit):
  IO.print("preludes:" ++ Session.phase(Session.initial()))
#|preludes:idle
