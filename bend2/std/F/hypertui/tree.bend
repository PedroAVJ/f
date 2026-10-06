import Base
import ../ui/primitives.bend as P

# The executable specialization of SPEC's Tree(Axis, Path). F's existing
# shapes retain text strings, paint and image assets; SPEC's command enum
# deliberately does not yet define those payloads or glyph outlines.
type Branch is Data:
  Branch{name: String, axis: P.Axis}

type Path is Data:
  Path{name: String, shape: P.Shape}

def UI() -> Type:
  Tree(Branch, Path)

def axis(layout: P.Layout) -> P.Axis:
  match layout:
    case P.Layout{axis, gap, pad}: axis

def children(ui: P.UI) -> List<UI()>:
  match ui:
    case P.Last{}: []
    case P.Leaf{name, shape, width, height, align, next}:
      Tip{Path{name, shape}} <> children(next)
    case P.Node{name, layout, width, height, align, first, next}:
      Fork{Branch{name, axis(layout)}, children(first)} <> children(next)

def lower(ui: P.UI) -> UI():
  Fork{Branch{"", P.Vertical{}}, children(ui)}
