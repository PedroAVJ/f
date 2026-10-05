import ../../f/bend2/std/F/ui/kit.bend as K
import ../../f/bend2/std/F/ui/primitives.bend as P
import ../../f/bend2/std/F/ui/metrics.bend as M
import ../../f/bend2/std/F/ui/tokens.bend as T

def same(a: Char, b: Char) -> Bool:
  match a b:
    case Chr{ac} Chr{bc}: U32.is_eq(ac, bc)

type Token is Data:
  Word{text: String, strong: Bool, href: String, gap: Bool}
  Break{}
type Cut is Data:
  Cut{head: String, tail: String, found: Bool}
def label_cut(s: String, head: String) -> Cut:
  match s:
    case SNil{}: Cut{head, "", False{}}
    case SCon{Chr{93}, rest}: Cut{head, rest, True{}}
    case SCon{c, rest}: label_cut(rest, head ++ SCon{c, ""})
def url_cut(s: String, head: String) -> Cut:
  match s:
    case SNil{}: Cut{head, "", False{}}
    case SCon{Chr{41}, rest}: Cut{head, rest, True{}}
    case SCon{c, rest}: url_cut(rest, head ++ SCon{c, ""})
def push(+text: String, strong: Bool, href: String, gap: Bool, +tokens: List<&2, Token>) -> List<&2, Token>:
  Bool.pick(List<&2, Token>, String.is_empty(text), tokens, Word{text, strong, href, gap} <> tokens)
def link_words(xs: List<&2, String>, +strong: Bool, +href: String, gap: Bool, tokens: List<&2, Token>) -> List<&2, Token>:
  match xs:
    case []: tokens
    case word <> rest: link_words(rest, strong, href, True{}, push(word, strong, href, gap, tokens))
type Scan is Data:
  Scan{rest: String, word: String, strong: Bool, code: Bool, gap: Bool, tokens: List<&2, Token>}
def link_apply(valid: Bool, label: String, result: Cut, original: Scan) -> Scan:
  match valid result original:
    case True{} Cut{url, tail, found} Scan{rest, +word, +strong, code, +gap, tokens}:
      Scan{tail, "", strong, code, False{}, link_words(String.split(label, Chr{32}), strong, url, Bool.pick(Bool, String.is_empty(word), gap, False{}), push(word, strong, "", gap, tokens))}
    case _ _ Scan{rest, word, strong, code, gap, tokens}: Scan{rest, word ++ "[", strong, code, gap, tokens}
def link_url(label: String, result: Cut, original: Scan) -> Scan:
  match result:
    case Cut{+url, tail, +found}: link_apply(found && (String.starts_with(url, "https://") || String.starts_with(url, "http://")), label, Cut{url, tail, found}, original)
def link_label(result: Cut, original: Scan) -> Scan:
  match result:
    case Cut{label, SCon{Chr{40}, tail}, True{}}: link_url(label, url_cut(tail, ""), original)
    case _: link_apply(False{}, "", Cut{"", "", False{}}, original)
def step(state: Scan) -> Scan:
  match state:
    case Scan{SNil{}, +word, +strong, +code, +gap, +tokens}: Scan{"", word, strong, code, gap, tokens}
    case Scan{SCon{Chr{10}, +rest}, +word, +strong, +code, +gap, +tokens}: Scan{rest, "", strong, code, False{}, Break{} <> push(word, strong, "", gap, tokens)}
    case Scan{SCon{Chr{32}, +rest}, +word, +strong, +code, +gap, +tokens}: Scan{rest, "", strong, code, True{}, push(word, strong, "", gap, tokens)}
    case Scan{SCon{Chr{9}, +rest}, +word, +strong, +code, +gap, +tokens}: Scan{rest, "", strong, code, True{}, push(word, strong, "", gap, tokens)}
    case Scan{SCon{Chr{13}, +rest}, +word, +strong, +code, +gap, +tokens}: Scan{rest, "", strong, code, True{}, push(word, strong, "", gap, tokens)}
    case Scan{SCon{Chr{96}, +rest}, +word, +strong, +code, +gap, +tokens}: Scan{rest, word, strong, Bool.not(code), gap, tokens}
    case Scan{SCon{Chr{42}, +rest}, +word, +strong, +code, +gap, +tokens}:
      Bool.pick(Scan, Bool.not(code) && String.starts_with(rest, "*"), Scan{String.drop(rest, 1n), "", Bool.not(strong), code, Bool.pick(Bool, String.is_empty(word), gap, False{}), push(word, strong, "", gap, tokens)}, Scan{rest, word ++ "*", strong, code, gap, tokens})
    case Scan{SCon{Chr{91}, +rest}, +word, +strong, +code, +gap, +tokens}:
      Bool.pick(Scan, Bool.not(code), link_label(label_cut(rest, ""), Scan{rest, word, strong, code, gap, tokens}), Scan{rest, word ++ "[", strong, code, gap, tokens})
    case Scan{SCon{+c, +rest}, +word, +strong, +code, +gap, +tokens}: Scan{rest, word ++ SCon{c, ""}, strong, code, gap, tokens}
