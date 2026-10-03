import Base
import ../../bend2/std/F/ui/primitives.bend as P
import ../../bend2/std/F/ui/tokens.bend as T
import ../../bend2/std/F/ui/symbols.bend as S
import ../../bend2/std/F/ui/nearling.bend as N
import ../../bend2/std/F/browser/scene.bend as Scene
import ../../bend2/std/F/browser/host.bend as Host

def card(+count: U32) -> P.Tree:
  P.layout("frame",P.Vertical{},8,4,160,0,P.Leading{},[
    P.text("button · increment","Count " ++ U32.show(count),P.TextType{"Body",18,500},T.TextRole.Ink{},144,24,P.Leading{}),
    P.symbol("glyph",S.Search{},24),
    P.rounded("gradient",P.Gradient{T.Stop.Of{T.SurfaceRole.Accent{}},T.Stop.Clear{},50},64,32,P.Corner{8},P.Stroke{T.LineRole.Ink{},T.State.Rest{},"2.3"},P.Leading{}),
    P.rounded("circle",P.Solid{T.SurfaceRole.Danger{},T.State.Rest{}},33,33,P.Full{},P.NoStroke{},P.Leading{}),
    P.leaf("shadow",P.Shape{P.Rounded{48,24,P.Corner{4}},P.Fill.None{},P.NoStroke{},[P.Shadow{2,4}]},48,24,P.Leading{}),
    P.rounded("photo",P.Image{P.Bitmap.Photo{"./asset.svg",32,16},0},32,16,P.Corner{0},P.NoStroke{},P.Leading{}),
    P.rounded("sprite",P.Image{P.Bitmap.Atlas{N.Frame{"sprite","./asset.svg",N.Idle{},0,False{},0,1,16,0,16,16,32,16}},0},16,16,P.Corner{0},P.NoStroke{},P.Leading{})])
def status(label: String, reply: Host.Reply) -> IO(Unit):
  match reply:
    case Host.Reply{code,data}: IO.print(label ++ ":" ++ U32.show(code))
def frame(+count: U32) -> IO(Unit):
  do IO<Unit>:
    dom : Host.Reply <- Host.render(Scene.html(card(count)))
    a : Unit <- status("html",dom)
    canvas : Host.Reply <- Host.canvas(Scene.canvas(card(count)))
    status("canvas",canvas)
def changed(event: Host.Reply) -> IO(Unit):
  match event:
    case Host.Reply{1,"button · increment"}: frame(1)
    case Host.Reply{code,data}: IO.print("event:" ++ U32.show(code) ++ ":" ++ data)
def main() -> IO(Unit):
  do IO<Unit>:
    first : Unit <- frame(0)
    event : Host.Reply <- Host.event()
    changed(event)
#|html:2
#|canvas:2
#|event:2:browser host unavailable
