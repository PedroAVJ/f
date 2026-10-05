import UI
import ../../bend2/std/F/ui/kit.bend as K
import ../../bend2/std/F/ui/primitives.bend as P
import ../../bend2/std/F/ui/tokens.bend as T
import ../../bend2/std/F/browser/input.bend as Native
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
  State{lang: Lang, page: Page, backend: Backend, draft: String, history: List<&2, Line>, focus: K.Focus, panel: Panel, width: U32, height: U32}

def scheme() -> T.Scheme: T.Scheme.Dark{}
def persist_inputs() -> Bool: False{}
def window() -> Native.WindowConfig: Native.WindowConfig{width(), height(), 640, 560}
def s() -> State:
  State{Lang.Es{}, Conversation{"1"}, Codex{}, "", [Line{Role.Near{}, "Hola, Pedro. ¿En qué te ayudo hoy?"}], K.Focus.Blurred{}, Closed{}, width(), height()}
def placeholder() -> String: "Mensaje"
def backend_name(b: Backend) -> String:
  match b:
    case Codex{}: "Codex"
    case Claude{}: "Claude"

def send(+s: State) -> State:
  match s:
    case State{lang, page, backend, +draft, history, focus, panel, +vw, +vh}:
      Bool.pick(State, String.is_empty(String.trim(draft)), s,
        State{lang, page, backend, "", List.append(&2, Line, history, [Line{Role.Mine{}, String.trim(draft)}, Line{Role.Near{}, "…"}]), focus, Closed{}, vw, vh})
def clicked(+s: State, +label: String) -> State:
  match s:
    case State{+lang, +page, +backend, +draft, +history, +focus, +panel, +vw, +vh}:
      Bool.pick(State, String.eq(label, "Enviar"), send(s),
      Bool.pick(State, String.eq(label, "Menú"), State{lang, page, backend, draft, history, focus, Menu{}, vw, vh},
      Bool.pick(State, String.eq(label, "Cerrar"), State{lang, page, backend, draft, history, focus, Closed{}, vw, vh},
      Bool.pick(State, String.eq(label, "Codex"), State{lang, page, Codex{}, draft, history, focus, Closed{}, vw, vh},
      Bool.pick(State, String.eq(label, "Claude"), State{lang, page, Claude{}, draft, history, focus, Closed{}, vw, vh},
      Bool.pick(State, String.eq(label, "Llamar a Near"), State{lang, page, backend, draft, history, focus, Notice{"Las llamadas estarán disponibles al conectar el agente."}, vw, vh},
      Bool.pick(State, String.eq(label, "Adjuntar"), State{lang, page, backend, draft, history, focus, Notice{"Los archivos estarán disponibles al conectar el agente."}, vw, vh},
      Bool.pick(State, String.eq(label, "Dictar"), State{lang, page, backend, draft, history, focus, Notice{"El dictado estará disponible al conectar el agente."}, vw, vh}, s))))))))
def ordinary_update(+s: State, i: Input) -> State:
  match s:
    case State{+lang, +page, +backend, +draft, +history, +focus, +panel, +vw, +vh}:
      match i:
        case Clicked{label}: clicked(s, label)
        case Typed{label, value}:
          Bool.pick(State, String.eq(label, placeholder()), State{lang, page, backend, value, history, focus, panel, vw, vh}, s)
        case Focused{label}:
          Bool.pick(State, String.eq(label, placeholder()), State{lang, page, backend, draft, history, K.Focus.Focused{}, panel, vw, vh}, s)
        case Blurred{label}:
          Bool.pick(State, String.eq(label, placeholder()), State{lang, page, backend, draft, history, K.Focus.Blurred{}, panel, vw, vh}, s)
        case _: s

# A sheet owns input while open; hidden conversation controls cannot send.
def panel_update(+s: State, i: Input) -> State:
  match s:
    case State{+lang, +page, +backend, +draft, +history, +focus, panel, +vw, +vh}:
      match panel:
        case Closed{}: ordinary_update(s, i)
        case Menu{}:
          match i:
            case Clicked{+label}:
              Bool.pick(State, String.eq(label, "Ver conversación"), State{lang, page, backend, draft, history, focus, History{}, vw, vh},
              Bool.pick(State, String.eq(label, "Codex") || String.eq(label, "Claude") || String.eq(label, "Cerrar"), clicked(s, label), s))
            case _: s
        case _:
          match i:
            case Clicked{+label}:
              Bool.pick(State, String.eq(label, "Cerrar"), State{lang, page, backend, draft, history, focus, Closed{}, vw, vh}, s)
            case _: s

# Window geometry changes even while a dialog owns conversation input.
def resized(s: State, +w: U32, +h: U32) -> State:
  match s:
    case State{lang, page, backend, draft, history, focus, panel, vw, vh}:
      State{lang, page, backend, draft, history, focus, panel, U32.max(w, 240), U32.max(h, 200)}
def update(s: State, i: Input) -> State:
  match i:
    case Native.Resized{w, h}: resized(s, w, h)
    case _: panel_update(s, i)

def panel_tree(panel: Panel, +backend: Backend, +vw: U32, +vh: U32) -> List<&2, P.UI>:
  match panel:
    case Closed{}: []
    case Menu{}:
      [dialog("Agente", [
        K.paragraph("Backend", "Seleccionado: " ++ backend_name(backend), K.body(), K.ink(), U32.sub(dialog_w(vw), 40), P.Leading{}),
        K.button_tree(K.say(K.ButtonKind.Quiet{}, "Codex")),
        K.button_tree(K.say(K.ButtonKind.Quiet{}, "Claude")),
        K.button_tree(K.say(K.ButtonKind.Quiet{}, "Ver conversación"))], vw, vh)]
    case History{}: []
    case Notice{text}:
      [dialog("Dot", [K.paragraph("Notice", text, K.body(), K.ink(), U32.sub(dialog_w(vw), 40), P.Leading{})], vw, vh)]
def f(s: State) -> UI:
  match s:
    case State{lang, page, +backend, +draft, +history, +focus, +panel, +vw, +vh}:
      match panel:
        case History{}: K.tree(history_view(history, vw, vh))
        case _:
          K.tree(conversation(placeholder(), draft, history, focus, panel_tree(panel, backend, vw, vh), vw, vh))
