import V

def system() -> System:
  System{"open-dot", "Open Dot", "Dot, on your own Codex or Claude subscription.",
    [Code{GitHub{"PedroAVJ", "open-dot", OpenSource{"MIT"}}}],
    [Deployment{"https://pedros-mac-mini.tail90fb4c.ts.net:9453", ["sessions"], [], [
      Node{"mac", "Pedro's Mac mini", "launchd", NodeRole.Server{}, Host.Owned{"Mac mini"},
        Platform.Launchd{Launchd{
          [Program{"dist/web/index.html", Build.Bend{"apps/web.bend"}}],
          [Agent{"web", "com.pedro.open-dot.web", "/usr/bin/python3",
            ["-m", "http.server", "4640", "--bind", "127.0.0.1", "--directory", "dist/web"], [], "open-dot-web", 4640}],
          [Serve{"web", 9453, 4640, "/"}]}},
        [], ["web"]}
    ]}]}

def main() -> IO(Unit):
  cli(system())
