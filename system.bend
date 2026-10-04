import Base
import V

def release() -> Release:
  Release{Repository{"open-dot", True{}}, [], []}

def system() -> System:
  System{"open-dot", "Open Dot", "Dot, on your own Codex or Claude subscription.",
    [
      Container{"web", "Web app", "ui.bend compiled to the browser.",
        Category.Client{}, Ownership.Ours{}, Exposure.Public{}, [], "ui.bend", [], ["F"], [], ["Bend"], [], [],
        [Relationship{"server", "Sends messages", "HTTPS", True{}}]},
      Container{"server", "Server", "Holds the session and talks to the agent.",
        Category.Proxy{}, Ownership.Ours{}, Exposure.Public{}, [Capability.Hosting{}], "server.bend", [], ["F"], [], ["Bend"], [], [],
        [Relationship{"codex", "Asks Codex", "HTTPS", True{}}, Relationship{"claude", "Asks Claude", "HTTPS", True{}}]},
      Container{"codex", "Codex", "The user's ChatGPT subscription.",
        Category.ModelApi{}, Ownership.Theirs{}, Exposure.Public{}, [], "", ["OpenAI"], [], [], [], [], [], []},
      Container{"claude", "Claude", "The user's Claude subscription.",
        Category.ModelApi{}, Ownership.Theirs{}, Exposure.Public{}, [], "", ["Anthropic"], [], [], [], [], [], []}
    ],
    Deployment{"https://dot.example.com", ["sessions"], [], [
      Node{"mac", "Pedro's Mac", "launchd", NodeRole.Server{}, Host.Owned{"MacBook"}, Platform.Unmanaged{}, [], ["web", "server"]}
    ]},
    release()}

# What the world looks like now. Hardcoded: nothing in V observes it yet.
def observed() -> Observed:
  Observed{["ui.bend", "state.bend", "copy.bend"], ["ui.bend", "state.bend", "copy.bend"], [],
    RepositoryStatus{"https://github.com/PedroAVJ/open-dot", "public", True{}, True{}}, []}

def main() -> IO(Unit):
  IO.print(show_all(plan(release(), observed())))
