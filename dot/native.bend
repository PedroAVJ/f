import Base
import ./session.bend as Dot
import ../ai/voice.bend as Voice

# Application-approved native events enter the same typed continuity.
# The transport validates protocol ordering via AI voice reducers first.
type Fragment is Data:
  Fragment{message: Dot.Message, start_ms: U32, end_ms: U32}

def realtime_history(event: Voice.RealtimeEvent, id: String, session: Dot.Session, +history: Dot.Continuity) -> Dot.Continuity:
  match event:
    case Voice.InputTranscript{item, text}: Dot.history_record(session, Dot.Message{id, Dot.UserMessage{}, Dot.CallMessage{}, text, Dot.UserRecorded{}}, history)
    case Voice.OutputTranscript{response, text}: Dot.history_record(session, Dot.Message{id, Dot.AssistantMessage{}, Dot.CallMessage{}, text, Dot.CompleteMessage{}}, history)
    case _: history

def live_fragment(event: Voice.LiveEvent, id: String) -> Maybe<&2, Fragment>:
  match event:
    case Voice.InputFragment{text, start, end}: Some{Fragment{Dot.Message{id, Dot.UserMessage{}, Dot.CallMessage{}, text, Dot.FragmentMessage{}}, start, end}}
    case Voice.OutputFragment{text, start, end}: Some{Fragment{Dot.Message{id, Dot.AssistantMessage{}, Dot.CallMessage{}, text, Dot.FragmentMessage{}}, start, end}}
    case _: None{}

def fragment_history(fragment: Maybe<&2, Fragment>, session: Dot.Session, +history: Dot.Continuity) -> Dot.Continuity:
  match fragment:
    case Some{Fragment{message, start, end}}:
      Bool.pick(Dot.Continuity, U32.is_le(start, end), Dot.history_record(session, message, history), history)
    case None{}: history

def live_history(+event: Voice.LiveEvent, +id: String, +session: Dot.Session, +history: Dot.Continuity) -> Dot.Continuity:
  match event:
    case Voice.Delegated{delegation, offset}:
      Bool.pick(Dot.Continuity, Dot.call_record_permitted(session), Dot.history_task(Dot.Task{id, "Live delegation " ++ delegation, Dot.TaskReady{}, Dot.AwaitingApproval{}, "", ""}, history), history)
    case _: fragment_history(live_fragment(event, id), session, history)


# Generic foreign entry points keep wire fixtures in the host, not closed terms.
# Text AI framing is independently available from agent.bend.
def history_initial() -> Dot.Continuity:
  Dot.history_initial()

def session_initial() -> Dot.Session:
  Dot.initial()

def microphone_permission(allowed: Bool, session: Dot.Session) -> Dot.Session:
  Dot.update(Bool.pick(Dot.Command, allowed, Dot.GrantMic{}, Dot.DenyMic{}), session)

def begin_call(session: Dot.Session) -> Dot.Session:
  Dot.update(Dot.BeginCall{}, session)

def end_call(session: Dot.Session) -> Dot.Session:
  Dot.update(Dot.EndCall{}, session)

def cancel_call(session: Dot.Session) -> Dot.Session:
  Dot.update(Dot.Cancel{}, session)

def realtime_decoded(result: Result<&2, &2, String, Voice.RealtimeEvent>, id: String, session: Dot.Session, history: Dot.Continuity) -> Result<&2, &2, String, Dot.Continuity>:
  match result:
    case Done{event}: Done{realtime_history(event, id, session, history)}
    case Fail{error}: Fail{error}

def realtime_wire(wire: String, id: String, session: Dot.Session, history: Dot.Continuity) -> Result<&2, &2, String, Dot.Continuity>:
  realtime_decoded(Voice.realtime_decode(wire), id, session, history)

def live_decoded(result: Result<&2, &2, String, Voice.LiveEvent>, id: String, session: Dot.Session, history: Dot.Continuity) -> Result<&2, &2, String, Dot.Continuity>:
  match result:
    case Done{event}: Done{live_history(event, id, session, history)}
    case Fail{error}: Fail{error}

def live_wire(wire: String, id: String, session: Dot.Session, history: Dot.Continuity) -> Result<&2, &2, String, Dot.Continuity>:
  live_decoded(Voice.live_decode(wire), id, session, history)

def live_fragment_decoded(result: Result<&2, &2, String, Voice.LiveEvent>, id: String) -> Result<&2, &2, String, Maybe<&2, Fragment>>:
  match result:
    case Done{event}: Done{live_fragment(event, id)}
    case Fail{error}: Fail{error}

def live_fragment_wire(wire: String, id: String) -> Result<&2, &2, String, Maybe<&2, Fragment>>:
  live_fragment_decoded(Voice.live_decode(wire), id)

def task_decision(id: String, approved: Bool, history: Dot.Continuity) -> Dot.Continuity:
  Dot.history_task_event(Bool.pick(Dot.TaskEvent, approved, Dot.ApproveTask{}, Dot.RejectTask{}), id, history)

def task_start(id: String, history: Dot.Continuity) -> Dot.Continuity:
  Dot.history_task_event(Dot.StartTask{}, id, history)

def task_result(id: String, result: String, history: Dot.Continuity) -> Dot.Continuity:
  Dot.history_task_event(Dot.FinishTask{result}, id, history)

def task_cancel(id: String, history: Dot.Continuity) -> Dot.Continuity:
  Dot.history_task_event(Dot.CancelTask{}, id, history)
