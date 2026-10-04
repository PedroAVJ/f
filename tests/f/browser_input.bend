# A tree's textbox renders as an input holding its whole value (F's
# "value · " leaf), named after the box; a button as a region. Browser
# events come back as Inputs: a click by the button's label, a field edit by
# the textbox's label and its new text, an address the app goes to
import UI
import ../../bend2/std/F/browser/host.bend as Host
import ../../bend2/std/F/browser/input.bend as In

def form() -> UI:
  screen("form", [input("Write to Dot", "hola"), action(ButtonKind.Primary{}, "Send", True{})])

def shown(i: Input) -> String:
  match i:
    case Clicked{l}:
      "clicked " ++ l
    case Typed{l, v}:
      "typed " ++ l ++ ": " ++ v
    case Navigated{a}:
      "went to " ++ a
    case Ignored{}:
      "ignored"

def main() -> IO(Unit):
  +h = UI.html(form())
  do IO<Unit>:
    IO.print(Bool.show(String.contains(h, "<input data-bend-field=\"textbox · Write to Dot\" value=\"hola\" aria-label=\"Write to Dot\"")))
    IO.print(Bool.show(String.contains(h, "data-bend-event=\"button · Send\"")))
    IO.print(shown(In.of(Host.Reply{1, "button · Send"})))
    IO.print(shown(In.of(Host.Reply{1, "{\"action\":\"field\",\"name\":\"textbox · Write to Dot\",\"value\":\"hola\"}"})))
    IO.print(shown(In.of(Host.Reply{1, "address · /conversation/7"})))
    IO.print(shown(In.of(Host.Reply{2, "browser host unavailable"})))
#|True
#|True
#|clicked Send
#|typed Write to Dot: hola
#|went to /conversation/7
#|ignored
