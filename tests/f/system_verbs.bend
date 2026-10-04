# A System is its releases and its deployments, from V's bare names; V's
# verbs over it are check, release, deploy and ship (building is a step of
# release and deploy), and any other word, build too, stops before observing
# anything
import V
import ../../bend2/std/F/deployment/domain/architecture/system/deploy/ops.bend as Verbs

def system() -> System:
  System{[Code{GitHub{"o", "x", Proprietary{}}}], [Mac{Tailscale{9453}, [Web{"apps/web"}]}]}

def main() -> IO(Unit):
  Verbs.verb("build", system())
#|unknown verb build: use check, release, deploy or ship
#|exit 1
