# Preview: prints both screens as HTML. Not the real entry point yet.
import Base
import ../f/bend2/std/F/ui/kit.bend as K
import ../f/bend2/std/F/browser/scene.bend as Scene
import ./state.bend as S
import ./f.bend as F

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(Scene.html(F.f(S.State{K.Lang.En{}, S.Connect{}, S.Codex{}, "", [], False{}})))
    IO.print(Scene.html(F.f(S.State{K.Lang.En{}, S.Conversation{"1"}, S.Codex{}, "", [K.Line{K.Role.Near{}, "Hi, I'm Dot."}, K.Line{K.Role.Mine{}, "Hey"}], False{}})))
