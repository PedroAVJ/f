# Preview: prints both screens as HTML. Not the real entry point yet.
import Base
import F
import ./state.bend as S
import ./ui.bend as App

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(Tree.html(App.f(S.State{Lang.En{}, S.Connect{}, S.Codex{}, "", [], False{}})))
    IO.print(Tree.html(App.f(S.State{Lang.En{}, S.Conversation{"1"}, S.Codex{}, "", [Line{Role.Near{}, "Hi, I'm Dot."}, Line{Role.Mine{}, "Hey"}], False{}})))
