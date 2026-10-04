import F

type Copy is Data:
  Tagline{}
  WithCodex{}
  WithClaude{}
  Typing{}
  MessagePrompt{}
  Send{}

def t(+lang: Lang, c: Copy) -> String:
  match c:
    case Tagline{}: Lang.pick(lang, "Tu asistente, con tu suscripción", "Your assistant, on your subscription")
    case WithCodex{}: Lang.pick(lang, "Continuar con ChatGPT", "Continue with ChatGPT")
    case WithClaude{}: Lang.pick(lang, "Continuar con Claude", "Continue with Claude")
    case Typing{}: Lang.pick(lang, "Dot está escribiendo…", "Dot is typing…")
    case MessagePrompt{}: Lang.pick(lang, "Escribe a Dot", "Write to Dot")
    case Send{}: Lang.pick(lang, "Enviar", "Send")
