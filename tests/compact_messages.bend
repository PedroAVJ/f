import UI
import ../../f/bend2/std/F/browser/input.bend as Native
import ../../f/bend2/std/F/ui/kit.bend as K
import ../../f/bend2/std/F/ui/primitives.bend as P
import ../mobile.bend as App
import ../components/mobile_conversation.bend as C
import ../components/mobile_rich_text.bend as Rich
import ../components/web_scene.bend as Web
import ./mobile.bend as Test

def four() -> String: "one\ntwo\nthree\nfour"
def five() -> String: "one\ntwo\nthree\nfour\nTAIL_SENTINEL"
def history(text: String) -> App.State:
  App.State.with_session(App.s(), App.Snapshot{[App.Thread{"thread-1", "Test", "idle", [App.Message{"long", K.Role.Near{}, text, "", 0, K.Picture{"", 0, 0, ""}, "", "", ""}], "", "", False{}, True{}, "long", ""}], "thread-1", [], "codex"})
def labels(t: P.UI) -> String:
  match t:
    case P.Last{}: ""
    case P.Leaf{name, shape, w, h, align, next}: name ++ "\n" ++ labels(next)
    case P.Node{name, lay, w, h, align, first, next}: name ++ "\n" ++ labels(first) ++ labels(next)
def main() -> IO(Unit):
  +short = K.item_tree(App.inline_text_item(K.Role.Near{}, four(), 0, 390))
  +long = K.item_tree(App.inline_text_item(K.Role.Near{}, five(), 0, 390))
  +mine = K.item_tree(App.inline_text_item(K.Role.Mine{}, five(), 1, 390))
  +detail = App.update(history(Test.repeat(80n)), Native.Clicked{"Read message 1"})
  +typed_four = App.update(App.s(), Native.Typed{"Message", four()})
  +typed_five = App.update(typed_four, Native.Typed{"Message", five()})
  +edited = App.update(typed_five, Native.Typed{"Message", Test.repeat(80n)})
  +closed = App.update(edited, Native.Clicked{"Close"})
  +reopened = App.update(closed, Native.Focused{"Message"})
  +english = K.draw(App.f(history(five())), K.Rendering{K.Lang.En{}, []})
  +bakery = App.State.with_session(history(five()), App.Snapshot{[], "", [], "bakery"})
  +bakery_tree = K.draw(App.f(bakery), K.Rendering{K.Lang.En{}, []})
  +detail_html = Web.html(Test.tree(detail))
  do IO<Unit>:
    IO.print(Bool.show(String.contains(detail_html, "id=\"dot-message-detail\"")))
    IO.print(Bool.show(String.contains(detail_html, "TAIL_SENTINEL")))
    IO.print(Bool.show(Bool.not(String.contains(detail_html, "id=\"dot-thread\""))))
    IO.print(Bool.show(String.contains(labels(bakery_tree), "button, disabled · Voice message")))
    IO.print(Bool.show(String.contains(labels(bakery_tree), "button, disabled · Call Near")))
    IO.print(Bool.show(String.contains(labels(bakery_tree), "button · Camera")))
    IO.print(Bool.show(Bool.not(App.can_record(bakery))))
    IO.print(Bool.show(String.contains(App.display_query(history(five())), "inlineLines=4")))
    IO.print(Bool.show(String.contains(App.display_query(history(five())), "assistantLines=5")))
    IO.print(Bool.show(App.draft_capped("https://example.com/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", 390)))
    IO.print(Bool.show(U32.is_eq(K.inline_line_limit(), 4)))
    IO.print(Bool.show(U32.is_eq(Rich.lines(four(), 200), 4)))
    IO.print(Bool.show(Bool.not(String.contains(labels(short), "Leer mensaje"))))
    IO.print(Bool.show(String.contains(labels(long), "Leer mensaje 1")))
    IO.print(Bool.show(Bool.not(String.contains(C.text_of(long), "TAIL_SENTINEL"))))
    IO.print(Bool.show(String.contains(labels(mine), "Leer mensaje 2")))
    IO.print(Bool.show(String.contains(C.text_of(english), "Read more")))
    IO.print(Bool.show(String.contains(labels(english), "Read message 1")))
    IO.print(Bool.show(App.is_detail(App.State.panel(detail))))
    IO.print(Bool.show(String.contains(C.text_of(Test.tree(detail)), "TAIL_SENTINEL")))
    IO.print(Bool.show(String.contains(labels(Test.tree(detail)), "Scroll viewport · Message")))
    IO.print(Bool.show(Test.fits(App.resized(detail, 390, 844), 390, 844)))
    IO.print(Bool.show(Test.fits(App.resized(detail, 320, 568), 320, 568)))
    IO.print(Bool.show(Test.fits(App.resized(detail, 844, 390), 844, 390)))
    IO.print(Bool.show(Bool.not(App.is_editor(App.State.panel(typed_four)))))
    IO.print(Bool.show(App.is_editor(App.State.panel(typed_five))))
    IO.print(Bool.show(String.eq(App.State.draft(edited), Test.repeat(80n))))
    IO.print(Bool.show(String.eq(App.State.draft(closed), Test.repeat(80n))))
    IO.print(Bool.show(App.is_closed(App.State.panel(closed))))
    IO.print(Bool.show(App.is_editor(App.State.panel(reopened))))
    IO.print(Bool.show(Test.fits(App.resized(edited, 390, 844), 390, 844)))
    IO.print(Bool.show(Test.fits(App.resized(edited, 320, 240), 320, 240)))
    IO.print(Bool.show(Test.fits(App.resized(edited, 844, 390), 844, 390)))
#| True
#| True
#| True
#| True
#| True
#| True
#| True
#| True
#| True
#| True
#| True
#| True
#| True
#| True
#| True
#| True
#| True
#| True
#| True
#| True
#| True
#| True
#| True

#| True
#| True
#| True
#| True
#| True
#| True
#| True

#| True
#| True
#| True
