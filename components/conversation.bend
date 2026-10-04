import ../../f/bend2/std/F/ui/kit.bend as K
import ../../f/bend2/std/F/ui/primitives.bend as P
import ../../f/bend2/std/F/ui/tokens.bend as T

# The Header, Conversation, Bubble and Composer from the accepted UI kit.
# The native host paints their positioned trees.
def width() -> U32: 390
def height() -> U32: 688
def margin() -> U32: 24
def box() -> U32: U32.sub(width(), U32.mul(2, margin()))
def box_h() -> U32: U32.sub(height(), U32.mul(2, margin()))
def identity() -> K.NearIdentity:
  +badge = K.badge_tree(K.badge("Dot"))
  K.NearIdentity{P.layout("Dot identity", P.Vertical{}, 0, 0, 0, 93, P.Middle{}, [K.spacer("Identity", 56, 61, P.Middle{}), badge]), badge}
def header() -> P.UI:
  K.header_tree(K.header(K.glass_button(K.Intent.Menu{}), identity(), K.glass_button(K.Intent.Call{}), box()))
def item(line: K.Line) -> K.Item:
  match line:
    case K.Line{K.Role.Mine{}, text}: K.Said{K.bubble(K.Role.Mine{}, K.Delivery.Sent{}, K.Said.Words{text}, K.Presence.Shown{}, box())}
    case K.Line{K.Role.Near{}, text}: K.Said{K.bubble(K.Role.Near{}, Unit{}, K.Said.Words{text}, K.Presence.Shown{}, box())}
def items(xs: List<&2, K.Line>) -> List<&2, K.Item>:
  match xs:
    case []: []
    case x <> rest: item(x) <> items(rest)
# A compact thread shows a preview of a very long message; the full text
# and all previous messages remain readable in the conversation sheet.
def preview(line: K.Line) -> K.Line:
  match line:
    case K.Line{role, +text}:
      K.Line{role, Bool.pick(String, Nat.is_gt(String.length(text), 180n), String.take(text, 180n) ++ "…", text)}
def previews(xs: List<&2, K.Line>) -> List<&2, K.Item>:
  match xs:
    case []: []
    case x <> rest: item(preview(x)) <> previews(rest)
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
def history_view(history: List<&2, K.Line>) -> P.UI:
  +thread = K.thread_tree(K.thread(K.calm(K.Ready{items(history)}, K.Typing.Hidden{}), box()))
  +h = U32.max(height(), U32.add(K.height(thread), 136))
  P.layout("Dot conversation", P.Depth{}, 0, 0, width(), h, P.Leading{}, [
    P.layout("Conversation history", P.Vertical{}, 24, margin(), width(), h, P.Leading{}, [
      K.sheet_top("Conversación", box()), thread])])
# Keep the latest whole bubbles that fit below the header so the composer
# stays reachable after a long conversation or a wrapped message.
def fits(+xs: List<&2, K.Item>, +room: U32) -> List<&2, K.Item>:
  match xs:
    case []: []
    case x <> rest:
      Bool.pick(List<&2, K.Item>, U32.is_le(K.height(K.thread_tree(K.thread(K.calm(K.Ready{xs}, K.Typing.Hidden{}), box()))), room), xs, fits(rest, room))
def dialog(+title: String, content: List<&2, P.UI>) -> P.UI:
  +panel = P.layout("Dialog content", P.Vertical{}, 16, 20, box(), 0, P.Leading{},
    K.append_trees([K.sheet_top(title, U32.sub(box(), 40))], content))
  +h = K.height(panel)
  P.layout("dialog · " ++ title, P.Depth{}, 0, 0, width(), height(), P.Leading{}, [
    K.scrim(width(), height()),
    K.placed_at("Panel", margin(), U32.sub(height(), U32.add(h, margin())),
      P.layout("Dialog panel", P.Depth{}, 0, 0, box(), h, P.Leading{}, [
        K.filled("Container", T.SurfaceRole.Raised{}, box(), h, P.Corner{24}, K.edge(K.hairline())), panel]))])
def conversation(+placeholder: String, +draft: String, history: List<&2, K.Line>, +focus: K.Focus, +layers: List<&2, P.UI>) -> P.UI:
  +room = U32.sub(K.thread_room(placeholder, box(), box_h(), draft, focus, K.AttachMenu.Closed{}), K.height(header()))
  +shown = fits(previews(history), room)
  +body = K.conversation_tree(K.conversation(placeholder, box(), box_h(), K.Settled{}, K.SettledState{K.Ready{shown}, draft, focus, K.AttachMenu.Closed{}}))
  +base = P.layout("Dot", P.Depth{}, 0, 0, width(), height(), P.Leading{}, [
    P.layout("Header", P.Vertical{}, 0, margin(), width(), 0, P.Leading{}, [header()]),
    P.layout("Body", P.Vertical{}, 0, margin(), width(), height(), P.Leading{}, [body])])
  P.layout("Dot", P.Depth{}, 0, 0, width(), height(), P.Leading{}, K.append_trees([Bool.pick(P.UI, has_layers(layers), inactive(base), base)], layers))
