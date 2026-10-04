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
