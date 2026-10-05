import ../../../bend2/std/F/ui/kit.bend as K
import ../../../bend2/std/F/ui/primitives.bend as P
import ../../../bend2/std/F/ui/tokens.bend as T

# The accepted conversation components use the Mac window's content size.
def width() -> U32: 1000
def height() -> U32: 760
def margin() -> U32: 32
def box(+w: U32) -> U32: U32.sub(U32.max(w, 240), U32.mul(2, margin()))
def body_y() -> U32: 96
def box_h(+h: U32) -> U32: U32.sub(U32.max(h, 200), U32.add(body_y(), 24))
def header(+w: U32) -> P.UI:
  +bw = box(w)
  K.header_tree(K.Header{P.layout("banner · Dot", P.Depth{}, 0, 0, bw, 48, P.Leading{}, [
    K.backdrop(bw, 48),
    K.aligned(K.button_tree(K.glass_button(K.Intent.Menu{})), P.Leading{}),
    K.aligned(K.badge_tree(K.badge("Dot")), P.Middle{}),
    P.layout("Right", P.Vertical{}, 0, 0, bw, 48, P.Leading{}, [
      K.aligned(K.button_tree(K.glass_button(K.Intent.Call{})), P.Trailing{})])])})
def item(line: K.Line, +w: U32) -> K.Item:
  match line:
    case K.Line{K.Role.Mine{}, text}: K.Said{K.bubble(K.Role.Mine{}, K.Delivery.Sent{}, K.Said.Words{text}, K.Presence.Shown{}, K.content_width(box(w)))}
    case K.Line{K.Role.Near{}, text}: K.Said{K.bubble(K.Role.Near{}, Unit{}, K.Said.Words{text}, K.Presence.Shown{}, K.content_width(box(w)))}
def items(xs: List<&2, K.Line>, +w: U32) -> List<&2, K.Item>:
  match xs:
    case []: []
    case x <> rest: item(x, w) <> items(rest, w)
# A compact thread shows a preview of a very long message; the full text
# and all previous messages remain readable in the conversation sheet.
def preview(line: K.Line) -> K.Line:
  match line:
    case K.Line{role, +text}:
      K.Line{role, Bool.pick(String, Nat.is_gt(String.length(text), 180n), String.take(text, 180n) ++ "…", text)}
def previews(xs: List<&2, K.Line>, +w: U32) -> List<&2, K.Item>:
  match xs:
    case []: []
    case x <> rest: item(preview(x), w) <> previews(rest, w)
def blocked(+name: String) -> String:
  Bool.pick(String, String.starts_with(name, "button · ") || String.starts_with(name, "textbox · "), "Blocked " ++ name, name)
def inactive(t: P.UI) -> P.UI:
  match t:
    case P.Last{}: P.Last{}
    case P.Leaf{name, shape, w, h, align, next}: P.Leaf{blocked(name), shape, w, h, align, inactive(next)}
    case P.Node{name, lay, w, h, align, first, next}: P.Node{blocked(name), lay, w, h, align, inactive(first), inactive(next)}
def has_layers(xs: List<&2, P.UI>) -> Bool:
  match xs:
    case []: False{}
    case _: True{}
def history_view(history: List<&2, K.Line>, +w: U32, +h: U32) -> P.UI:
  +inner = K.content_width(box(w))
  +thread = K.thread_tree(K.thread(K.calm(K.Ready{items(history, w)}, K.Typing.Hidden{}), inner))
  +full_h = U32.max(h, U32.add(K.height(thread), 136))
  P.layout("Dot conversation", P.Depth{}, 0, 0, w, full_h, P.Leading{}, [
    K.placed_at("Conversation history", U32.div(U32.sub(w, inner), 2), 24,
      P.layout("History column", P.Vertical{}, 24, 0, inner, 0, P.Leading{}, [
        K.sheet_top("Conversación", inner), thread]))])
# Keep the latest whole bubbles that fit below the header so the composer
# stays reachable after a long conversation or a wrapped message.
def fits(+xs: List<&2, K.Item>, +room: U32, +w: U32) -> List<&2, K.Item>:
  match xs:
    case []: []
    case x <> rest:
      Bool.pick(List<&2, K.Item>, U32.is_le(K.height(K.thread_tree(K.thread(K.calm(K.Ready{xs}, K.Typing.Hidden{}), box(w)))), room), xs, fits(rest, room, w))
def dialog_w(+w: U32) -> U32: U32.min(480, box(w))
def dialog(+title: String, content: List<&2, P.UI>, +w: U32, +h: U32) -> P.UI:
  +pw = dialog_w(w)
  +panel = P.layout("Dialog content", P.Vertical{}, 16, 20, pw, 0, P.Leading{},
    K.append_trees([K.sheet_top(title, U32.sub(pw, 40))], content))
  +ph = K.height(panel)
  P.layout("dialog · " ++ title, P.Depth{}, 0, 0, w, h, P.Leading{}, [
    K.scrim(w, h),
    K.placed_at("Panel", U32.div(U32.sub(w, pw), 2), U32.div(U32.sub(U32.max(h, ph), ph), 2),
      P.layout("Dialog panel", P.Depth{}, 0, 0, pw, ph, P.Leading{}, [
        K.filled("Container", T.SurfaceRole.Raised{}, pw, ph, P.Corner{24}, K.edge(K.hairline())), panel]))])
def conversation(+placeholder: String, +draft: String, history: List<&2, K.Line>, +focus: K.Focus, +layers: List<&2, P.UI>, +w: U32, +h: U32) -> P.UI:
  +room = K.thread_room(placeholder, box(w), box_h(h), draft, focus, K.AttachMenu.Closed{})
  +shown = fits(previews(history, w), room, w)
  +body = K.conversation_tree(K.conversation(placeholder, box(w), box_h(h), K.Settled{}, K.SettledState{K.Ready{shown}, draft, focus, K.AttachMenu.Closed{}}))
  +base = P.layout("Dot", P.Depth{}, 0, 0, w, h, P.Leading{}, [
    K.placed_at("Header", margin(), 16, header(w)),
    K.placed_at("Body", margin(), body_y(), body)])
  P.layout("Dot", P.Depth{}, 0, 0, w, h, P.Leading{}, K.append_trees([Bool.pick(P.UI, has_layers(layers), inactive(base), base)], layers))
