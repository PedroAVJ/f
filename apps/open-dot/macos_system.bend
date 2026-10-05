import V

def system() -> System:
  System{
    [Code{GitHub{"PedroAVJ", "f", OpenSource{"Apache-2.0"}}}],
    [Mac{Tailscale{9453}, [Application.MacOS{"ui"}]}]}

def main() -> IO(Unit):
  cli(system())
