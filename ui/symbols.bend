import Base

# Approved appearance; this minimal internal data contract remains provisional.
type Symbol is Data:
  Send{}
  Search{}
  Telephone{}
  Plus{}
type Shape is Data:
  Path{data: String}
  Circle{x: String, y: String, radius: String}
type Drawing is Data:
  Drawing{name: String, x: String, y: String, width: String, shapes: List<&2, Shape>}

def drawing(symbol: Symbol) -> Drawing:
  match symbol:
    case Send{}: Drawing{"Send", "-80", "-64", "3", [Path{"M12 22V2M3 11L12 2L21 11"}]}
    case Search{}: Drawing{"Search", "80", "-64", "2.3", [Circle{"10", "10", "6.8"}, Path{"M15 15L21.5 21.5"}]}
    case Telephone{}: Drawing{"Telephone", "-80", "64", "2.3", [Path{"M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.12.96.35 1.9.69 2.79a2 2 0 0 1-.45 2.11L8.09 9.89a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.89.34 1.83.57 2.79.69A2 2 0 0 1 22 16.92z"}]}
    case Plus{}: Drawing{"Plus", "80", "64", "2.3", [Path{"M12 4V20M4 12H20"}]}

def canvas() -> List<&2, Drawing>:
  [drawing(Send{}), drawing(Search{}), drawing(Telephone{}), drawing(Plus{})]
def shapes_markup(shapes: List<&2, Shape>) -> String:
  match shapes:
    case Nil{}: ""
    case Con{Path{data}, tail}: "<path d=\"" ++ data ++ "\"/>" ++ shapes_markup(tail)
    case Con{Circle{x, y, radius}, tail}: "<circle cx=\"" ++ x ++ "\" cy=\"" ++ y ++ "\" r=\"" ++ radius ++ "\"/>" ++ shapes_markup(tail)
def svg_drawing(draw: Drawing) -> String:
  match draw:
    case Drawing{name, x, y, width, shapes}:
      "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" width=\"18\" height=\"18\" fill=\"none\" stroke=\"#f6f7f8\" stroke-width=\"" ++ width ++ "\" stroke-linecap=\"round\" stroke-linejoin=\"round\" aria-hidden=\"true\" focusable=\"false\">" ++ shapes_markup(shapes) ++ "</svg>"
def svg(symbol: Symbol) -> String:
  svg_drawing(drawing(symbol))
