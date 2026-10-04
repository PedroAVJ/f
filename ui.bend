import Base
import ../f/bend2/std/F/ui/primitives.bend as P
import ../f/bend2/std/F/ui/kit.bend as K
import ./state.bend as S
import ./copy.bend as C

def f(s: S.State) -> P.Tree:
  match s:
    case S.State{+lang, url, backend, draft, lines, +busy}:
      match url:
        case S.Connect{}:
          K.screen("connect", [
            K.title("Dot"),
            K.caption(C.t(lang, C.Tagline{})),
            K.action(K.ButtonKind.Primary{}, C.t(lang, C.WithCodex{}), True{}),
            K.action(K.ButtonKind.Quiet{}, C.t(lang, C.WithClaude{}), True{})])
        case S.Conversation{id}:
          K.screen("conversation", [
            K.title("Dot"),
            K.stack("log", List.append(&2, P.Tree, K.lines(lines), Bool.pick(List<&2, P.Tree>, busy, [K.caption(C.t(lang, C.Typing{}))], []))),
            K.input(C.t(lang, C.MessagePrompt{}), draft),
            K.action(K.ButtonKind.Primary{}, C.t(lang, C.Send{}), Bool.not(busy))])
