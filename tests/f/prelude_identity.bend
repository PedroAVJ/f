import Base
import ../../bend2/std/F/ui/primitives.bend as P
import F
import State
import V
import ../../bend2/std/F/dot/session.bend as D
import ../../bend2/std/F/deployment/domain/architecture/system/release/type.bend as R

def tree_identity(t: Tree) -> P.Tree: t
def session_identity(s: Session) -> D.Session: s
def release_identity(r: Release) -> R.Release: r
def main() -> IO(Unit):
  IO.print(Session.phase(session_identity(Session.update(Command.Start{}, Session.initial()))))
#|running
