import Base
import ../../bend2/std/F/ui/primitives.bend as P
import ../../bend2/std/F/ui/tokens.bend as T
import ../../bend2/std/F/browser/scene.bend as Scene
import ../../bend2/std/F/browser/host.bend as Host

def kernel(x: U32) -> U32: U32.add(U32.mul(x,3),1)
def tree(+value: U32) -> P.Tree:
  P.layout("result",P.Vertical{},8,4,160,64,P.Leading{},[
    P.text("label","GPU sum " ++ U32.show(value),P.TextType{"Body",18,500},T.TextRole.Ink{},144,24,P.Leading{}),
    P.rounded("bar",P.Solid{T.SurfaceRole.Accent{},T.State.Rest{}},value,16,P.Corner{2},P.NoStroke{},P.Leading{})])
def draw(+total: U32) -> IO(Unit):
  do IO<Unit>:
    dom : Host.Reply <- Host.render(Scene.html(tree(total)))
    canvas : Host.Reply <- Host.canvas(Scene.canvas(tree(total)))
    IO.print("GPU sum " ++ U32.show(total))
def main() -> IO(Unit):
  do IO<Unit>:
    a : U32 <- IO.pure(U32,kernel!(2))
    b : U32 <- IO.pure(U32,kernel!(3))
    c : U32 <- IO.pure(U32,kernel!(4))
    draw(U32.add(a,U32.add(b,c)))
#|GPU sum 30
