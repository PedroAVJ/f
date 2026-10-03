import Base
import ../../bend2/std/F/ui/primitives.bend as P
import ../../bend2/std/F/ui/kit.bend as K
import ../../bend2/std/F/browser/scene.bend as Scene
import ../../bend2/std/F/browser/host.bend as Host

def view() -> P.Tree:
  P.layout("buttons",P.Vertical{},8,4,160,104,P.Leading{},[
    K.button_tree(K.act(K.ButtonKind.Primary{},K.Intent.Send{},K.Form.Both{})),
    K.button_tree(K.act_off(K.ButtonKind.Primary{},K.Intent.Send{},K.Form.Both{}))])
def clicked(reply: Host.Reply) -> IO(Unit):
  match reply:
    case Host.Reply{code,data}: IO.print("clicked:" ++ U32.show(code) ++ ":" ++ data)
def main() -> IO(Unit):
  do IO<Unit>:
    dom : Host.Reply <- Host.render(Scene.html(view()))
    canvas : Host.Reply <- Host.canvas(Scene.canvas(view()))
    event : Host.Reply <- Host.event()
    clicked(event)
#|clicked:2:browser host unavailable
