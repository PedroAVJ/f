import Base
import ../../bend2/std/F/ui/primitives.bend as P
import ../../bend2/std/F/ui/tokens.bend as T
import ../../bend2/std/F/ui/description.bend as Description

type State is Data:
  State{count: U32, data: String}

law UI: Data
def UI(): Description.UI<P.Tree>

def text(name: String, content: String) -> P.Tree:
  P.text(name, content, P.TextType{"Body", 20, 500}, T.TextRole.Ink{}, 320, 40, P.Leading{})
def Counter(count: U32) -> P.Tree:
  text("button · increment", "Count: " ++ U32.show(count))
def FetchButton() -> P.Tree:
  text("button · fetch", "Fetch message")
def Status(data: String) -> P.Tree:
  text("status", data)
def StatusPanel(content: Unit -> P.Tree) -> P.Tree:
  P.layout("StatusPanel", P.Vertical{}, 0, 0, 320, 40, P.Leading{}, [content(Unit{})])

def F(state: State) -> UI:
  match state:
    case State{count, data}:
      status = {unit => Status(data) : Unit -> P.Tree}
      Description.UI{P.layout("App", P.Vertical{}, 8, 16, 360, 200, P.Leading{}, [Counter(count), FetchButton(), StatusPanel(status)])}
