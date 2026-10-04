# A System is its releases and its deployments, from V's bare names; V's
# verbs over it are diff, build, release and deploy, and any other word,
# check and ship too, stops before observing anything
import V
import ../../bend2/std/F/deployment/domain/architecture/system/deploy/ops.bend as Verbs

def system() -> System:
  System{[Code{GitHub{"o", "x", Proprietary{}}}], [Mac{Tailscale{9453}, [Web{"ui"}]}]}

def main() -> IO(Unit):
  Verbs.verb("ship", system())
#|unknown verb ship: use diff, build, release or deploy
#|exit 1
