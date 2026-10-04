import V

def system() -> System:
  System{
    [Code{GitHub{"PedroAVJ", "open-dot", OpenSource{"MIT"}}}],
    [Mac{Tailscale{9453}, [Application.MacOS{"ui"}]}]}

def main() -> IO(Unit):
  cli(system())
