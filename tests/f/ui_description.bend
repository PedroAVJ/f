import Base
import F
import ../../bend2/std/F/ui/primitives.bend as P
import ../../bend2/std/F/ui/description.bend as FUI
import ../../demos/browser/ui.bend as App

def shape_content(shape: Shape) -> String:
  match shape:
    case P.Shape{P.Text{string, text_type}, fill, stroke, effects}: string ++ "|"
    case _: ""
def content(tree: Tree) -> String:
  match tree:
    case P.Last{}: ""
    case P.Leaf{name, shape, width, height, align, next}: shape_content(shape) ++ content(next)
    case P.Node{name, layout, width, height, align, first, next}: content(first) ++ content(next)

def main() -> IO(Unit):
  do IO<Unit>:
    initial : Unit <- IO.print(content(FUI.root(Tree, App.F(App.State{0, "Ready"}))))
    changed : Unit <- IO.print(content(FUI.root(Tree, App.F(App.State{7, "Fetched"}))))
    IO.print(Component.html(FUI.root(Component, FUI.UI{Component.Text{"status", "<safe>"}})))

#|Count: 0|Fetch message|Ready|
#|Count: 7|Fetch message|Fetched|
#|<p class="status">&lt;safe&gt;</p>
