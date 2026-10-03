import Base
import ./session.bend as Dot
import ../ai/protocol.bend as AI

# Native typed AI stream transitions carry transport/protocol error summaries.
type TextOutcome is Data:
  TextOutcome{message: Dot.Message, error: String}
type NativeTransition is Data:
  NativeTransition{stream: AI.StreamState, message: Dot.Message, error: String}

def consume_text(event: AI.TextEvent, state: AI.StreamState, message: Dot.Message) -> TextOutcome:
  match event:
    case AI.TextDelta{text}: TextOutcome{Dot.reduce_text(Dot.TextDelta{text}, message), ""}
    case AI.TextComplete{}: TextOutcome{Dot.reduce_text(Dot.TextResult{AI.text(state)}, message), ""}
    case AI.TextCancelled{}: TextOutcome{Dot.reduce_text(Dot.TextCancelled{}, message), ""}
    case AI.TextFailed{+error}: TextOutcome{Dot.reduce_text(Dot.TextError{AI.error_summary(error)}, message), AI.error_summary(error)}
    case AI.TextIgnored{}: TextOutcome{message, ""}

def transition_outcome(outcome: TextOutcome, state: AI.StreamState) -> NativeTransition:
  match outcome:
    case TextOutcome{message, error}: NativeTransition{state, message, error}

def consume_transition(transition: AI.Transition, message: Dot.Message) -> NativeTransition:
  match transition:
    case AI.Transition{+state, event}: transition_outcome(consume_text(event, state, message), state)

def reduce_frame(frame: AI.Frame, state: AI.StreamState, message: Dot.Message) -> NativeTransition:
  consume_transition(AI.reduce(frame, state), message)

# Foreign hosts create data through this constructor rather than forge ADT tags.
def streaming_message(id: String, source: Dot.MessageSource) -> Dot.Message:
  Dot.Message{id, Dot.AssistantMessage{}, source, "", Dot.StreamingMessage{}}
