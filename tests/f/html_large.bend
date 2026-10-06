import Base
import ../../bend2/std/F/ui/primitives.bend as P
import ../../bend2/std/F/browser/scene.bend as Scene

def body(n: Nat, acc: String) -> String:
  match n:
    case 0n: acc
    case 1n+rest: body(rest, SCon{Chr{120}, acc})
def intact(+s: String, count: U32) -> Bool:
  match s:
    case SCon{Chr{120}, rest}: intact(rest, U32.inc(count))
    case _: U32.is_eq(count, 262144) && String.eq(s, "</div>")
def main() -> Bool:
  +frame = Scene.html_frame(P.Size{390, 844, 0}, body(262144n, ""))
  String.starts_with(frame, "<div style=\"position:relative;width:390px;height:844px\">") && intact(String.drop(frame, 56n), 0)
#|True
