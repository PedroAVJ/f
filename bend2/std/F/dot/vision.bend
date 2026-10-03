import Base
import ../ai/wire_json.bend as J

# Camera input context only: bounded snapshots, no avatar or generated video.
type Permission is Data:
  Denied{}
  Granted{}
type Phase is Data:
  Off{}
  Starting{}
  Ready{}
  Pending{}
  Sent{}
  Accepted{}
  Error{}
type State is Data:
  State{permission: Permission, in_call: Bool, active: Bool, phase: Phase, latest_id: String, captured_at_ms: Nat, provider_event_id: String, failure_code: String}
type Metadata is Data:
  Metadata{id: String, captured_at_ms: Nat, byte_length: U32}
type VisionEvent is Data:
  Consent{}
  Revoke{}
  BeginCall{}
  EndCall{}
  StartRequested{}
  CameraStarted{}
  Stop{}
  Queue{metadata: Metadata}
  Submitted{id: String, event_id: String}
  Acknowledged{id: String, event_id: String}
  Rejected{id: String, code: String}
  Failed{code: String}

def initial() -> State:
  State{Denied{}, False{}, False{}, Off{}, "", 0n, "", ""}

def off(s: State) -> State:
  match s:
    case State{p, call, active, phase, id, at, event, error}: State{Denied{}, call, False{}, Off{}, "", at, "", ""}

def available(s: State) -> Bool:
  match s:
    case State{Granted{}, True{}, True{}, phase, id, at, event, error}: True{}
    case _: False{}

def can_queue(s: State) -> Bool:
  match s:
    case State{Granted{}, True{}, True{}, Ready{}, id, at, event, error}: True{}
    case State{Granted{}, True{}, True{}, Accepted{}, id, at, event, error}: True{}
    case State{Granted{}, True{}, True{}, Error{}, id, at, event, error}: True{}
    case _: False{}

def queue_allowed(+metadata: Metadata, +s: State) -> Bool:
  match metadata s:
    case Metadata{+id, +at, +bytes} State{p, call, active, phase, old, +previous, event, error}:
      can_queue(s) && Bool.not(String.eq(id, "")) && (bytes > 0 : U32) && (bytes <= 262144 : U32) && Nat.is_ge(at, previous) && (String.eq(old, "") || Nat.is_ge(at, Nat.add(previous, 1000n)))

def queued(metadata: Metadata, s: State) -> State:
  match metadata s:
    case Metadata{id, at, bytes} State{p, call, active, phase, old, previous, event, error}: State{p, call, active, Pending{}, id, at, "", ""}

def submit(id: String, event_id: String, +s: State) -> State:
  match s:
    case State{p, call, active, Pending{}, +old, at, event, error}: Bool.pick(State, String.eq(id, old), State{p, call, active, Sent{}, old, at, event_id, ""}, s)
    case _: s

def acknowledge(id: String, event_id: String, +s: State) -> State:
  match s:
    case State{p, call, active, Sent{}, +old, at, +event, error}: Bool.pick(State, String.eq(id, old) && String.eq(event_id, event), State{p, call, active, Accepted{}, old, at, event, ""}, s)
    case _: s

def reject(id: String, code: String, +s: State) -> State:
  match s:
    case State{p, call, True{}, phase, +old, at, event, error}: Bool.pick(State, String.eq(id, old), State{p, call, True{}, Error{}, old, at, event, code}, s)
    case _: s

def failed(code: String, s: State) -> State:
  match s:
    case State{p, call, True{}, phase, id, at, event, error}: State{p, call, True{}, Error{}, id, at, event, code}
    case State{p, call, False{}, phase, id, at, event, error}: State{Denied{}, call, False{}, Error{}, id, at, event, code}

def reduce(event: VisionEvent, +s: State) -> State:
  match event s:
    case Consent{} State{p, call, active, phase, id, at, event, error}: State{Granted{}, call, active, phase, id, at, event, error}
    case BeginCall{} State{p, call, active, phase, id, at, event, error}: State{p, True{}, active, phase, id, at, event, error}
    case EndCall{} State{p, call, active, phase, id, at, event, error}: State{Denied{}, False{}, False{}, Off{}, "", at, "", ""}
    case Revoke{} state: off(state)
    case Stop{} state: off(state)
    case StartRequested{} State{Granted{}, True{}, False{}, phase, id, at, event, error}: State{Granted{}, True{}, False{}, Starting{}, id, at, event, ""}
    case CameraStarted{} State{Granted{}, True{}, False{}, Starting{}, id, at, event, error}: State{Granted{}, True{}, True{}, Ready{}, id, at, event, ""}
    case Queue{+metadata} +state: Bool.pick(State, queue_allowed(metadata, state), queued(metadata, state), state)
    case Submitted{id, event} state: submit(id, event, state)
    case Acknowledged{id, event} state: acknowledge(id, event, state)
    case Rejected{id, code} state: reject(id, code, state)
    case Failed{code} state: failed(code, state)
    case _ _: s

def phase_name(phase: Phase) -> String:
  match phase:
    case Off{}: "off"
    case Starting{}: "starting"
    case Ready{}: "ready"
    case Pending{}: "pending"
    case Sent{}: "sent"
    case Accepted{}: "accepted"
    case Error{}: "error"

def status(s: State) -> String:
  match s:
    case State{p, call, active, phase, id, at, event, error}: phase_name(phase)

type ImageFormat is Data:
  PNG{}
  JPEG{}
type ImageContext is Data:
  ImageContext{metadata: Metadata, format: ImageFormat, payload_base64: String}

def mime(format: ImageFormat) -> String:
  match format:
    case PNG{}: "image/png"
    case JPEG{}: "image/jpeg"

def realtime_image(event_id: String, item_id: String, image: ImageContext) -> String:
  match image:
    case ImageContext{metadata, format, payload}:
      "{\"type\":\"conversation.item.create\",\"event_id\":" ++ J.quote(event_id) ++ ",\"item\":{\"id\":" ++ J.quote(item_id) ++ ",\"type\":\"message\",\"role\":\"user\",\"content\":[{\"type\":\"input_image\",\"image_url\":" ++ J.quote("data:" ++ mime(format) ++ ";base64," ++ payload) ++ "}]}}"

# GPT-Live accepts concise backend visual findings, never the image bytes.
def live_context(event_id: String, findings: String) -> String:
  "{\"type\":\"session.instructions.append\",\"event_id\":" ++ J.quote(event_id) ++ ",\"delegation_id\":null,\"content\":" ++ J.quote(findings) ++ "}"
