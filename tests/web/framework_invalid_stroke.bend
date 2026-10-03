import Base
import ../../bend2/std/F/ui/primitives.bend as P
import ../../bend2/std/F/ui/tokens.bend as T
import ../../bend2/std/F/browser/scene.bend as Scene
import ../../bend2/std/F/browser/host.bend as Host

def view() -> P.Tree:
  P.rounded("stroke",P.Solid{T.SurfaceRole.Surface{},T.State.Rest{}},64,32,P.Corner{8},P.Stroke{T.LineRole.Line{},T.State.Rest{},"0px #000;background:rgb(1,2,3);--probe:"},P.Leading{})
def status(label: String, reply: Host.Reply) -> IO(Unit):
  match reply:
    case Host.Reply{code,data}: IO.print(label ++ ":" ++ U32.show(code) ++ ":" ++ data)
def main() -> IO(Unit):
  do IO<Unit>:
    dom : Host.Reply <- Host.render(Scene.html(view()))
    a : Unit <- status("html",dom)
    canvas : Host.Reply <- Host.canvas(Scene.canvas(view()))
    status("canvas",canvas)
#|html:2:browser host unavailable
#|canvas:2:browser host unavailable
