import Base
import F
import State
import V
import ../../bend2/std/F/ui/components.bend as C

def identity(c: UI) -> C.UI: c
def main() -> IO(Unit):
  IO.print("preludes:" ++ Session.phase(Session.initial()))
#|preludes:idle
