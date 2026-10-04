import UI
import ./screens/connect
import ./screens/conversation

# Which agent answers: the user's own subscription.
type Backend is Data:
  Codex{}
  Claude{}

# Where the app is. Its address comes from its shape: /connect, /conversation/<id>.
type Page is Data:
  Connect{}
  Conversation{id: String}

# The app's language picks every Text it shows. The composer's input keeps and shows its own text; `draft` is
# that text as last typed, for Send.
type State is Data:
  State{lang: Lang, page: Page, backend: Backend, draft: String, history: List<&2, Line>, busy: Bool}

# Where the app starts: the Connect page, in English, on Codex, nothing typed or said, not busy.
def s() -> State:
  State{Lang.En{}, Connect{}, Codex{}, "", [], False{}}

# What a person's input does: Continue with ChatGPT or Claude picks the backend and opens the conversation;
# typing sets the draft; Send says it, and Dot answers "…" (there is no server yet).
def update(s: State, i: Input) -> State:
  match s:
    case State{+lang, +page, +backend, +draft, +history, +busy}:
      match i:
        case Clicked{+label}:
          Bool.pick(State, String.eq(label, Text.pick(lang, Text{"Continue with ChatGPT", "Continuar con ChatGPT"})), State{lang, Conversation{"1"}, Codex{}, draft, history, busy},
            Bool.pick(State, String.eq(label, Text.pick(lang, Text{"Continue with Claude", "Continuar con Claude"})), State{lang, Conversation{"1"}, Claude{}, draft, history, busy},
              Bool.pick(State, String.eq(label, Text.pick(lang, Text{"Send", "Enviar"})) && Bool.not(busy) && Bool.not(String.is_empty(String.trim(draft))),
                State{lang, page, backend, draft, List.append(&2, Line, history, [Line{Role.Mine{}, draft}, Line{Role.Near{}, "…"}]), busy},
                State{lang, page, backend, draft, history, busy})))
        case Typed{_, value}:
          State{lang, page, backend, value, history, busy}
        case _:
          State{lang, page, backend, draft, history, busy}

# The UI: the page's screen.
def f(s: State) -> UI:
  match s:
    case State{lang, page, backend, draft, history, busy}:
      match page:
        case Connect{}: connect()
        case Conversation{id}: conversation(history, busy)
