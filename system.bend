import V

def system() -> System:
  System{
    [Code{GitHub{"PedroAVJ", "open-dot", OpenSource{"MIT"}}}],
    [Mac{Tailscale{9453}, [Web{"apps/web"}]}]}

def main() -> IO(Unit):
  cli(system())
