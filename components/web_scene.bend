import ../../f/bend2/std/F/browser/scene.bend as S
import ../../f/bend2/std/F/ui/primitives.bend as P
import ../../f/bend2/std/F/ui/tokens.bend as T

# Bool.pick evaluates both arguments; defer branches that render whole trees.
def choose(condition: Bool, yes: Unit -> String, no: Unit -> String) -> String:
  match condition:
    case True{}: yes(Unit{})
    case False{}: no(Unit{})

# The shared tree names the thread viewport and its contents. Only the browser's
# scroll container differs from the native host; positions and controls stay in F.
def scrolling(+name: String) -> Bool:
  String.starts_with(name, "Scroll content · ") || String.starts_with(name, "button · scroll:") || String.starts_with(name, "button, disabled · scroll:") || String.starts_with(name, "Blocked button · scroll:")

def box_name(b: P.Box) -> String:
  match b:
    case P.Box{name, mark, x, y, width, height, level, layer}: name

def bottom(xs: List<&2, P.Box>) -> U32:
  match xs:
    case []: 0
    case P.Box{+name, mark, x, +y, width, +height, level, layer} <> rest:
      U32.max(Bool.pick(U32, scrolling(name), U32.add(y, height), 0), bottom(rest))

def event_name(+name: String) -> String:
  Bool.pick(String, String.starts_with(name, "button · scroll:"), "button · " ++ String.drop(name, 16n),
    Bool.pick(String, String.starts_with(name, "button, disabled · scroll:"), "button, disabled · " ++ String.drop(name, 26n), name))

def textbox(+name: String, value: String, x: U32, y: U32, width: U32, height: U32, id: U32) -> String:
  "<textarea data-bend-field=\"" ++ S.escape(name) ++ "\" aria-label=\"" ++ S.escape(S.region_label(name)) ++ "\" placeholder=\"" ++ S.escape(S.region_label(name)) ++ "\" rows=\"1\" style=\"position:absolute;box-sizing:border-box;margin:0;border:0;padding:14px 16px;background:transparent;color:" ++ T.text(T.TextRole.Ink{},T.State.Rest{},T.Scheme.Dark{}) ++ ";font:17px/20px system-ui;resize:none;left:" ++ U32.show(x) ++ "px;top:" ++ U32.show(y) ++ "px;width:" ++ U32.show(width) ++ "px;height:" ++ U32.show(height) ++ "px;z-index:" ++ U32.show(id) ++ "\">" ++ S.escape(value) ++ "</textarea>"

def control(b: P.Box, +id: U32, +value: String) -> String:
  match b:
    case P.Box{+name, +mark, +x, +y, +width, +height, +level, +layer}:
      choose(String.starts_with(name, "textbox · "), u => textbox(name, value, x, y, width, height, id),
        u => choose(P.interactive(name) || S.disabled(name), u => S.region_html_in(P.Box{event_name(name), mark, x, y, width, height, level, layer}, id, value, T.Scheme.Dark{}), u => ""))

# Native text editing replaces the drawn field lines, but keeps its container.
def editable_boxes(xs: List<&2, P.Box>, +hidden: Bool, +depth: U32) -> List<&2, P.Box>:
  match xs:
    case []: []
    case +box <> rest:
      match box:
        case P.Box{+name, +mark, +x, +y, +width, +height, +level, +layer}:
          +inside = hidden && U32.is_gt(level, depth)
          +field = String.eq(name, "Field text")
          +tail = editable_boxes(rest, inside || field, Bool.pick(U32, field, level, depth))
          Bool.pick(List<&2, P.Box>, inside || field, tail, P.Box{name, mark, x, y, width, height, level, layer} <> tail)

def next_value(xs: List<&2, P.Box>) -> String:
  match xs:
    case []: ""
    case P.Box{name, mark, x, y, width, height, level, layer} <> rest: S.value_of(name)

def boxes(xs: List<&2, P.Box>, +scroll: Bool, +id: U32) -> String:
  match xs:
    case []: ""
    case +box <> +rest:
      choose(Bool.not(Bool.xor(scrolling(box_name(box)), scroll)),
        u => S.box_at_in(box, id, T.Scheme.Dark{}) ++ control(box, id, next_value(rest)), u => "") ++ boxes(rest, scroll, U32.inc(id))

def thread(+xs: List<&2, P.Box>, view: P.Box) -> String:
  match view:
    case P.Box{name, mark, +x, +y, +width, +height, level, layer}:
      "<div id=\"dot-thread\" role=\"log\" aria-label=\"Conversation\" tabindex=\"0\" style=\"position:absolute;overflow:auto;isolation:isolate;overscroll-behavior:contain;left:" ++ U32.show(x) ++ "px;top:" ++ U32.show(y) ++ "px;width:" ++ U32.show(width) ++ "px;height:" ++ U32.show(height) ++ "px\"><div style=\"position:relative;min-height:100%;height:" ++ U32.show(U32.sub(bottom(xs), y)) ++ "px\"><div style=\"position:absolute;left:-" ++ U32.show(x) ++ "px;top:calc(max(0px, 100% - " ++ U32.show(U32.sub(bottom(xs), y)) ++ "px) - " ++ U32.show(y) ++ "px)\">" ++ boxes(xs, True{}, 0) ++ "</div></div></div>"

def ordered(xs: List<&2, P.Box>, +all: List<&2, P.Box>, +id: U32) -> String:
  match xs:
    case []: ""
    case +box <> +rest:
      choose(String.eq(box_name(box), "Scroll viewport · Conversation"), u => thread(all, box),
        u => choose(scrolling(box_name(box)), u => "", u => S.box_at_in(box, id, T.Scheme.Dark{}) ++ control(box, id, next_value(rest)))) ++ ordered(rest, all, U32.inc(id))

def html_boxes(size: P.Size, +xs: List<&2, P.Box>) -> String:
  S.html_frame(size, ordered(xs, xs, 0))

def html(+tree: P.UI) -> String:
  html_boxes(P.size(tree), editable_boxes(S.placed(P.size(tree), tree), False{}, 0))
