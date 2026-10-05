import UI
import ../../f/bend2/std/F/ui/kit.bend as K
import ../../f/bend2/std/F/browser/host.bend as Host
import ../../f/bend2/std/F/browser/input.bend as Native
import ../mobile.bend as App
import ../components/web_scene.bend as Web

def render(+state: App.State) -> String:
  Web.html(K.draw(App.f(state), K.Rendering{App.lang(state), []}))

def main() -> IO(Unit):
  +empty = render(App.resized(App.s(), 320, 568))
  +loaded = App.apply_reply(App.s(), Host.Reply{1, "{\"threads\":[{\"id\":\"one\",\"title\":\"Near\",\"status\":\"idle\",\"messages\":[{\"id\":\"one\",\"role\":\"assistant\",\"text\":\"A short conversation\"}]}],\"selectedThreadId\":\"one\"}"}, False{})
  +typed = App.update(loaded, Native.Typed{"Mensaje", "<script>not code</script>"})
  +html = render(App.resized(typed, 390, 844))
  do IO<Unit>:
    IO.print(Bool.show(String.contains(empty, "id=\"dot-thread\"") && Bool.not(String.contains(empty, "429496"))))
    IO.print(Bool.show(String.contains(html, "<textarea ") && String.contains(html, "&lt;script&gt;not code&lt;/script&gt;")))
    IO.print(Bool.show(String.contains(html, "A short conversation") && String.contains(html, "role=\"log\"")))
    IO.print(Bool.show(Bool.not(String.contains(html, "Field text")) && Bool.not(String.contains(html, "<script>"))))
#| True
#| True
#| True
#| True
