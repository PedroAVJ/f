import Base
import ./kit.bend as K
import ./primitives.bend as P
import ./tokens.bend as T

# Lexical highlighting only: source is never parsed as an executable module.
type Span is Data:
  Span{kind: String, text: String}
type Token is Data:
  Token{span: Span, rest: String}

def letter(+c: U32) -> Bool:
  (U32.is_ge(c, 65) && U32.is_le(c, 90)) || (U32.is_ge(c, 97) && U32.is_le(c, 122)) || U32.is_eq(c, 95) || U32.is_ge(c, 128)
def digit(+c: U32) -> Bool: U32.is_ge(c, 48) && U32.is_le(c, 57)
def word_char(+c: U32) -> Bool: letter(c) || digit(c) || U32.is_eq(c, 46)
def choose(-A: Type, condition: Bool, yes: Unit -> A, no: Unit -> A) -> A:
  match condition:
    case True{}: yes(Unit{})
    case False{}: no(Unit{})
def word(+s: String, +acc: String) -> (String & String):
  match s:
    case SNil{}: (String.reverse(acc), "")
    case SCon{+char, rest}:
      match char:
        case Chr{code}: choose(String & String, word_char(code), u => word(rest, SCon{char, acc}), u => (String.reverse(acc), s))
def quoted(s: String, +quote: U32, +escaped: Bool, acc: String) -> (String & String):
  match s:
    case SNil{}: (String.reverse(acc), "")
    case SCon{+char, +rest}:
      match char:
        case Chr{+code}:
          +next : String = SCon{char, acc}
          choose(String & String, Bool.not(escaped) && U32.is_eq(code, quote), u => (String.reverse(next), rest), u => quoted(rest, quote, Bool.not(escaped) && U32.is_eq(code, 92), next))
def keyword(+s: String) -> Bool:
  String.eq(s, "import") || String.eq(s, "def") || String.eq(s, "type") || String.eq(s, "is") || String.eq(s, "Data") || String.eq(s, "match") || String.eq(s, "case") || String.eq(s, "do") || String.eq(s, "let") || String.eq(s, "with") || String.eq(s, "return") || String.eq(s, "law")
def first_code(s: String) -> U32:
  match s:
    case SNil{}: 0
    case SCon{Chr{code}, rest}: code
def word_kind(+s: String, rest: String) -> String:
  +first = first_code(s)
  Bool.pick(String, digit(first), "literal", Bool.pick(String, keyword(s), "keyword", Bool.pick(String, String.starts_with(String.trim(rest), ":"), "name", Bool.pick(String, U32.is_ge(first, 65) && U32.is_le(first, 90), "type", "plain"))))
def word_token(pair: String & String) -> Token:
  match pair:
    case (+text, +rest): Token{Span{word_kind(text, rest), text}, rest}
def literal_token(pair: String & String) -> Token:
  match pair:
    case (text, rest): Token{Span{"literal", text}, rest}
def spaces(+s: String, acc: String) -> (String & String):
  match s:
    case SCon{Chr{32}, rest}: spaces(rest, SCon{Chr{32}, acc})
    case _: (String.reverse(acc), s)
def space_token(pair: String & String) -> Token:
  match pair:
    case (text, rest): Token{Span{"plain", text}, rest}
def token(+s: String) -> Token:
  match s:
    case SNil{}: Token{Span{"plain", ""}, ""}
    case SCon{+char, +rest}:
      match char:
        case Chr{+code}:
          match code:
            case 35: Token{Span{"comment", s}, ""}
            case 34: literal_token(quoted(rest, code, False{}, SCon{char, SNil{}}))
            case 39: literal_token(quoted(rest, code, False{}, SCon{char, SNil{}}))
            case 32: space_token(spaces(rest, " "))
            case _: choose(Token, word_char(code), u => word_token(word(rest, SCon{char, SNil{}})), u => Token{Span{"punctuation", SCon{char, SNil{}}}, rest})
def token_value(value: Token) -> Span:
  match value:
    case Token{span, rest}: span
def token_rest(value: Token) -> String:
  match value:
    case Token{span, rest}: rest
def spans_go(fuel: Nat, +s: String) -> List<&2, Span>:
  match fuel:
    case 0n: []
    case 1n+remaining:
      match s:
        case SNil{}: []
        case _:
          +next = token(s)
          token_value(next) <> spans_go(remaining, token_rest(next))
def spans(+s: String) -> List<&2, Span>: spans_go(String.length(s), s)
def normalized(s: String) -> String:
  match s:
    case SNil{}: ""
    case SCon{Chr{9}, rest}: "    " ++ normalized(rest)
    case SCon{Chr{13}, rest}: normalized(rest)
    case SCon{char, rest}: SCon{char, normalized(rest)}
