import Base
import ../ui/components.bend as C
import ./scene.bend as S
import ../ui/symbols.bend as D
import ../ui/nearling.bend as N

def disabled(b: Bool) -> String: Bool.pick(String, b, " disabled", "")
def field(kind: String, +label: String, +value: String, placeholder: String) -> String:
  match kind:
    case "evidence": "<figure><img class=\"evidence\" loading=\"lazy\" alt=\"" ++ S.escape(label) ++ "\" src=\"" ++ S.escape(value) ++ "\"></figure>"
    case "photo": "<label class=\"photo\">" ++ S.escape(label) ++ "<input type=\"file\" accept=\"image/jpeg,image/png,image/webp\" capture=\"environment\" data-bend-upload=\"" ++ S.escape(value) ++ "\"></label>"
    case _: "<label>" ++ S.escape(label) ++ "<input data-bend-field=\"" ++ S.escape(kind) ++ "\" value=\"" ++ S.escape(value) ++ "\" placeholder=\"" ++ S.escape(placeholder) ++ "\"></label>"
def glyph(d: D.Drawing) -> String:
  match d:
    case D.Drawing{name, x, y, +width, shapes}: "<svg viewBox=\"" ++ S.escape(x) ++ " " ++ S.escape(y) ++ " " ++ S.escape(width) ++ " " ++ S.escape(width) ++ "\" width=\"24\" height=\"24\">" ++ S.symbol_shapes(shapes) ++ "</svg>"
def sprite(f: N.Frame) -> String:
  match f:
    case N.Frame{id, +asset, animation, time, reduced, row, column, x, y, +width, +height, sheet_width, sheet_height}:
      Bool.pick(String, String.is_empty(asset), "", "<svg class=\"sprite\" role=\"img\" aria-label=\"Near\" width=\"" ++ U32.show(width) ++ "\" height=\"" ++ U32.show(height) ++ "\" viewBox=\"" ++ U32.show(x) ++ " " ++ U32.show(y) ++ " " ++ U32.show(width) ++ " " ++ U32.show(height) ++ "\" preserveAspectRatio=\"none\"><image href=\"" ++ S.escape(asset) ++ "\" width=\"" ++ U32.show(sheet_width) ++ "\" height=\"" ++ U32.show(sheet_height) ++ "\"/></svg>")
type Render is Data:
  One{ui: C.UI}
  Many{uis: List<&2, C.UI>}
def go(fuel: Nat, r: Render) -> String:
  match fuel:
    case 0n: "<p>Demasiados componentes.</p>"
    case 1n+ +p:
      match r:
        case Many{Nil{}}: ""
        case Many{Con{c, rest}}: go(p, One{c}) ++ go(p, Many{rest})
        case One{C.Group{kind, cs}}: "<section class=\"" ++ S.escape(kind) ++ "\">" ++ go(p, Many{cs}) ++ "</section>"
        case One{C.Text{kind, value}}: "<p class=\"" ++ S.escape(kind) ++ "\">" ++ S.escape(value) ++ "</p>"
        case One{C.Bubble{id, role, text}}: "<article class=\"bubble " ++ S.escape(role) ++ "\">" ++ S.escape(text) ++ "</article>"
        case One{C.Field{kind, label, value, placeholder}}: field(kind, label, value, placeholder)
        case One{C.Button{kind, label, action, id, off}}: "<button type=\"button\" class=\"" ++ S.escape(kind) ++ "\" data-bend-event=\"" ++ S.escape(action) ++ "\"" ++ disabled(off) ++ ">" ++ S.escape(label) ++ "</button>"
        case One{C.Person{id, username}}: "<p>" ++ S.escape(username) ++ "</p>"
        case One{C.TaskRow{id, title, done}}: "<p>" ++ S.escape(title) ++ Bool.pick(String, done, " ✓", "") ++ "</p>"
        case One{C.Symbol{C.Glyph{drawing}}}: glyph(drawing)
        case One{C.Symbol{C.Sprite{frame}}}: sprite(frame)
def html(c: C.UI) -> String: go(4096n, One{c})
