import UI

def composer() -> UI:
  stack([
    input(Text{"Write to Dot", "Escribe a Dot"}),
    action(Text{"Send", "Enviar"})])
