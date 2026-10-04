# A UI's text is a Text in every language the app speaks, drawn in the app's
# language. An input owns its state (text and focus): the runtime keeps it,
# by the input's label, and supplies it when it shows the UI; a textbox
# renders as an input holding that text, a button as a region. Browser
# events come back as Inputs: a click by the button's label, an edit by the
# textbox's label and its new text, focus and blur by its label, an address
# the app goes to
import UI
import ../../bend2/std/F/browser/host.bend as Host
import ../../bend2/std/F/browser/input.bend as In
import ../../bend2/std/F/browser/scene.bend as Scene

def form() -> UI:
  screen([stack([input(Text{"Write to Dot", "Escribe a Dot"}), action(Text{"Send", "Enviar"})])])

def shown(i: Input) -> String:
  match i:
    case Clicked{l}:
      "clicked " ++ l
    case Typed{l, v}:
      "typed " ++ l ++ ": " ++ v
    case Focused{l}:
      "focused " ++ l
    case Blurred{l}:
      "left " ++ l
    case Navigated{a}:
      "went to " ++ a
    case Ignored{}:
      "ignored"
    case In.Resized{w, h}:
      "resized " ++ U32.show(w) ++ "x" ++ U32.show(h)

def kept() -> List<&2, Held>:
  Input.keep(Input.keep(Input.keep([], Typed{"Write to Dot", "ho"}), Focused{"Write to Dot"}), Typed{"Write to Dot", "hola"})

def main() -> IO(Unit):
  +en = UI.html(form(), Lang.En{})
  +es = UI.html(form(), Lang.Es{})
  +held = Scene.html(UI.draw(form(), Rendering{Lang.En{}, kept()}))
  do IO<Unit>:
    IO.print(Bool.show(String.contains(en, "<input data-bend-field=\"textbox · Write to Dot\" value=\"\" aria-label=\"Write to Dot\"")))
    IO.print(Bool.show(String.contains(es, "data-bend-field=\"textbox · Escribe a Dot\"") && String.contains(es, "data-bend-event=\"button · Enviar\"")))
    IO.print(Bool.show(String.contains(held, "value=\"hola\"") && String.contains(held, "data-bend-stroke-width=\"1.5\"")))
    IO.print(shown(In.of(Host.Reply{1, "button · Send"})))
    IO.print(shown(In.of(Host.Reply{1, "{\"action\":\"field\",\"name\":\"textbox · Write to Dot\",\"value\":\"hola\"}"})))
    IO.print(shown(In.of(Host.Reply{1, "{\"action\":\"focus\",\"name\":\"textbox · Write to Dot\"}"})))
    IO.print(shown(In.of(Host.Reply{1, "{\"action\":\"blur\",\"name\":\"textbox · Write to Dot\"}"})))
    IO.print(shown(In.of(Host.Reply{1, "address · /conversation/7"})))
    IO.print(shown(In.of(Host.Reply{2, "browser host unavailable"})))
    IO.print(shown(In.of(Host.Reply{1, "{\"action\":\"resize\",\"width\":1000,\"height\":760}"})))
    IO.print(shown(In.of(Host.Reply{1, "{\"action\":\"resize\",\"width\":0,\"height\":760}"})))
    IO.print(shown(In.of(Host.Reply{1, "{\"action\":\"resize\",\"width\":1000.5,\"height\":760}"})))
    IO.print(shown(In.of(Host.Reply{1, "{\"action\":\"resize\",\"width\":\"1000\",\"height\":760}"})))
    IO.print(shown(In.of(Host.Reply{1, "{\"action\":\"resize\",\"width\":4294967296,\"height\":760}"})))
#|True
#|True
#|True
#|clicked Send
#|typed Write to Dot: hola
#|focused Write to Dot
#|left Write to Dot
#|went to /conversation/7
#|ignored
#|resized 1000x760
#|ignored
#|ignored
#|ignored
#|ignored
