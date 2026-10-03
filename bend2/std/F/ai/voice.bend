import Base
import ./wire_json.bend as J

# Native voice protocol subset. JSON is private to codecs, never public events.
# PCM payloads are encoded bytes; the host owns socket/audio IO, not transitions.
type RealtimeConfig is Data:
  RealtimeConfig{instructions: String, voice: String, transcription_model: String}
type RealtimeCommand is Data:
  Configure{config: RealtimeConfig}
  AppendAudio{pcm16_base64: String}
  CommitAudio{}
  ClearAudio{}
  CreateResponse{}
  CancelResponse{response_id: String}
type ResponseStatus is Data:
  Completed{}
  Cancelled{}
  Failed{}
  Incomplete{}
type TokenUsage is Data:
  ReportedTokens{input_tokens: U32, output_tokens: U32}
  UsageUnavailable{}
type RealtimeEvent is Data:
  SessionCreated{session_id: String}
  SessionUpdated{session_id: String}
  ResponseCreated{response_id: String}
  AudioDelta{response_id: String, pcm16_base64: String}
  OutputTranscript{response_id: String, text: String}
  InputTranscript{item_id: String, text: String}
  ResponseDone{response_id: String, status: ResponseStatus, usage: TokenUsage}
  ProviderError{code: String, message: String}
  UnknownRealtime{event_type: String}
type ProtocolPhase is Data:
  Connecting{}
  Ready{}
  Closing{}
  Closed{}
  Broken{code: String}
type RealtimeState is Data:
  RealtimeState{phase: ProtocolPhase, session_id: String, active_responses: List<&2, String>}

def realtime_initial() -> RealtimeState:
  RealtimeState{Connecting{}, "", []}

def command_name(command: RealtimeCommand) -> String:
  match command:
    case Configure{c}: "session.update"
    case AppendAudio{audio}: "input_audio_buffer.append"
    case CommitAudio{}: "input_audio_buffer.commit"
    case ClearAudio{}: "input_audio_buffer.clear"
    case CreateResponse{}: "response.create"
    case CancelResponse{id}: "response.cancel"

def realtime_encode(command: RealtimeCommand) -> String:
  match command:
    case Configure{RealtimeConfig{instructions, voice, model}}:
      "{\"type\":\"session.update\",\"session\":{\"type\":\"realtime\",\"instructions\":" ++ J.quote(instructions) ++ ",\"audio\":{\"input\":{\"format\":{\"type\":\"audio/pcm\",\"rate\":24000},\"transcription\":{\"model\":" ++ J.quote(model) ++ "},\"turn_detection\":null},\"output\":{\"format\":{\"type\":\"audio/pcm\",\"rate\":24000},\"voice\":" ++ J.quote(voice) ++ "}}}}"
    case AppendAudio{audio}: "{\"type\":\"input_audio_buffer.append\",\"audio\":" ++ J.quote(audio) ++ "}"
    case CancelResponse{id}: "{\"type\":\"response.cancel\",\"response_id\":" ++ J.quote(id) ++ "}"
    case CreateResponse{}: "{\"type\":\"response.create\",\"response\":{}}"
    case c: "{\"type\":" ++ J.quote(command_name(c)) ++ "}"

# PCM16 mono base64 frames: ASCII alphabet, complete quartets/samples, local bound.
def base64_char(+code: U32) -> Bool:
  ((code >= 65 : U32) && (code <= 90 : U32)) || ((code >= 97 : U32) && (code <= 122 : U32)) || ((code >= 48 : U32) && (code <= 57 : U32)) || U32.is_eq(code, 43) || U32.is_eq(code, 47)

def base64_scan(s: String, valid: Bool, +padding: U32) -> Maybe<&2, U32>:
  match s valid:
    case _ False{}: None{}
    case SNil{} True{}: Some{padding}
    case SCon{'=', rest} True{}: base64_scan(rest, (padding < 2 : U32), (padding + 1 : U32))
    case SCon{Chr{code}, rest} True{}: base64_scan(rest, U32.is_eq(padding, 0) && base64_char(code), padding)

def base64_finish(+length: Nat, padding: Maybe<&2, U32>) -> Bool:
  match padding:
    case Some{+pads}: (pads <= 2 : U32) && Nat.is_ne(length, 0n) && (U32.from_nat(length) <= 262144 : U32) && Nat.is_eq(Nat.mod(length, 4n), 0n) && Nat.is_eq(Nat.mod(Nat.sub(Nat.mul(Nat.div(length, 4n), 3n), U32.to_nat(pads)), 2n), 0n)
    case _: False{}

def pcm16_limited(allowed: Bool, +audio: String) -> Bool:
  match allowed:
    case False{}: False{}
    case True{}: base64_finish(String.length(audio), base64_scan(audio, True{}, 0))