def scan(fuel: Nat, state: Scan) -> Scan:
  match fuel:
    case 0n: state
    case 1n+n: scan(n, step(state))
def reversed(xs: List<&2, Token>, acc: List<&2, Token>) -> List<&2, Token>:
  match xs:
    case []: acc
    case x <> rest: reversed(rest, x <> acc)
def scanned(state: Scan) -> List<&2, Token>:
  match state:
    case Scan{rest, word, strong, code, gap, tokens}: reversed(push(word, strong, "", gap, tokens), [])
def tokens(+text: String) -> List<&2, Token>: scanned(scan(String.length(text), Scan{text, "", False{}, False{}, False{}, []}))
def font(strong: Bool) -> P.TextType: P.TextType{"Body", 17, Bool.pick(U32, strong, 600, 400)}
def linked(href: String, +copy: P.UI) -> P.UI:
  match href:
    case SNil{}: copy
    case _: P.layout("button · open-url:" ++ href, P.Depth{}, 0, 0, K.width(copy), K.height(copy), P.Leading{}, [copy, K.placed_at("Link underline", 0, U32.sub(K.height(copy), 2), P.rounded("Underline", P.Fill.None{}, K.width(copy), 1, P.Corner{0}, P.Stroke{T.LineRole.Ink{}, T.State.Rest{}, "1"}, P.Leading{}))])
def word_tree(text: String, strong: Bool, href: String) -> P.UI:
  linked(href, K.words("Text", text, font(strong), K.ink(), P.Leading{}))
# Split unbroken identifiers and URLs so no text can widen the message.
def chunks(s: String, +strong: Bool, +href: String, +max: U32, +part: String, +gap: Bool, +acc: List<&2, Token>) -> List<&2, Token>:
  match s:
    case SNil{}: reversed(push(part, strong, href, gap, acc), [])
    case SCon{+c, rest}:
      +next = part ++ SCon{c, ""}
      +full = Bool.not(String.is_empty(part)) && U32.is_gt(M.width(next, font(strong)), max)
      chunks(rest, strong, href, max, Bool.pick(String, full, SCon{c, ""}, next), Bool.pick(Bool, full, False{}, gap), Bool.pick(List<&2, Token>, full, Word{part, strong, href, gap} <> acc, acc))
def bounded(xs: List<&2, Token>, +max: U32) -> List<&2, Token>:
  match xs:
    case []: []
    case Break{} <> rest: Break{} <> bounded(rest, max)
    case Word{text, strong, href, gap} <> rest: List.append(&2, Token, chunks(text, strong, href, max, "", gap, []), bounded(rest, max))
def reverse_trees(xs: List<&2, P.UI>, acc: List<&2, P.UI>) -> List<&2, P.UI>:
  match xs:
    case []: acc
    case x <> rest: reverse_trees(rest, x <> acc)
type Run is Data:
  Run{text: String, strong: Bool, href: String, trees: List<&2, P.UI>}
def flush(text: String, strong: Bool, href: String, trees: List<&2, P.UI>) -> List<&2, P.UI>:
  match text:
    case SNil{}: trees
    case _: word_tree(text, strong, href) <> trees
