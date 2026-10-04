import F
import ./state as S
import ./copy as C

# What a person's input does: Continue with ChatGPT or Claude picks the backend and opens the conversation;
# typing edits the draft; Send says the draft, and Dot answers "…" (there is no server yet).
def update(s: S.State, i: Input) -> S.State:
  match s:
    case S.State{+lang, +url, +backend, +draft, +history, +busy}:
      match i:
        case Clicked{+label}:
          Bool.pick(S.State, String.eq(label, C.t(lang, C.WithCodex{})), S.State{lang, S.Conversation{"1"}, S.Codex{}, draft, history, busy},
            Bool.pick(S.State, String.eq(label, C.t(lang, C.WithClaude{})), S.State{lang, S.Conversation{"1"}, S.Claude{}, draft, history, busy},
              Bool.pick(S.State, String.eq(label, C.t(lang, C.Send{})) && Bool.not(String.is_empty(String.trim(draft))),
                S.State{lang, url, backend, "", List.append(&2, Line, history, [Line{Role.Mine{}, draft}, Line{Role.Near{}, "…"}]), busy},
                S.State{lang, url, backend, draft, history, busy})))
        case Typed{_, value}:
          S.State{lang, url, backend, value, history, busy}
        case Ignored{}:
          S.State{lang, url, backend, draft, history, busy}
