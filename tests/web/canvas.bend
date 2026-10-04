import Base
import ../../bend2/std/F/ui/primitives.bend as P
import ../../bend2/std/F/ui/tokens.bend as T
import ../../bend2/std/F/browser/scene.bend as Scene
import ../../bend2/std/F/browser/host.bend as Host

def tile(+size: U32) -> P.UI:
  P.rounded("tile", P.Solid{T.SurfaceRole.Background{}, T.State.Rest{}}, size, size, P.Corner{0}, P.NoStroke{}, P.Leading{})
def show(label: String, reply: Host.Reply) -> IO(Unit):
  match reply:
    case Host.Reply{status, data}: IO.print(label ++ ":" ++ U32.show(status))
def main() -> IO(Unit):
  do IO<Unit>:
    first : Host.Reply <- Host.canvas(Scene.canvas(tile(32)))
    printed : Unit <- show("paint", first)
    second : Host.Reply <- Host.canvas(Scene.canvas(tile(16)))
    show("repaint", second)
#|paint:2
#|repaint:2
