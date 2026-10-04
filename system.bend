import Base
import ../f/bend2/std/F/deployment/domain/architecture/system/type.bend as Sys
import ../f/bend2/std/F/deployment/domain/architecture/system/container/type.bend as Ct
import ../f/bend2/std/F/deployment/domain/architecture/system/deployment/type.bend as D
import ../f/bend2/std/F/deployment/domain/architecture/system/deployment/host/type.bend as H
import ../f/bend2/std/F/deployment/domain/architecture/system/release/type.bend as R
import ../f/bend2/std/F/deployment/domain/architecture/system/plan/type.bend as P
import ../f/bend2/std/F/deployment/domain/architecture/system/plan/ops.bend as Plan
import ../f/bend2/std/F/deployment/domain/architecture/category/type.bend as K
import ../f/bend2/std/F/deployment/domain/architecture/relationship/type.bend as Rel

def release() -> R.Release:
  R.Release{R.Repository{"open-dot", True{}}, [], []}

def system() -> Sys.System:
  Sys.System{"open-dot", "Open Dot", "Dot, on your own Codex or Claude subscription.",
    [
      Ct.Container{"web", "Web app", "ui.bend compiled to the browser.",
        K.Client{}, Ct.Ours{}, Ct.Public{}, [], "ui.bend", [], ["F"], [], ["Bend"], [], [],
        [Rel.Relationship{"server", "Sends messages", "HTTPS", True{}}]},
      Ct.Container{"server", "Server", "Holds the session and talks to the agent.",
        K.Proxy{}, Ct.Ours{}, Ct.Public{}, [K.Hosting{}], "server.bend", [], ["F"], [], ["Bend"], [], [],
        [Rel.Relationship{"codex", "Asks Codex", "HTTPS", True{}}, Rel.Relationship{"claude", "Asks Claude", "HTTPS", True{}}]},
      Ct.Container{"codex", "Codex", "The user's ChatGPT subscription.",
        K.ModelApi{}, Ct.Theirs{}, Ct.Public{}, [], "", ["OpenAI"], [], [], [], [], [], []},
      Ct.Container{"claude", "Claude", "The user's Claude subscription.",
        K.ModelApi{}, Ct.Theirs{}, Ct.Public{}, [], "", ["Anthropic"], [], [], [], [], [], []}
    ],
    D.Deployment{"https://dot.example.com", ["sessions"], [], [
      D.Node{"mac", "Pedro's Mac", "launchd", D.Server{}, H.Owned{"MacBook"}, D.Unmanaged{}, [], ["web", "server"]}
    ]},
    release()}

# What the world looks like now. Hardcoded: nothing in V observes it yet.
def observed() -> P.Observed:
  P.Observed{["ui.bend", "state.bend", "copy.bend"], ["ui.bend", "state.bend", "copy.bend"], [],
    P.Remote{"https://github.com/PedroAVJ/open-dot", "public", True{}, True{}}, []}

def main() -> IO(Unit):
  IO.print(Plan.show_all(Plan.plan(release(), observed())))
