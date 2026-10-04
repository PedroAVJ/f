import UI
import ../../f/bend2/std/F/browser/input.bend as Native
import ../../f/bend2/std/F/ui/kit.bend as K
import ../ui.bend as App
import ../components/conversation.bend as C
import ../../f/bend2/std/F/ui/primitives.bend as P
import ../../f/bend2/std/F/ui/tokens.bend as T
import ../../f/bend2/std/F/browser/scene.bend as Scene

def count(xs: List<&2, Line>) -> U32:
  match xs:
    case []: 0
    case x <> rest: U32.add(1, count(rest))
def summary(s: App.State) -> String:
  match s:
    case App.State{lang, page, backend, draft, history, focus, panel, width, height}:
      App.backend_name(backend) ++ ":" ++ draft ++ ":" ++ U32.show(count(history))
def input(s: App.State, +text: String) -> App.State:
  App.update(s, Typed{"Mensaje", text})
def history_count(s: App.State) -> U32:
  match s:
    case App.State{lang, page, backend, draft, history, focus, panel, width, height}: count(history)
def repeat(n: Nat) -> String:
  match n:
    case 0n: "fin"
    case 1n+k: "Este mensaje debe seguir disponible completo. " ++ repeat(k)
def tree(s: App.State) -> P.UI: K.draw(App.f(s), K.Rendering{Lang.Es{}, []})
def frame_matches(+s: App.State, +w: U32, +h: U32) -> Bool:
  U32.is_eq(K.width(tree(s)), w) && U32.is_eq(K.height(tree(s)), h)
def inside(xs: List<&2, P.Box>, +w: U32, +h: U32) -> Bool:
  match xs:
    case []: True{}
    case P.Box{name, mark, x, y, bw, bh, level, layer} <> rest:
      U32.is_le(U32.add(x, bw), w) && U32.is_le(U32.add(y, bh), h) && inside(rest, w, h)
def regions_fit(+s: App.State, +w: U32, +h: U32) -> Bool:
  inside(K.placed(tree(s)), w, h)
def centered_composer(s: App.State, +w: U32) -> Bool:
  +a = K.find_area(K.placed(tree(s)), "group · Escribir mensaje")
  +center = U32.add(U32.mul(K.area_x(a), 2), K.area_w(a))
  U32.is_gt(K.area_w(a), 0) && U32.is_le(center, w) && U32.is_le(w, U32.add(center, 1))
def main() -> IO(Unit):
  +start = App.s()
  +typed = input(start, "  Hola, ¿qué tal? 👋  ")
  +sent = App.update(typed, Clicked{"Enviar"})
  +twice = App.update(sent, Clicked{"Enviar"})
  +menu = App.update(sent, Clicked{"Menú"})
  +claude = App.update(menu, Clicked{"Claude"})
  +tree = K.draw(App.f(sent), K.Rendering{Lang.Es{}, []})
  +packet = Scene.canvas_in(tree, T.Scheme.Dark{})
  +long = App.update(input(start, repeat(100n)), Clicked{"Enviar"})
  +history = App.update(App.update(long, Clicked{"Menú"}), Clicked{"Ver conversación"})
  +full = Scene.canvas_in(K.draw(App.f(history), K.Rendering{Lang.Es{}, []}), T.Scheme.Dark{})
  +modal = Scene.canvas_in(K.draw(App.f(menu), K.Rendering{Lang.Es{}, []}), T.Scheme.Dark{})
  +narrow = App.update(sent, Native.Resized{640, 560})
  +wide = App.update(sent, Native.Resized{1440, 900})
  +draft_resize = App.update(typed, Native.Resized{800, 620})
  +modal_resize = App.update(menu, Native.Resized{1200, 800})
  +draft_menu = App.update(App.update(typed, Clicked{"Menú"}), Native.Resized{800, 620})
  do IO<Unit>:
    IO.print(summary(start))
    IO.print(summary(sent))
    IO.print(summary(twice))
    IO.print(summary(claude))
    IO.print(summary(App.update(start, Typed{"unrelated", "do not edit the composer"})))
    IO.print(Bool.show(U32.is_eq(history_count(App.update(input(start, " \n\t "), Clicked{"Enviar"})), 1)))
    IO.print(Bool.show(String.contains(packet, "Hola, ¿qué tal? 👋")))
    IO.print(Bool.show(String.contains(packet, "textbox · Mensaje")))
    IO.print(Bool.show(String.contains(packet, "button, disabled · Enviar")))
    IO.print(Bool.show(U32.is_eq(P.width_of(P.size(tree)), C.width())))
    IO.print(Bool.show(U32.is_eq(P.height_of(P.size(tree)), C.height())))
    IO.print(Bool.show(String.contains(full, "fin")))
    IO.print(Bool.show(U32.is_eq(history_count(App.update(menu, Clicked{"Enviar"})), 3)))
    IO.print(Bool.show(String.contains(modal, "[\"region\",\"textbox · Mensaje\"")))
    IO.print(Bool.show(frame_matches(narrow, 640, 560)))
    IO.print(Bool.show(frame_matches(wide, 1440, 900)))
    IO.print(Bool.show(regions_fit(narrow, 640, 560)))
    IO.print(Bool.show(regions_fit(wide, 1440, 900)))
    IO.print(Bool.show(centered_composer(wide, 1440)))
    IO.print(Bool.show(String.eq(summary(draft_resize), summary(typed))))
    IO.print(Bool.show(frame_matches(modal_resize, 1200, 800)))
    IO.print(Bool.show(regions_fit(modal_resize, 1200, 800)))
    IO.print(Bool.show(String.eq(summary(App.update(draft_menu, Clicked{"Enviar"})), summary(typed))))
    IO.print(Bool.show(frame_matches(App.update(draft_menu, Clicked{"Cerrar"}), 800, 620)))
#|Codex::1
#|Codex::3
#|Codex::3
#|Claude::3
#|Codex::1
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|False
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
