# Canvas theme selection changes every token-bearing paint property while
# retaining the existing Light packet, geometry and interactive regions.
import Base
import ../../bend2/std/F/ui/primitives.bend as P
import ../../bend2/std/F/ui/tokens.bend as T
import ../../bend2/std/F/browser/scene.bend as Scene

def tile() -> P.UI:
  P.rounded("tile", P.Solid{T.SurfaceRole.Background{}, T.State.Rest{}}, 32, 24, P.Full{}, P.NoStroke{}, P.Leading{})

def main() -> IO(Unit):
  +light = Scene.canvas(tile())
  +dark = Scene.canvas_in(tile(), T.Scheme.Dark{})
  do IO<Unit>:
    IO.print(light)
    IO.print(dark)
    IO.print(Bool.show(String.eq(light, Scene.canvas_in(tile(), T.Scheme.Light{}))))
    IO.print(Scene.fill_json_in(P.Gradient{T.Stop.Of{T.SurfaceRole.Accent{}}, T.Stop.Clear{}, 50}, T.Scheme.Dark{}))
    IO.print(Scene.stroke_json_in(P.Stroke{T.LineRole.Ink{}, T.State.Rest{}, "1.5"}, T.Scheme.Dark{}))
    IO.print(Scene.effect_json_in(P.Glass{8, 140, 2, 30, 80, T.LineRole.Edge{}, T.Backdrop.Base{}}, T.Scheme.Dark{}))
    IO.print(Scene.paint_in(P.Shape{P.Text{"Dot", P.TextType{"Label", 17, 600}}, P.TextFill.Solid{T.TextRole.Ink{}, T.State.Rest{}}, P.NoStroke{}, []}, "", T.Scheme.Dark{}))
#|[["frame",32,24],["clear"],["shape","tile",0,0,32,24,["rounded",32,24,12],["solid","#ffffff"],["none"],[]]]
#|[["frame",32,24],["clear"],["shape","Canvas background",0,0,32,24,["rounded",32,24,0],["solid","#000000"],["none"],[]],["shape","tile",0,0,32,24,["rounded",32,24,12],["solid","#000000"],["none"],[]]]
#|True
#|["gradient","#2c5785","rgba(0,0,0,0)",50]
#|["stroke","#f6f7f8","1.5"]
#|["glass",8,140,2,30,80,"#414141"]
#|["text","Dot",17,600],["solid","#f6f7f8"],["none"],[]]
