# A tree's textbox renders as an input holding its whole value (F's
# "value · " leaf), named after the box; a button as a region. Browser
# events come back as Inputs: a click by the button's label, a field edit by
# the textbox's label and its new text
import F
import ../../bend2/std/F/browser/host.bend as Host
import ../../bend2/std/F/browser/input.bend as In

def form() -> Tree:
  screen("form", [input("Write to Dot", "hola"), action(ButtonKind.Primary{}, "Send", True{})])

def shown(i: Input) -> String:
  match i:
    case Clicked{l}:
      "clicked " ++ l
    case Typed{l, v}:
      "typed " ++ l ++ ": " ++ v
    case Ignored{}:
      "ignored"

def main() -> IO(Unit):
  +h = Tree.html(form())
  do IO<Unit>:
    IO.print(Bool.show(String.contains(h, "<input data-bend-field=\"textbox · Write to Dot\" value=\"hola\" aria-label=\"Write to Dot\"")))
    IO.print(Bool.show(String.contains(h, "data-bend-event=\"button · Send\"")))
    IO.print(shown(In.of(Host.Reply{1, "button · Send"})))
    IO.print(shown(In.of(Host.Reply{1, "{\"action\":\"field\",\"name\":\"textbox · Write to Dot\",\"value\":\"hola\"}"})))
    IO.print(shown(In.of(Host.Reply{2, "browser host unavailable"})))
#|True
#|True
#|clicked Send
#|typed Write to Dot: hola
#|ignored
