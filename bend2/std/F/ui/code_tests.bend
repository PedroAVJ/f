import Base
import ./code.bend as C
import ./kit.bend as K
import ./primitives.bend as P
import ./tokens.bend as T
import ../browser/scene.bend as Scene

def joined(xs: List<&2, C.Span>) -> String:
  match xs:
    case []: ""
    case C.Span{kind, text} <> rest: text ++ joined(rest)
def kind(xs: List<&2, C.Span>) -> String:
  match xs:
    case C.Span{value, text} <> rest: value
    case _: ""
def aa(value: T.Contrast) -> Bool:
  match value:
    case T.Contrast{fg, bg, scheme, state, use, ratio, passed, aaa}: passed
def checks() -> List<&2, Bool>:
  [String.eq(joined(C.spans("Name : Type # note")), "Name : Type # note"), String.eq(kind(C.spans("Name : Type")), "name"), String.eq(kind(C.spans("Type")), "type"), String.eq(kind(C.spans("def answer")), "keyword"), String.eq(kind(C.spans("42")), "literal"), String.eq(kind(C.spans("# comment")), "comment"), String.eq(kind(C.spans("\"# literal\"")), "literal"), String.eq(joined(C.window("Name : Type", 2n, 5n)), "me : "), String.eq(kind(C.window("\"long quoted text\"", 5n, 6n)), "literal"), String.eq(C.normalized("a\tb\r"), "a    b"), U32.is_le(K.width(C.page("a very long line with words", 0, 80)), 80), String.contains(Scene.html_in(C.page("<script>", 0, 320), T.Scheme.Dark{}), "&lt;"), String.contains(Scene.canvas(C.page("Name : Type", 0, 320)), "monospace"), Bool.not(String.contains(Scene.canvas(K.words("Normal", "Normal", K.body(), K.ink(), P.Leading{})), "monospace")), List.all(&2, T.Contrast, aa, T.text_pairs(T.text_roles(), T.Scheme.Dark{}, T.State.Rest{})), List.all(&2, T.Contrast, aa, T.text_pairs(T.text_roles(), T.Scheme.Light{}, T.State.Rest{}))]
def main() -> IO(Unit): IO.print(Bool.pick(String, List.all(&2, Bool, x => x, checks()), "PASS source lexer, paging, font, escaping, and contrast", "FAIL source renderer"))

#| PASS source lexer, paging, font, escaping, and contrast
