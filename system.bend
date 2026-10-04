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
    Deployment{"https://pedros-mac-mini.tail90fb4c.ts.net:9453", ["sessions"], [], [
      Node{"mac", "Pedro's Mac mini", "launchd", NodeRole.Server{}, Host.Owned{"Mac mini"},
        Platform.Launchd{Launchd{
          [Program{"dist/web/index.html", Build.Bend{"apps/web.bend"}}],
          [Agent{"web", "com.pedro.open-dot.web", "/usr/bin/python3",
            ["-m", "http.server", "4640", "--bind", "127.0.0.1", "--directory", "dist/web"], [], "open-dot-web", 4640}],
          [Serve{"web", 9453, 4640, "/"}]}},
        [], ["web"]}
    ]},
    Release{Repository{"open-dot", True{}}, [], []}}
