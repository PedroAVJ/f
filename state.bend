import F

# Which agent answers: the user's own subscription.
type Backend is Data:
  Codex{}
  Claude{}

type Url is Data:
  Connect{}
  Conversation{id: String}

type State is Data:
  State{lang: Lang, url: Url, backend: Backend, draft: String, history: List<&2, Line>, busy: Bool}

# Where the app starts: the Connect screen, in English, on Codex, nothing typed or said, not busy.
def initial() -> State:
  State{Lang.En{}, Connect{}, Codex{}, "", [], False{}}