def color(kind: String) -> T.TextRole:
  match kind:
    case "keyword": T.TextRole.CodeKeyword{}
    case "type": T.TextRole.CodeType{}
    case "name": T.TextRole.CodeName{}
    case "literal": T.TextRole.CodeLiteral{}
    case "comment": T.TextRole.Muted{}
    case "punctuation": T.TextRole.Muted{}
    case _: T.TextRole.Ink{}
def text_type() -> P.TextType: P.TextType{"Code", 14, 400}
def advance(n: U32) -> U32: U32.div(U32.mul(n, 8428), 1000)
def columns(w: U32) -> U32: U32.max(1, U32.div(U32.mul(w, 1000), 8428))
def span_view(+kind: String, +text: String, +at: U32) -> P.UI:
  +width = U32.sub(advance(U32.add(at, U32.from_nat(String.length(text)))), advance(at))
  K.placed_at("Code run", advance(at), 0, P.text("Code " ++ kind, text, text_type(), color(kind), width, 20, P.Leading{}))
def line_view(items: List<&2, P.UI>, w: U32) -> P.UI:
  P.layout("Code line", P.Depth{}, 0, 0, w, 20, P.Leading{}, items)
def span_size(xs: List<&2, Span>) -> Nat:
  match xs:
    case []: 0n
    case Span{kind, text} <> rest: Nat.add(String.length(text), span_size(rest))
def rows_go(fuel: Nat, xs: List<&2, Span>, +w: U32, +at: U32, +items: List<&2, P.UI>) -> List<&2, P.UI>:
  match fuel:
    case 0n: [line_view(items, w)]
    case Succ{+remaining}:
      match xs:
        case []: [line_view(items, w)]
        case Span{+kind, +text} <> +rest:
          +length = U32.from_nat(String.length(text))
          +room = U32.sub(columns(w), at)
          +head = String.take(text, U32.to_nat(room))
          +tail = String.drop(text, U32.to_nat(room))
          choose(List<&2, P.UI>, U32.is_le(length, room), u => rows_go(remaining, rest, w, U32.add(at, length), K.append_trees(items, [span_view(kind, text, at)])), u => line_view(K.append_trees(items, [span_view(kind, head, at)]), w) <> rows_go(remaining, Span{kind, tail} <> rest, w, 0, []))
def rows(+xs: List<&2, Span>, w: U32) -> List<&2, P.UI>:
  rows_go(Nat.add(1n, Nat.mul(2n, Nat.add(span_size(xs), List.length(&2, Span, xs)))), xs, w, 0, [])
def source_lines(xs: List<&2, String>, +w: U32) -> List<&2, P.UI>:
  match xs:
    case []: []
    case line <> rest: K.append_trees(rows(spans(normalized(line)), w), source_lines(rest, w))
def view(text: String, +w: U32) -> P.UI:
  P.layout("Read-only source", P.Vertical{}, 0, 0, w, 0, P.Leading{}, source_lines(String.split(text, '\n'), w))
def preview_lines(n: Nat, xs: List<&2, String>) -> List<&2, String>:
  match n:
    case 0n: []
    case 1n+remaining:
      match xs:
        case []: []
        case line <> rest: line <> preview_lines(remaining, rest)
def preview_with_limit(text: String, limit: U32, +w: U32) -> P.UI:
  P.layout("Source preview", P.Vertical{}, 0, 0, w, 0, P.Leading{}, source_lines(preview_lines(6n, String.split(String.take(normalized(text), U32.to_nat(limit)), '\n')), w))

def clipped(xs: List<&2, Span>, +start: Nat, +size: Nat) -> List<&2, Span>:
  match xs:
    case []: []
    case Span{+kind, +text} <> +rest:
      +length = String.length(text)
      choose(List<&2, Span>, Nat.is_eq(size, 0n), u => [], u => choose(List<&2, Span>, Nat.is_ge(start, length), u => clipped(rest, Nat.sub(start, length), size), u => Span{kind, String.take(String.drop(text, start), size)} <> clipped(rest, 0n, Nat.sub(size, Nat.sub(length, start)))))
def page_lines(xs: List<&2, String>, +start: Nat, +size: Nat, +w: U32) -> List<&2, P.UI>:
  match xs:
    case []: []
    case +line <> +rest:
      +length = Nat.add(String.length(line), 1n)
      choose(List<&2, P.UI>, Nat.is_eq(size, 0n), u => [], u => choose(List<&2, P.UI>, Nat.is_ge(start, length), u => page_lines(rest, Nat.sub(start, length), size, w), u => K.append_trees(rows(clipped(spans(line), start, size), w), page_lines(rest, 0n, Nat.sub(size, Nat.sub(length, start)), w))))
def page_size() -> U32: 2048
def page(+text: String, offset: U32, +w: U32) -> P.UI:
  P.layout("Read-only source", P.Vertical{}, 0, 0, w, 0, P.Leading{}, page_lines(String.split(normalized(text), '\n'), U32.to_nat(offset), U32.to_nat(page_size()), w))
