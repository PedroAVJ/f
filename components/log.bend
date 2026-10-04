import Base
import F
import ../state.bend as S
import ../copy.bend as C

# The conversation so far, plus "Dot is typing…" while waiting.
def log(+lang: Lang, history: List<&2, Line>, busy: Bool) -> Tree:
  stack("log", List.append(&2, Tree, lines(history), Bool.pick(List<&2, Tree>, busy, [caption(C.t(lang, C.Typing{}))], [])))
