import UI
import ../f/bend2/std/F/ui/kit.bend as K
import ../f/bend2/std/F/ui/primitives.bend as P
import ../f/bend2/std/F/ui/tokens.bend as T
import ./components/conversation

# The native milestone owns its conversation and composer state. Agent
# transport is the next milestone; a send retains the original "…" reply.
type Backend is Data:
  Codex{}
  Claude{}
type Page is Data:
  Conversation{id: String}
type Panel is Data:
  Closed{}
  Menu{}
  History{}
  Notice{text: String}
type State is Data:
  State{lang: Lang, page: Page, backend: Backend, draft: String, history: List<&2, Line>, focus: K.Focus, panel: Panel}

def scheme() -> T.Scheme: T.Scheme.Dark{}
def persist_inputs() -> Bool: False{}
def s() -> State:
  State{Lang.Es{}, Conversation{"1"}, Codex{}, "", [Line{Role.Near{}, "Hola, Pedro. ¿En qué te ayudo hoy?"}], K.Focus.Blurred{}, Closed{}}
def placeholder() -> String: "Mensaje"
def backend_name(b: Backend) -> String:
  match b:
    case Codex{}: "Codex"
    case Claude{}: "Claude"

def send(+s: State) -> State:
  match s:
    case State{lang, page, backend, +draft, history, focus, panel}:
      Bool.pick(State, String.is_empty(String.trim(draft)), s,
        State{lang, page, backend, "", List.append(&2, Line, history, [Line{Role.Mine{}, String.trim(draft)}, Line{Role.Near{}, "…"}]), focus, Closed{}})
def clicked(+s: State, +label: String) -> State:
  match s:
    case State{+lang, +page, +backend, +draft, +history, +focus, +panel}:
      Bool.pick(State, String.eq(label, "Enviar"), send(s),
      Bool.pick(State, String.eq(label, "Menú"), State{lang, page, backend, draft, history, focus, Menu{}},
      Bool.pick(State, String.eq(label, "Cerrar"), State{lang, page, backend, draft, history, focus, Closed{}},
      Bool.pick(State, String.eq(label, "Codex"), State{lang, page, Codex{}, draft, history, focus, Closed{}},
      Bool.pick(State, String.eq(label, "Claude"), State{lang, page, Claude{}, draft, history, focus, Closed{}},
      Bool.pick(State, String.eq(label, "Llamar a Near"), State{lang, page, backend, draft, history, focus, Notice{"Las llamadas estarán disponibles al conectar el agente."}},
      Bool.pick(State, String.eq(label, "Adjuntar"), State{lang, page, backend, draft, history, focus, Notice{"Los archivos estarán disponibles al conectar el agente."}},
      Bool.pick(State, String.eq(label, "Dictar"), State{lang, page, backend, draft, history, focus, Notice{"El dictado estará disponible al conectar el agente."}}, s))))))))
def ordinary_update(+s: State, i: Input) -> State:
  match s:
    case State{+lang, +page, +backend, +draft, +history, +focus, +panel}:
      match i:
        case Clicked{label}: clicked(s, label)
        case Typed{label, value}:
          Bool.pick(State, String.eq(label, placeholder()), State{lang, page, backend, value, history, focus, panel}, s)
        case Focused{label}:
          Bool.pick(State, String.eq(label, placeholder()), State{lang, page, backend, draft, history, K.Focus.Focused{}, panel}, s)
        case Blurred{label}:
          Bool.pick(State, String.eq(label, placeholder()), State{lang, page, backend, draft, history, K.Focus.Blurred{}, panel}, s)
        case _: s

# A sheet owns input while open; hidden conversation controls cannot send.
def update(+s: State, i: Input) -> State:
  match s:
    case State{+lang, +page, +backend, +draft, +history, +focus, panel}:
      match panel:
        case Closed{}: ordinary_update(s, i)
        case Menu{}:
          match i:
            case Clicked{+label}:
              Bool.pick(State, String.eq(label, "Ver conversación"), State{lang, page, backend, draft, history, focus, History{}},
              Bool.pick(State, String.eq(label, "Codex") || String.eq(label, "Claude") || String.eq(label, "Cerrar"), clicked(s, label), s))
            case _: s
        case _:
          match i:
            case Clicked{+label}:
              Bool.pick(State, String.eq(label, "Cerrar"), State{lang, page, backend, draft, history, focus, Closed{}}, s)
            case _: s

def panel_tree(panel: Panel, +backend: Backend) -> List<&2, P.UI>:
  match panel:
    case Closed{}: []
    case Menu{}:
      [dialog("Agente", [
        K.paragraph("Backend", "Seleccionado: " ++ backend_name(backend), K.body(), K.ink(), 302, P.Leading{}),
        K.button_tree(K.say(K.ButtonKind.Quiet{}, "Codex")),
        K.button_tree(K.say(K.ButtonKind.Quiet{}, "Claude")),
        K.button_tree(K.say(K.ButtonKind.Quiet{}, "Ver conversación"))])]
    case History{}: []
    case Notice{text}:
      [dialog("Dot", [K.paragraph("Notice", text, K.body(), K.ink(), 302, P.Leading{})])]
def f(s: State) -> UI:
  match s:
    case State{lang, page, +backend, +draft, +history, +focus, +panel}:
      match panel:
        case History{}: K.tree(history_view(history))
        case _:
          K.tree(conversation(placeholder(), draft, history, focus, panel_tree(panel, backend)))
