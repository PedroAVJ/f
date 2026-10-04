import F
import ../copy as C

def connect(+lang: Lang) -> Tree:
  screen("connect", [
    title("Dot"),
    caption(C.t(lang, C.Tagline{})),
    action(ButtonKind.Primary{}, C.t(lang, C.WithCodex{}), True{}),
    action(ButtonKind.Quiet{}, C.t(lang, C.WithClaude{}), True{})])
