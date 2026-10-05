import ../../f/bend2/std/F/ui/kit.bend as K
import ../../f/bend2/std/F/ui/primitives.bend as P
import ../../f/bend2/std/F/ui/tokens.bend as T
import ../../f/bend2/std/F/ui/metrics.bend as M

def width() -> U32: 390
def height() -> U32: 844
def margin() -> U32: 16
def box(+w: U32) -> U32: U32.sub(U32.max(w, 320), U32.mul(2, margin()))
def body_y() -> U32: 104
def box_h(+h: U32) -> U32: U32.sub(U32.max(h, 240), U32.add(body_y(), 20))
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
def previews(xs: List<&2, K.Line>, +w: U32) -> List<&2, K.Item>:
  match xs:
    case []: []
    case K.Line{role, +text} <> rest:
      item(K.Line{role, Bool.pick(String, Nat.is_gt(String.length(text), 180n), String.take(text, 180n) ++ "…", text)}, w) <> previews(rest, w)
def fits(+xs: List<&2, K.Item>, +room: U32, +w: U32) -> List<&2, K.Item>:
  match xs:
    case []: []
    case x <> rest:
      Bool.pick(List<&2, K.Item>, U32.is_le(K.height(K.thread_tree(K.thread(K.calm(K.Ready{xs}, K.Typing.Hidden{}), box(w)))), room), xs, fits(rest, room, w))
def blocked(+name: String) -> String:
  Bool.pick(String, String.starts_with(name, "button · ") || String.starts_with(name, "textbox · "), "Blocked " ++ name, name)
def inactive(t: P.UI) -> P.UI:
  match t:
    case P.Last{}: P.Last{}
    case P.Leaf{name, shape, w, h, align, next}: P.Leaf{blocked(name), shape, w, h, align, inactive(next)}
    case P.Node{name, lay, w, h, align, first, next}: P.Node{blocked(name), lay, w, h, align, inactive(first), inactive(next)}
def sending_name(+name: String, +disabled: Bool) -> String:
  Bool.pick(String, disabled && String.eq(name, "button · Enviar"), "button, disabled · Enviar", name)
def disable_send(t: P.UI, +disabled: Bool) -> P.UI:
  match t:
    case P.Last{}: P.Last{}
    case P.Leaf{name, shape, w, h, align, next}: P.Leaf{sending_name(name, disabled), shape, w, h, align, disable_send(next, disabled)}
    case P.Node{name, lay, w, h, align, first, next}: P.Node{sending_name(name, disabled), lay, w, h, align, disable_send(first, disabled), disable_send(next, disabled)}
def has_layers(xs: List<&2, P.UI>) -> Bool:
  match xs:
    case []: False{}
    case _: True{}
def dialog_w(+w: U32) -> U32: U32.min(480, box(w))
def named_button(t: P.UI, +label: String) -> P.UI:
  match t:
    case P.Node{name, lay, w, h, align, first, next}: P.Node{"button · " ++ label, lay, w, h, align, first, next}
    case other: other
def thread_button(id: String, +title: String, +w: U32) -> P.UI:
  named_button(K.button_tree(K.say(K.ButtonKind.Quiet{}, M.truncate(Bool.pick(String, String.is_empty(title), "Conversación", title), U32.sub(dialog_w(w), 68), K.label_type()))), "thread:" ++ id)
def history_view(history: List<&2, K.Line>, +more: Bool, latest: Bool, +w: U32, +h: U32) -> P.UI:
  +inner = K.content_width(box(w))
  +thread = K.thread_tree(K.thread(K.calm(K.Ready{items(history, w)}, K.Typing.Hidden{}), inner))
  +navigation = P.layout("History pages", P.Horizontal{}, 8, 0, inner, 0, P.Leading{}, K.append_trees(
    Bool.pick(List<&2, P.UI>, more, [K.button_tree(K.say(K.ButtonKind.Quiet{}, "Anteriores"))], []),
    Bool.pick(List<&2, P.UI>, latest, [], [K.button_tree(K.say(K.ButtonKind.Quiet{}, "Recientes"))])))
  +column = P.layout("History column", P.Vertical{}, 24, 0, inner, 0, P.Leading{}, [K.sheet_top("Conversación", inner), navigation, thread])
  +full_h = U32.max(h, U32.add(K.height(column), 32))
  P.layout("Dot conversation", P.Depth{}, 0, 0, w, full_h, P.Leading{}, [
    K.placed_at("Conversation history", U32.div(U32.sub(w, inner), 2), 16,
      column)])
def dialog(+title: String, content: List<&2, P.UI>, +w: U32, +h: U32) -> P.UI:
  +pw = dialog_w(w)
  +panel = P.layout("Dialog content", P.Vertical{}, 12, 16, pw, 0, P.Leading{},
    K.append_trees([K.sheet_top(title, U32.sub(pw, 32))], content))
  +ph = K.height(panel)
  P.layout("dialog · " ++ title, P.Depth{}, 0, 0, w, U32.max(h, ph), P.Leading{}, [
    K.scrim(w, U32.max(h, ph)),
    K.placed_at("Panel", U32.div(U32.sub(w, pw), 2), U32.div(U32.sub(U32.max(h, ph), ph), 2),
      P.layout("Dialog panel", P.Depth{}, 0, 0, pw, ph, P.Leading{}, [
        K.filled("Container", T.SurfaceRole.Raised{}, pw, ph, P.Corner{24}, K.edge(K.hairline())), panel]))])
def conversation(+placeholder: String, +draft: String, history: List<&2, K.Line>, +focus: K.Focus, +status: String, +disabled: Bool, +layers: List<&2, P.UI>, +w: U32, +h: U32) -> P.UI:
  +room = K.thread_room(placeholder, box(w), box_h(h), draft, focus, K.AttachMenu.Closed{})
  +shown = fits(previews(history, w), room, w)
  +body = disable_send(K.conversation_tree(K.conversation(placeholder, box(w), box_h(h), K.Settled{}, K.SettledState{K.Ready{shown}, draft, focus, K.AttachMenu.Closed{}})), disabled)
  +base = P.layout("Dot", P.Depth{}, 0, 0, w, h, P.Leading{}, [
    K.placed_at("Header", margin(), 16, header(w)),
    K.placed_at("Connection", margin(), 76,
      K.words("status · " ++ status, M.truncate(status, box(w), K.small_type()), K.small_type(), K.muted(), P.Leading{})),
    K.placed_at("Body", margin(), body_y(), body)])
  P.layout("Dot", P.Depth{}, 0, 0, w, h, P.Leading{}, K.append_trees([Bool.pick(P.UI, has_layers(layers), inactive(base), base)], layers))
