import Base
import ../../bend2/std/F/ui/primitives.bend as P
import ../../bend2/std/F/ui/tokens.bend as T
import ../../bend2/std/F/browser/scene.bend as Scene
import ../../bend2/std/F/browser/host.bend as Host

def view() -> P.Tree:
  P.rounded("large",P.Solid{T.SurfaceRole.Accent{},T.State.Rest{}},1000,700,P.Corner{8},P.Stroke{T.LineRole.Ink{},T.State.Rest{},"1e-2"},P.Leading{})
def status(label: String, reply: Host.Reply) -> IO(Unit):
  match reply:
    case Host.Reply{code,data}: IO.print(label ++ ":" ++ U32.show(code))
def main() -> IO(Unit):
  do IO<Unit>:
    dom : Host.Reply <- Host.render(Scene.html(view()))
    a : Unit <- status("html",dom)
    canvas : Host.Reply <- Host.canvas(Scene.canvas(view()))
    status("canvas",canvas)
#|html:2
#|canvas:2
