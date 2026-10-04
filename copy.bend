import Base
import ../f/bend2/std/F/ui/kit.bend as K

type Copy is Data:
  Tagline{}
  WithCodex{}
  WithClaude{}
  Typing{}
  MessagePrompt{}
  Send{}

def t(+lang: K.Lang, c: Copy) -> String:
  match c:
    case Tagline{}: K.es_en(lang, "Tu asistente, con tu suscripción", "Your assistant, on your subscription")
    case WithCodex{}: K.es_en(lang, "Continuar con ChatGPT", "Continue with ChatGPT")
    case WithClaude{}: K.es_en(lang, "Continuar con Claude", "Continue with Claude")
    case Typing{}: K.es_en(lang, "Dot está escribiendo…", "Dot is typing…")
    case MessagePrompt{}: K.es_en(lang, "Escribe a Dot", "Write to Dot")
    case Send{}: K.es_en(lang, "Enviar", "Send")
