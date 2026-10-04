import Base
import F
import ./state.bend as S
import ./copy.bend as C

def f(s: S.State) -> Tree:
  match s:
    case S.State{+lang, url, backend, draft, history, +busy}:
      match url:
        case S.Connect{}:
          screen("connect", [
            title("Dot"),
            caption(C.t(lang, C.Tagline{})),
            action(ButtonKind.Primary{}, C.t(lang, C.WithCodex{}), True{}),
            action(ButtonKind.Quiet{}, C.t(lang, C.WithClaude{}), True{})])
        case S.Conversation{id}:
          screen("conversation", [
            title("Dot"),
            stack("log", List.append(&2, Tree, lines(history), Bool.pick(List<&2, Tree>, busy, [caption(C.t(lang, C.Typing{}))], []))),
            input(C.t(lang, C.MessagePrompt{}), draft),
            action(ButtonKind.Primary{}, C.t(lang, C.Send{}), Bool.not(busy))])
