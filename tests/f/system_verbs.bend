# A System is its releases and its deployments, from V's bare names; V's
# verbs over it are check, build, release, deploy and ship, and any other
# word stops before observing anything
import V
import ../../bend2/std/F/deployment/domain/architecture/system/deploy/ops.bend as Verbs

def system() -> System:
  System{"x", "X", "An example.", [Code{GitHub{"o", "x", Proprietary{}}}], [Deployment{"http://127.0.0.1:1", [], [], []}]}

def main() -> IO(Unit):
  Verbs.verb("launch", system())
#|unknown verb launch: use check, build, release, deploy or ship
#|exit 1
