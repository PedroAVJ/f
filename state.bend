import Base
import ../f/bend2/std/F/ui/kit.bend as K

# Which agent answers: the user's own subscription.
type Backend is Data:
  Codex{}
  Claude{}

type Url is Data:
  Connect{}
  Conversation{id: String}

type State is Data:
  State{lang: K.Lang, url: Url, backend: Backend, draft: String, lines: List<&2, K.Line>, busy: Bool}
