import Base
import ./symbols.bend as S
import ./nearling.bend as N

# Shared production and review vocabulary; API remains provisional.
type Visual is Data:
  Glyph{drawing: S.Drawing}
  Sprite{frame: N.Frame}
type Component is Data:
  Group{kind: String, children: List<&2, Component>}
  Text{kind: String, value: String}
  Bubble{id: U32, role: String, text: String}
  Field{kind: String, label: String, value: String, placeholder: String}
  Button{kind: String, label: String, action: String, id: U32, disabled: Bool}
  Person{id: U32, username: String}
  TaskRow{id: U32, title: String, done: Bool}
  Symbol{visual: Visual}

def Composer(draft: String, disabled: Bool) -> Component:
  Group{"composer", [Field{"draft", "Escribe a Near", draft, "Escribe a Near"}, Button{"send", "Enviar", "send", 0, disabled}]}
def Near(animation: N.Animation, time_ms: U32, reduced_motion: Bool) -> Component:
  Symbol{Sprite{N.sample(animation, time_ms, reduced_motion)}}
def NearIdentity(animation: N.Animation) -> Component:
  Group{"pet", [Near(animation, 0, False{}), Text{"near-name", "Near"}]}
def Header(mode: String, animation: N.Animation) -> Component:
  Group{"near-header", [NearIdentity(animation), Text{"mode", mode}]}
def NameField(value: String) -> Component:
  Field{"username", "Nombre de usuario", value, "Escribe un nombre"}
def Message(text: String) -> Component:
  Text{"bubble", text}
def AppShell(header: Component, conversation: Component, composer: Component) -> Component:
  Group{"app-shell", [header, conversation, composer]}
def append_components(xs: List<&2, Component>, tail: List<&2, Component>) -> List<&2, Component>:
  match xs:
    case Nil{}: tail
    case Con{head, rest}: Con{head, append_components(rest, tail)}
