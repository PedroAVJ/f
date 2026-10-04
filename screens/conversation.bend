import Base
import F
import ../copy.bend as C
import ../components/log.bend as L

def conversation(+lang: Lang, draft: String, history: List<&2, Line>, +busy: Bool) -> Tree:
  screen("conversation", [
    title("Dot"),
    L.log(lang, history, busy),
    input(C.t(lang, C.MessagePrompt{}), draft),
    action(ButtonKind.Primary{}, C.t(lang, C.Send{}), Bool.not(busy))])