def pcm16_frame(+audio: String) -> Bool:
  pcm16_limited((U32.from_nat(String.length(audio)) <= 262144 : U32), audio)

# Strict accessors: absent/wrong type never fabricates an empty success value.
def text_value(value: Maybe<&2, J.Json>) -> Maybe<&2, String>:
  match value:
    case Some{J.Text{s}}: Some{s}
    case _: None{}

def text(value: J.Json, key: String) -> Maybe<&2, String>:
  text_value(J.get(value, key))

def child(value: J.Json, key: String) -> J.Json:
  Maybe.default(&2, J.Json, J.get(value, key), J.Null{})

def number_value(value: Maybe<&2, J.Json>) -> Maybe<&2, F32>:
  match value:
    case Some{J.Number{s}}: F32.read(s)
    case _: None{}

def number(value: J.Json, key: String) -> Maybe<&2, F32>:
  number_value(J.get(value, key))

def integer_exact(+wire: String, parsed: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match parsed:
    case Some{+value}: Bool.pick(Maybe<&2, U32>, String.eq(wire, U32.show(value)), Some{value}, None{})
    case _: None{}

def integer_value(value: Maybe<&2, J.Json>) -> Maybe<&2, U32>:
  match value:
    case Some{J.Number{+s}}: integer_exact(s, U32.read(s))
    case _: None{}

def integer(value: J.Json, key: String) -> Maybe<&2, U32>:
  integer_value(J.get(value, key))

def status(s: String) -> Maybe<&2, ResponseStatus>:
  match s:
    case "completed": Some{Completed{}}
    case "cancelled": Some{Cancelled{}}
    case "failed": Some{Failed{}}
    case "incomplete": Some{Incomplete{}}
    case _: None{}

def rt_identity(kind: String, id: Maybe<&2, String>) -> Result<&2, &2, String, RealtimeEvent>:
  match kind id:
    case "session.created" Some{s}: Done{SessionCreated{s}}
    case "session.updated" Some{s}: Done{SessionUpdated{s}}
    case "response.created" Some{s}: Done{ResponseCreated{s}}
    case _ _: Fail{"identity_field"}

def rt_pair(kind: String, id: Maybe<&2, String>, value: Maybe<&2, String>) -> Result<&2, &2, String, RealtimeEvent>:
  match kind id value:
    case "response.output_audio.delta" Some{i} Some{+v}: Bool.pick(Result<&2, &2, String, RealtimeEvent>, pcm16_frame(v), Done{AudioDelta{i, v}}, Fail{"invalid_pcm16"})
    case "response.output_audio_transcript.done" Some{i} Some{v}: Done{OutputTranscript{i, v}}
    case "conversation.item.input_audio_transcription.completed" Some{i} Some{v}: Done{InputTranscript{i, v}}
    case _ _ _: Fail{"event_fields"}

def rt_tokens(i: Maybe<&2, U32>, o: Maybe<&2, U32>) -> Maybe<&2, TokenUsage>:
  match i o:
    case Some{i} Some{o}: Some{ReportedTokens{i, o}}
    case _ _: None{}

def rt_usage(+value: J.Json) -> Maybe<&2, TokenUsage>:
  match value:
    case J.Null{}: Some{UsageUnavailable{}}
    case J.Object{fields}: rt_tokens(integer(value, "input_tokens"), integer(value, "output_tokens"))
    case _: None{}

def rt_done(id: Maybe<&2, String>, st: Maybe<&2, ResponseStatus>, usage: Maybe<&2, TokenUsage>) -> Result<&2, &2, String, RealtimeEvent>:
  match id st usage:
    case Some{id} Some{s} Some{u}: Done{ResponseDone{id, s, u}}
    case _ _ _: Fail{"response_terminal"}

def status_value(s: Maybe<&2, String>) -> Maybe<&2, ResponseStatus>:
  match s:
    case Some{s}: status(s)
    case _: None{}

def rt_error(code: Maybe<&2, String>, message: Maybe<&2, String>) -> Result<&2, &2, String, RealtimeEvent>:
  match message:
    case Some{s}: Done{ProviderError{Maybe.default(&2, String, code, "provider_error"), s}}
    case _: Fail{"provider_error_frame"}

type RealtimeWireKind is Data:
  RTSessionCreated{}
  RTSessionUpdated{}
  RTResponseCreated{}
  RTAudioDelta{}
  RTOutputTranscript{}
  RTInputTranscript{}
  RTResponseDone{}
  RTError{}
  RTUnknown{}


# Shallow tags avoid compiler expansion of long, overlapping String patterns.
def realtime_wire_kind(+kind: String) -> RealtimeWireKind:
  Bool.pick(RealtimeWireKind, String.eq(kind, "session.created"), RTSessionCreated{}, Bool.pick(RealtimeWireKind, String.eq(kind, "session.updated"), RTSessionUpdated{}, Bool.pick(RealtimeWireKind, String.eq(kind, "response.created"), RTResponseCreated{}, Bool.pick(RealtimeWireKind, String.eq(kind, "response.output_audio.delta"), RTAudioDelta{}, Bool.pick(RealtimeWireKind, String.eq(kind, "response.output_audio_transcript.done"), RTOutputTranscript{}, Bool.pick(RealtimeWireKind, String.eq(kind, "conversation.item.input_audio_transcription.completed"), RTInputTranscript{}, Bool.pick(RealtimeWireKind, String.eq(kind, "response.done"), RTResponseDone{}, Bool.pick(RealtimeWireKind, String.eq(kind, "error"), RTError{}, RTUnknown{}))))))))

def realtime_fields(wire_kind: RealtimeWireKind, kind: String, +value: J.Json) -> Result<&2, &2, String, RealtimeEvent>:
  match wire_kind:
    case RTSessionCreated{}: rt_identity(kind, text(child(value, "session"), "id"))
    case RTSessionUpdated{}: rt_identity(kind, text(child(value, "session"), "id"))
    case RTResponseCreated{}: rt_identity(kind, text(child(value, "response"), "id"))
    case RTAudioDelta{}: rt_pair(kind, text(value, "response_id"), text(value, "delta"))
    case RTOutputTranscript{}: rt_pair(kind, text(value, "response_id"), text(value, "transcript"))
    case RTInputTranscript{}: rt_pair(kind, text(value, "item_id"), text(value, "transcript"))
    case RTResponseDone{}:
      +r = child(value, "response")
      +u = child(r, "usage")
      rt_done(text(r, "id"), status_value(text(r, "status")), rt_usage(u))
    case RTError{}:
      +e = child(value, "error")
      rt_error(text(e, "code"), text(e, "message"))
    case RTUnknown{}: Done{UnknownRealtime{kind}}

def realtime_event(+kind: String, value: J.Json) -> Result<&2, &2, String, RealtimeEvent>:
  realtime_fields(realtime_wire_kind(kind), kind, value)

def realtime_kind(kind: Maybe<&2, String>, value: J.Json) -> Result<&2, &2, String, RealtimeEvent>:
  match kind:
    case Some{s}: realtime_event(s, value)
    case _: Fail{"event_type"}

def realtime_parsed(result: Result<&1, &1, String, J.Json>) -> Result<&2, &2, String, RealtimeEvent>:
  match result:
    case Fail{e}: Fail{e}
    case Done{+v}: realtime_kind(text(v, "type"), v)

def realtime_limited(allowed: Bool, wire: String) -> Result<&2, &2, String, RealtimeEvent>:
  match allowed:
    case False{}: Fail{"frame_limit"}
    case True{}: realtime_parsed(J.read(wire))

def realtime_decode(+wire: String) -> Result<&2, &2, String, RealtimeEvent>:
  realtime_limited((U32.from_nat(String.length(wire)) <= 1048576 : U32), wire)

def contains(+xs: List<&2, String>, id: String) -> Bool:
  List.contains(~String, ~String.eq, xs, id)

def remove_go(xs: List<&2, String>, +id: String, +acc: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}: List.reverse(&2, String, acc)
    case Con{+head, tail}: remove_go(tail, id, Bool.pick(List<&2, String>, String.eq(head, id), acc, Con{head, acc}))

def remove(xs: List<&2, String>, id: String) -> List<&2, String>:
  remove_go(xs, id, [])

def realtime_response(event: RealtimeEvent, +s: RealtimeState) -> RealtimeState:
  match event s:
    case ResponseCreated{+id} RealtimeState{p, session, +active}:
      Bool.pick(RealtimeState, String.eq(id, "") || contains(active, id), RealtimeState{Broken{"response_identity"}, session, active}, RealtimeState{p, session, Con{id, active}})
    case ResponseDone{+id, status, usage} RealtimeState{p, session, +active}:
      Bool.pick(RealtimeState, contains(active, id), RealtimeState{p, session, remove(active, id)}, RealtimeState{Broken{"response_order"}, session, active})
    case AudioDelta{+id, bytes} RealtimeState{p, session, +active}:
      Bool.pick(RealtimeState, contains(active, id), s, RealtimeState{Broken{"response_order"}, session, active})
    case OutputTranscript{+id, text} RealtimeState{p, session, +active}:
      Bool.pick(RealtimeState, contains(active, id), s, RealtimeState{Broken{"response_order"}, session, active})
    case _ _: s

def realtime_reduce(event: RealtimeEvent, +s: RealtimeState) -> RealtimeState:
  match event s:
    case _ RealtimeState{Broken{code}, id, active}: s
    case _ RealtimeState{Closed{}, id, active}: s
    case SessionCreated{+id} RealtimeState{Connecting{}, old, active}:
      Bool.pick(RealtimeState, String.eq(id, ""), RealtimeState{Broken{"session_identity"}, old, active}, RealtimeState{Ready{}, id, active})
    case SessionCreated{id} RealtimeState{p, old, active}: RealtimeState{Broken{"session_identity"}, old, active}
    case ProviderError{code, message} RealtimeState{Connecting{}, id, active}: RealtimeState{Broken{code}, id, active}
    case _ RealtimeState{Connecting{}, id, active}: RealtimeState{Broken{"before_ready"}, id, active}
    case SessionUpdated{+id} RealtimeState{p, +old, active}:
      Bool.pick(RealtimeState, String.eq(id, old), s, RealtimeState{Broken{"session_identity"}, old, active})
    case e state: realtime_response(e, state)

# GPT-Live is continuous audio plus application-owned delegation, not Realtime.
type LiveConfig is Data:
  LiveConfig{model: String, instructions: String, voice: String, store: Bool}
type ContextKind is Data:
  Commentary{}
  Thinking{}
  Instructions{}
type LiveCommand is Data:
  StartSession{event_id: String, config: LiveConfig}
  LiveAudio{pcm16_base64: String}
  AppendContext{event_id: String, delegation_id: Maybe<&2, String>, kind: ContextKind, content: String}
  Mute{event_id: String}
  Unmute{event_id: String}
  CloseSession{}
type LiveEvent is Data:
  Started{session_id: String}
  Updated{session_id: String}
  Delegated{delegation_id: String, offset_ms: U32}
  LiveAudioDelta{pcm16_base64: String}
  InputFragment{text: String, start_ms: U32, end_ms: U32}
  OutputFragment{text: String, start_ms: U32, end_ms: U32}
  ContextAccepted{client_event_id: String, kind: ContextKind}
  MuteAccepted{client_event_id: String, muted: Bool}
  UsageUpdated{seconds: F32}
  SessionClosed{session_id: Maybe<&2, String>, reason: String, seconds: F32}
  LiveProviderError{code: String, message: String, client_event_id: Maybe<&2, String>}
  UnknownLive{event_type: String}
type PendingCommand is Data:
  PendingContext{event_id: String, delegation_id: Maybe<&2, String>, kind: ContextKind}
  PendingMute{event_id: String, muted: Bool}
type LiveState is Data:
  LiveState{phase: ProtocolPhase, session_id: String, delegations: List<&2, String>, pending: List<&2, PendingCommand>, used_ids: List<&2, String>, usage_seconds: F32, finalized: Bool}

def live_initial() -> LiveState:
  LiveState{Connecting{}, "", [], [], [], 0.0, False{}}

def context_name(kind: ContextKind) -> String:
  match kind:
    case Commentary{}: "session.commentary.append"
    case Thinking{}: "session.thinking.append"
    case Instructions{}: "session.instructions.append"

def optional_id(id: Maybe<&2, String>) -> String:
  match id:
    case Some{s}: J.quote(s)
    case None{}: "null"

def live_encode(command: LiveCommand) -> String:
  match command:
    case StartSession{id, LiveConfig{model, instructions, voice, store}}:
      "{\"type\":\"session.start\",\"event_id\":" ++ J.quote(id) ++ ",\"session\":{\"model\":" ++ J.quote(model) ++ ",\"instructions\":" ++ J.quote(instructions) ++ ",\"store\":" ++ Bool.pick(String, store, "true", "false") ++ ",\"audio\":{\"format\":{\"type\":\"audio/pcm\",\"rate\":24000},\"output\":{\"voice\":" ++ J.quote(voice) ++ "}},\"delegation\":{\"type\":\"client\"}}}"
    case LiveAudio{audio}: "{\"type\":\"session.input_audio.append\",\"audio\":" ++ J.quote(audio) ++ "}"
    case AppendContext{id, delegation, kind, content}:
      "{\"type\":" ++ J.quote(context_name(kind)) ++ ",\"event_id\":" ++ J.quote(id) ++ ",\"delegation_id\":" ++ optional_id(delegation) ++ ",\"content\":" ++ J.quote(content) ++ "}"
    case Mute{id}: "{\"type\":\"session.input_audio.mute\",\"event_id\":" ++ J.quote(id) ++ "}"
    case Unmute{id}: "{\"type\":\"session.input_audio.unmute\",\"event_id\":" ++ J.quote(id) ++ "}"
    case CloseSession{}: "{\"type\":\"session.close\"}"

# Numeric usage uses Bend F32: finite nonnegative values only; no billing precision claim.
def live_identity(kind: String, id: Maybe<&2, String>) -> Result<&2, &2, String, LiveEvent>:
  match kind id:
    case "session.started" Some{s}: Done{Started{s}}
    case "session.updated" Some{s}: Done{Updated{s}}
    case _ _: Fail{"session_identity"}

def live_delegation(id: Maybe<&2, String>, target: Maybe<&2, String>, offset: Maybe<&2, U32>) -> Result<&2, &2, String, LiveEvent>:
  match id target offset:
    case Some{id} Some{"client"} Some{ms}: Done{Delegated{id, ms}}
    case _ _ _: Fail{"delegation_target"}

def live_audio(audio: Maybe<&2, String>) -> Result<&2, &2, String, LiveEvent>:
  match audio:
    case Some{+s}: Bool.pick(Result<&2, &2, String, LiveEvent>, pcm16_frame(s), Done{LiveAudioDelta{s}}, Fail{"invalid_pcm16"})
    case _: Fail{"audio_frame"}

def live_fragment(kind: String, text: Maybe<&2, String>, start: Maybe<&2, U32>, end: Maybe<&2, U32>) -> Result<&2, &2, String, LiveEvent>:
  match kind text start end:
    case "session.input_transcript.delta" Some{s} Some{a} Some{b}: Done{InputFragment{s, a, b}}
    case "session.output_transcript.delta" Some{s} Some{a} Some{b}: Done{OutputFragment{s, a, b}}
    case _ _ _ _: Fail{"transcript_frame"}

def live_context_ack(id: Maybe<&2, String>, kind: ContextKind) -> Result<&2, &2, String, LiveEvent>:
  match id:
    case Some{s}: Done{ContextAccepted{s, kind}}
    case _: Fail{"ack_id"}

def live_mute_ack(id: Maybe<&2, String>, muted: Bool) -> Result<&2, &2, String, LiveEvent>:
  match id:
    case Some{s}: Done{MuteAccepted{s, muted}}
    case _: Fail{"ack_id"}

def live_usage(seconds: Maybe<&2, F32>) -> Result<&2, &2, String, LiveEvent>:
  match seconds:
    case Some{s}: Done{UsageUpdated{s}}
    case _: Fail{"usage_frame"}

def live_final(id: Maybe<&2, String>, reason: Maybe<&2, String>, seconds: Maybe<&2, F32>) -> Result<&2, &2, String, LiveEvent>:
  match reason seconds:
    case Some{r} Some{s}: Done{SessionClosed{id, r, s}}
    case _ _: Fail{"final_usage"}

def live_error(code: Maybe<&2, String>, message: Maybe<&2, String>, id: Maybe<&2, String>) -> Result<&2, &2, String, LiveEvent>:
  match message:
    case Some{s}: Done{LiveProviderError{Maybe.default(&2, String, code, "provider_error"), s, id}}
    case _: Fail{"provider_error_frame"}

type LiveWireKind is Data:
  LVStarted{}
  LVUpdated{}
  LVDelegated{}
  LVAudioDelta{}
  LVInputFragment{}
  LVOutputFragment{}
  LVCommentaryAccepted{}
  LVThinkingAccepted{}
  LVInstructionsAccepted{}
  LVMuted{}
  LVUnmuted{}
  LVUsageUpdated{}
  LVClosed{}
  LVError{}
  LVUnknown{}


# Shallow tags avoid compiler expansion of long, overlapping String patterns.
def live_wire_kind(+kind: String) -> LiveWireKind:
  Bool.pick(LiveWireKind, String.eq(kind, "session.started"), LVStarted{}, Bool.pick(LiveWireKind, String.eq(kind, "session.updated"), LVUpdated{}, Bool.pick(LiveWireKind, String.eq(kind, "session.delegation.created"), LVDelegated{}, Bool.pick(LiveWireKind, String.eq(kind, "session.output_audio.delta"), LVAudioDelta{}, Bool.pick(LiveWireKind, String.eq(kind, "session.input_transcript.delta"), LVInputFragment{}, Bool.pick(LiveWireKind, String.eq(kind, "session.output_transcript.delta"), LVOutputFragment{}, Bool.pick(LiveWireKind, String.eq(kind, "session.commentary.appended"), LVCommentaryAccepted{}, Bool.pick(LiveWireKind, String.eq(kind, "session.thinking.appended"), LVThinkingAccepted{}, Bool.pick(LiveWireKind, String.eq(kind, "session.instructions.appended"), LVInstructionsAccepted{}, Bool.pick(LiveWireKind, String.eq(kind, "session.input_audio.muted"), LVMuted{}, Bool.pick(LiveWireKind, String.eq(kind, "session.input_audio.unmuted"), LVUnmuted{}, Bool.pick(LiveWireKind, String.eq(kind, "session.usage.updated"), LVUsageUpdated{}, Bool.pick(LiveWireKind, String.eq(kind, "session.closed"), LVClosed{}, Bool.pick(LiveWireKind, String.eq(kind, "error"), LVError{}, LVUnknown{}))))))))))))))

def live_fields(wire_kind: LiveWireKind, kind: String, +v: J.Json) -> Result<&2, &2, String, LiveEvent>:
  match wire_kind:
    case LVStarted{}: live_identity(kind, text(child(v, "session"), "id"))
    case LVUpdated{}: live_identity(kind, text(child(v, "session"), "id"))
    case LVDelegated{}:
      +d = child(v, "delegation")
      live_delegation(text(d, "id"), text(d, "target"), integer(v, "offset_ms"))
    case LVAudioDelta{}: live_audio(text(v, "delta"))
    case LVInputFragment{}: live_fragment(kind, text(v, "delta"), integer(v, "start_ms"), integer(v, "end_ms"))
    case LVOutputFragment{}: live_fragment(kind, text(v, "delta"), integer(v, "start_ms"), integer(v, "end_ms"))
    case LVCommentaryAccepted{}: live_context_ack(text(v, "client_event_id"), Commentary{})
    case LVThinkingAccepted{}: live_context_ack(text(v, "client_event_id"), Thinking{})
    case LVInstructionsAccepted{}: live_context_ack(text(v, "client_event_id"), Instructions{})
    case LVMuted{}: live_mute_ack(text(v, "client_event_id"), True{})
    case LVUnmuted{}: live_mute_ack(text(v, "client_event_id"), False{})
    case LVUsageUpdated{}: live_usage(number(child(v, "usage"), "seconds"))
    case LVClosed{}: live_final(text(child(v, "session"), "id"), text(v, "reason"), number(child(v, "usage"), "seconds"))
    case LVError{}:
      +e = child(v, "error")
      live_error(text(e, "code"), text(e, "message"), text(e, "client_event_id"))
    case LVUnknown{}: Done{UnknownLive{kind}}

def live_event(+kind: String, v: J.Json) -> Result<&2, &2, String, LiveEvent>:
  live_fields(live_wire_kind(kind), kind, v)

def live_kind(kind: Maybe<&2, String>, value: J.Json) -> Result<&2, &2, String, LiveEvent>:
  match kind:
    case Some{s}: live_event(s, value)
    case _: Fail{"event_type"}

def live_parsed(result: Result<&1, &1, String, J.Json>) -> Result<&2, &2, String, LiveEvent>:
  match result:
    case Fail{e}: Fail{e}
    case Done{+v}: live_kind(text(v, "type"), v)

def live_limited(allowed: Bool, wire: String) -> Result<&2, &2, String, LiveEvent>:
  match allowed:
    case False{}: Fail{"frame_limit"}
    case True{}: live_parsed(J.read(wire))

def live_decode(+wire: String) -> Result<&2, &2, String, LiveEvent>:
  live_limited((U32.from_nat(String.length(wire)) <= 1048576 : U32), wire)

def context_eq(a: ContextKind, b: ContextKind) -> Bool:
  String.eq(context_name(a), context_name(b))

def pending_id(p: PendingCommand) -> String:
  match p:
    case PendingContext{id, delegation, kind}: id
    case PendingMute{id, muted}: id

def bool_eq(a: Bool, b: Bool) -> Bool:
  match a b:
    case True{} True{}: True{}
    case False{} False{}: True{}
    case _ _: False{}

def ack_matches(event: LiveEvent, pending: PendingCommand) -> Bool:
  match event pending:
    case ContextAccepted{+id, kind} PendingContext{+other, delegation, p}: String.eq(id, other) && context_eq(kind, p)
    case MuteAccepted{+id, muted} PendingMute{+other, value}: String.eq(id, other) && bool_eq(muted, value)
    case _ _: False{}

def has_ack(+event: LiveEvent, pending: List<&2, PendingCommand>) -> Bool:
  match pending:
    case Nil{}: False{}
    case Con{p, tail}: ack_matches(event, p) || has_ack(event, tail)

def remove_ack_go(+event: LiveEvent, pending: List<&2, PendingCommand>, +acc: List<&2, PendingCommand>) -> List<&2, PendingCommand>:
  match pending:
    case Nil{}: List.reverse(&2, PendingCommand, acc)
    case Con{+p, tail}: remove_ack_go(event, tail, Bool.pick(List<&2, PendingCommand>, ack_matches(event, p), acc, Con{p, acc}))

def remove_ack(event: LiveEvent, pending: List<&2, PendingCommand>) -> List<&2, PendingCommand>:
  remove_ack_go(event, pending, [])

def live_break(code: String, s: LiveState) -> LiveState:
  match s:
    case LiveState{phase, id, ds, ps, used, seconds, finalized}: LiveState{Broken{code}, id, ds, [], used, seconds, finalized}

def live_ready(s: LiveState) -> Bool:
  match s:
    case LiveState{Ready{}, id, ds, ps, used, seconds, finalized}: True{}
    case _: False{}

def remember(+command: PendingCommand, s: LiveState) -> Result<&2, &2, String, LiveState>:
  match s:
    case LiveState{phase, id, ds, +ps, +used, seconds, finalized}:
      +key = pending_id(command)
      Bool.pick(Result<&2, &2, String, LiveState>, String.eq(key, "") || contains(used, key) || (U32.from_nat(List.length(&2, String, used)) >= 1024 : U32) || (U32.from_nat(List.length(&2, PendingCommand, ps)) >= 256 : U32), Fail{"command_id_or_limit"}, Done{LiveState{phase, id, ds, Con{command, ps}, Con{key, used}, seconds, finalized}})

def delegation_valid(delegation: Maybe<&2, String>, +ds: List<&2, String>) -> Bool:
  match delegation:
    case None{}: True{}
    case Some{id}: contains(ds, id)

# Preparing a command reserves its acknowledgment ID BEFORE raw transport send.
# Context has a local 4000-codepoint bound; provider 500-token budgeting remains
# caller responsibility. This slice has no startup history/reconnect/compaction.
# A transport failure must call live_abort; no state is silently retried.
def live_config_valid(config: LiveConfig) -> Bool:
  match config:
    case LiveConfig{model, instructions, voice, store}: Bool.not(String.eq(model, "")) && Bool.not(String.eq(voice, ""))

def live_prepare(command: LiveCommand, +s: LiveState) -> Result<&2, &2, String, LiveState>:
  match command s:
    case StartSession{+event_id, config} LiveState{Connecting{}, id, ds, ps, +used, seconds, finalized}:
      Bool.pick(Result<&2, &2, String, LiveState>, String.eq(event_id, "") || Nat.is_ne(List.length(&2, String, used), 0n) || Bool.not(live_config_valid(config)), Fail{"command_id"}, Done{LiveState{Connecting{}, id, ds, ps, Con{event_id, used}, seconds, finalized}})
    case AppendContext{event_id, +delegation, kind, +content} LiveState{Ready{}, id, +ds, ps, used, seconds, finalized}:
      Bool.pick(Result<&2, &2, String, LiveState>, delegation_valid(delegation, ds) && Bool.not(String.eq(content, "")) && (U32.from_nat(String.length(content)) <= 4000 : U32), remember(PendingContext{event_id, delegation, kind}, s), Fail{"delegation_or_content"})
    case Mute{event_id} LiveState{Ready{}, id, ds, ps, used, seconds, finalized}: remember(PendingMute{event_id, True{}}, s)
    case Unmute{event_id} LiveState{Ready{}, id, ds, ps, used, seconds, finalized}: remember(PendingMute{event_id, False{}}, s)
    case CloseSession{} LiveState{Ready{}, id, ds, ps, used, seconds, finalized}: Done{LiveState{Closing{}, id, ds, ps, used, seconds, finalized}}
    case LiveAudio{audio} LiveState{Ready{}, id, ds, ps, used, seconds, finalized}: Bool.pick(Result<&2, &2, String, LiveState>, pcm16_frame(audio), Done{s}, Fail{"invalid_pcm16"})
    case _ _: Fail{"not_ready"}

def live_ack_reduce(+event: LiveEvent, +s: LiveState) -> LiveState:
  match s:
    case LiveState{phase, id, ds, +ps, used, seconds, finalized}:
      Bool.pick(LiveState, has_ack(event, ps), LiveState{phase, id, ds, remove_ack(event, ps), used, seconds, finalized}, live_break("ack_mismatch", s))

def valid_usage(+seconds: F32, previous: F32) -> Bool:
  (seconds >= previous : F32) && (seconds >= 0.0 : F32) && F32.is_eq(F32.sub(seconds, seconds), 0.0)

def remove_pending_go(+key: String, pending: List<&2, PendingCommand>, +acc: List<&2, PendingCommand>) -> List<&2, PendingCommand>:
  match pending:
    case Nil{}: List.reverse(&2, PendingCommand, acc)
    case Con{+p, tail}: remove_pending_go(key, tail, Bool.pick(List<&2, PendingCommand>, String.eq(key, pending_id(p)), acc, Con{p, acc}))

def remove_pending(key: String, pending: List<&2, PendingCommand>) -> List<&2, PendingCommand>:
  remove_pending_go(key, pending, [])

def error_pending(command: Maybe<&2, String>, pending: List<&2, PendingCommand>) -> List<&2, PendingCommand>:
  match command:
    case Some{id}: remove_pending(id, pending)
    case None{}: pending

def live_reduce(event: LiveEvent, +s: LiveState) -> LiveState:
  match event s:
    case _ LiveState{Closed{}, id, ds, ps, used, seconds, finalized}: s
    case _ LiveState{Broken{code}, id, ds, ps, used, seconds, finalized}: s
    case Started{+session} LiveState{Connecting{}, id, ds, ps, used, seconds, finalized}:
      Bool.pick(LiveState, String.eq(session, ""), live_break("session_identity", s), LiveState{Ready{}, session, ds, ps, used, seconds, finalized})
    case Started{session} state: live_break("session_identity", state)
    case LiveProviderError{code, message, command} LiveState{Connecting{}, id, ds, ps, used, seconds, finalized}: live_break(code, s)
    case _ LiveState{Connecting{}, id, ds, ps, used, seconds, finalized}: live_break("before_ready", s)
    case Updated{+session} LiveState{phase, +id, ds, ps, used, seconds, finalized}:
      Bool.pick(LiveState, String.eq(session, id), s, live_break("session_identity", s))
    case Delegated{+delegation, offset} LiveState{phase, id, +ds, ps, used, seconds, finalized}:
      Bool.pick(LiveState, String.eq(delegation, "") || contains(ds, delegation) || (U32.from_nat(List.length(&2, String, ds)) >= 128 : U32), live_break("delegation_identity", s), LiveState{phase, id, Con{delegation, ds}, ps, used, seconds, finalized})
    case ContextAccepted{id, kind} state: live_ack_reduce(ContextAccepted{id, kind}, state)
    case MuteAccepted{id, muted} state: live_ack_reduce(MuteAccepted{id, muted}, state)
    case UsageUpdated{+next} LiveState{phase, id, ds, ps, used, +seconds, finalized}:
      Bool.pick(LiveState, valid_usage(next, seconds), LiveState{phase, id, ds, ps, used, next, finalized}, live_break("usage_regression", s))
    case SessionClosed{session, reason, +next} LiveState{phase, +id, ds, ps, used, +seconds, finalized}:
      Bool.pick(LiveState, String.eq(Maybe.default(&2, String, session, id), id) && valid_usage(next, seconds), LiveState{Closed{}, id, ds, [], used, next, True{}}, live_break("final_usage", s))
    case LiveProviderError{code, message, command} LiveState{phase, id, ds, ps, used, seconds, finalized}: LiveState{phase, id, ds, error_pending(command, ps), used, seconds, finalized}
    case _ _: s

# Abort is distinct from acknowledged session.close. Final usage stays unconfirmed.
def live_abort(+s: LiveState) -> LiveState:
  match s:
    case LiveState{Closed{}, id, ds, ps, used, seconds, finalized}: s
    case LiveState{Broken{code}, id, ds, ps, used, seconds, finalized}: s
    case _: live_break("aborted_without_final_usage", s)

def realtime_close(+s: RealtimeState) -> RealtimeState:
  match s:
    case RealtimeState{Broken{code}, id, active}: s
    case RealtimeState{Closed{}, id, active}: s
    case RealtimeState{phase, id, active}: RealtimeState{Closed{}, id, []}

def realtime_prepare(command: RealtimeCommand, +s: RealtimeState) -> Result<&2, &2, String, RealtimeState>:
  match command s:
    case AppendAudio{audio} RealtimeState{Ready{}, id, active}: Bool.pick(Result<&2, &2, String, RealtimeState>, pcm16_frame(audio), Done{s}, Fail{"invalid_pcm16"})
    case CancelResponse{response} RealtimeState{Ready{}, id, active}: Bool.pick(Result<&2, &2, String, RealtimeState>, contains(active, response), Done{s}, Fail{"unknown_response"})
    case Configure{RealtimeConfig{instructions, voice, model}} RealtimeState{Ready{}, id, active}: Bool.pick(Result<&2, &2, String, RealtimeState>, Bool.not(String.eq(voice, "")) && Bool.not(String.eq(model, "")), Done{s}, Fail{"configuration"})
    case _ RealtimeState{Ready{}, id, active}: Done{s}
    case _ _: Fail{"not_ready"}

# Ack metadata is correlated locally, rather than invented from provider payload.
# Call this on pre-reduction state; reducer rejects unmatched event IDs/kinds.
type ContextReceipt is Data:
  ContextReceipt{event_id: String, delegation_id: Maybe<&2, String>, kind: ContextKind}

def context_receipt(+event: LiveEvent, pending: List<&2, PendingCommand>) -> Maybe<&2, ContextReceipt>:
  match event pending:
    case _ Nil{}: None{}
    case ContextAccepted{+ack_id, +ack_kind} Con{PendingContext{+id, +delegation, +kind}, tail}:
      Bool.pick(Maybe<&2, ContextReceipt>, String.eq(ack_id, id) && context_eq(ack_kind, kind), Some{ContextReceipt{id, delegation, kind}}, context_receipt(ContextAccepted{ack_id, ack_kind}, tail))
    case e Con{head, tail}: context_receipt(e, tail)

def live_receipt(event: LiveEvent, state: LiveState) -> Maybe<&2, ContextReceipt>:
  match state:
    case LiveState{phase, id, ds, pending, used, seconds, finalized}: context_receipt(event, pending)
