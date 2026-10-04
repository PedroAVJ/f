import Base
import ../../bend2/std/F/ui/primitives.bend as P
import F
import State
import ../../bend2/std/F/dot/session.bend as D

def tree_identity(t: Tree) -> P.Tree: t
def session_identity(s: Session) -> D.Session: s
def main() -> IO(Unit):
  IO.print(Session.phase(session_identity(Session.update(Command.Start{}, Session.initial()))))
#|running
