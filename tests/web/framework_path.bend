import Base
import ../../bend2/std/F/ui/primitives.bend as P
import ../../bend2/std/F/ui/symbols.bend as S
import ../../bend2/std/F/browser/scene.bend as Scene
import ../../bend2/std/F/browser/host.bend as Host

def view() -> P.Tree: P.symbol("large-glyph",S.Search{},48)
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
