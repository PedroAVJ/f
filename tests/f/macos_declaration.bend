# Invalid declarations must stop deploy too: otherwise an empty deployment
# or two native apps sharing an output folder silently succeed as no-ops.
import V
import ../../bend2/std/F/deployment/domain/architecture/system/deploy/ops.bend as Verbs

def show_deploy(d: Deployment) -> IO(Unit):
  do IO<Unit>:
    p : Verbs.Planned <- Verbs.mac_plan(d, [])
    IO.write(show_all(Verbs.deploy_steps(p)))

def main() -> IO(Unit):
  do IO<Unit>:
    show_deploy(Mac{Tailscale{9453}, []})
    show_deploy(Mac{Tailscale{9453}, [Application.MacOS{"ui"}, Application.MacOS{"other"}]})
    show_deploy(Mac{Tailscale{9453}, [Web{"ui"}, Web{"other"}]})
#|blocked  mac: no app declared
#|blocked  mac: one Mac app per deployment so far
#|blocked  mac :9453: one app per Tailscale port so far
