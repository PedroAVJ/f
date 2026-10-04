import F
import ./state.bend as S
import ./screens/connect.bend as ConnectScreen
import ./screens/conversation.bend as ConversationScreen

def f(s: S.State) -> Tree:
  match s:
    case S.State{lang, url, backend, draft, history, busy}:
      match url:
        case S.Connect{}: ConnectScreen.connect(lang)
        case S.Conversation{id}: ConversationScreen.conversation(lang, draft, history, busy)
