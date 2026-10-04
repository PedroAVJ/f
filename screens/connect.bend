import UI

def connect() -> UI:
  screen([
    title(Text{"Dot", "Dot"}),
    caption(Text{"Your assistant, on your subscription", "Tu asistente, con tu suscripción"}),
    action(Text{"Continue with ChatGPT", "Continuar con ChatGPT"}),
    action_as(ButtonKind.Quiet{}, Text{"Continue with Claude", "Continuar con Claude"}, True{})])