def run_join(join: Bool, word: String, +bold: Bool, url: String, gap: Bool, run: Run) -> Run:
  match join run:
    case True{} Run{+text, strong, href, trees}: Run{text ++ Bool.pick(String, gap && Bool.not(String.is_empty(text)), " ", "") ++ word, bold, url, trees}
    case False{} Run{text, strong, href, trees}:
      +done = flush(text, strong, href, trees)
      Run{word, bold, url, Bool.pick(List<&2, P.UI>, gap, K.spacer("Word space", M.width(" ", font(bold)), 23, P.Leading{}) <> done, done)}
def run_add(token: Token, run: Run) -> Run:
  match token run:
    case Break{} Run{text, strong, href, trees}: Run{text, strong, href, trees}
    case Word{word, +bold, +url, gap} Run{+text, +strong, +href, trees}:
      run_join((String.eq(Bool.show(bold), Bool.show(strong)) && String.eq(url, href)) || String.is_empty(text), word, bold, url, gap, Run{text, strong, href, trees})
def runs(xs: List<&2, Token>, run: Run) -> Run:
  match xs:
    case []: run
    case x <> rest: runs(rest, run_add(x, run))
def run_trees(run: Run) -> List<&2, P.UI>:
  match run:
    case Run{text, strong, href, trees}: reverse_trees(flush(text, strong, href, trees), [])
def row(xs: List<&2, Token>) -> P.UI:
  P.layout("Text line", P.Horizontal{}, 0, 0, 0, 23, P.Leading{}, run_trees(runs(reversed(xs, []), Run{"", False{}, "", []})))
type Wrap is Data:
  Wrap{line: List<&2, Token>, width: U32, lines: List<&2, P.UI>}
def wrapped_line(wrap: Bool, text: String, strong: Bool, href: String, gap: Bool, word_width: U32, next_width: U32, state: Wrap) -> Wrap:
  match wrap state:
    case True{} Wrap{line, width, lines}: Wrap{[Word{text, strong, href, False{}}], word_width, row(line) <> lines}
    case False{} Wrap{line, width, lines}: Wrap{Word{text, strong, href, gap} <> line, next_width, lines}
def add(token: Token, state: Wrap, max: U32) -> Wrap:
  match token state:
    case Break{} Wrap{line, width, lines}: Wrap{[], 0, row(line) <> lines}
    case Word{+text, +strong, href, +gap} Wrap{line, +width, lines}:
      +space = Bool.pick(U32, U32.is_zero(width) || Bool.not(gap), 0, M.width(" ", font(strong)))
      +word_width = M.width(text, font(strong))
      +next_width = U32.add(U32.add(width, space), word_width)
      wrapped_line(U32.is_gt(next_width, max) && U32.is_gt(width, 0), text, strong, href, gap, word_width, next_width, Wrap{line, width, lines})
def wrap(xs: List<&2, Token>, state: Wrap, +max: U32) -> Wrap:
  match xs:
    case []: state
    case token <> rest: wrap(rest, add(token, state, max), max)
def finish(state: Wrap) -> List<&2, P.UI>:
  match state:
    case Wrap{line, +width, +lines}: reverse_trees(Bool.pick(List<&2, P.UI>, U32.is_zero(width), lines, row(line) <> lines), [])
def rows(+text: String, +max: U32) -> List<&2, P.UI>:
  finish(wrap(bounded(tokens(text), max), Wrap{[], 0, []}, max))
def take_rows(xs: List<&2, P.UI>, done: Bool, +limit: U32) -> List<&2, P.UI>:
  match xs done:
    case _ True{}: []
    case Nil{} False{}: []
    case Con{row, rest} False{}: row <> take_rows(rest, U32.is_zero(U32.sub(limit, 1)), U32.sub(limit, 1))
def first_rows(xs: List<&2, P.UI>, +limit: U32) -> List<&2, P.UI>: take_rows(xs, U32.is_zero(limit), limit)
def row_count(xs: List<&2, P.UI>) -> U32:
  match xs:
    case []: 0
    case row <> rest: U32.add(1, row_count(rest))
def lines(+text: String, +max: U32) -> U32: row_count(rows(text, max))
def preview(text: String, max: U32, limit: U32) -> P.UI:
  P.layout("Message text", P.Vertical{}, 0, 0, 0, 0, P.Leading{}, first_rows(rows(text, max), limit))
def view(+text: String, +max: U32) -> P.UI:
  P.layout("Message text", P.Vertical{}, 0, 0, 0, 0, P.Leading{}, rows(text, max))
