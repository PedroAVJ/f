import Base
import ./speech.bend as S
import ./requests.bend as R
import ./codecs.bend as C
import ./protocol.bend as P
import ./native-host/host.bend as Host

# Server-only native orchestration; physical IO is an opaque injected raw host.
type TextSession is Data:
  TextSession{handle: U32, state: P.RawState}
type StartResult is Data:
  Started{session: TextSession}
  InvalidRequest{error: R.RequestError}
  StartFailed{error: C.Error}
type Poll is Data:
  Poll{session: TextSession, events: List<&2, P.TextEvent>}

def started(reply: Host.Reply, provider: C.Provider, framing: P.Framing) -> StartResult:
  match reply:
    case Host.Reply{1, handle, data}: Started{TextSession{handle, P.raw_initial(provider, framing)}}
    case Host.Reply{status, handle, data}: StartFailed{C.Error{C.TransportError{}, status, ""}}

# HTTP open success includes canonical decimal HTTP status in Reply.data.
# Process/socket metadata remains opaque and uses a separate start path.
def http_valid(valid: Bool, successful: Bool, status: U32) -> Result<&2, &2, C.Error, U32>:
  match valid successful:
    case False{} _: Fail{C.Error{C.ProtocolError{}, 0, ""}}
    case True{} False{}: Fail{C.Error{C.ProviderError{}, status, ""}}
    case True{} True{}: Done{status}

def http_parsed(+raw: String, parsed: Maybe<&2, U32>) -> Result<&2, &2, C.Error, U32>:
  match parsed:
    case None{}: Fail{C.Error{C.ProtocolError{}, 0, ""}}
    case Some{+status}: http_valid(String.eq(raw, U32.show(status)) && (status >= 100 : U32) && (status <= 599 : U32), (status >= 200 : U32) && (status <= 299 : U32), status)

def http_metadata(+raw: String) -> Result<&2, &2, C.Error, U32>:
  http_parsed(raw, U32.read(raw))

def start_failed(handle: U32, error: C.Error) -> IO(StartResult):
  match handle:
    case 0: IO.pure(StartResult, StartFailed{error})
    case _:
      do IO<StartResult>:
        reply : Host.Reply <- Host.Transport.close(handle)
        IO.pure(StartResult, StartFailed{error})

def http_decision(metadata: Result<&2, &2, C.Error, U32>, handle: U32, provider: C.Provider) -> IO(StartResult):
  match metadata:
    case Fail{error}: start_failed(handle, error)
    case Done{status}: IO.pure(StartResult, Started{TextSession{handle, P.raw_initial(provider, P.SSE{})}})

def http_started(reply: Host.Reply, provider: C.Provider) -> IO(StartResult):
  match reply:
    case Host.Reply{1, 0, data}: IO.pure(StartResult, StartFailed{C.Error{C.ProtocolError{}, 0, ""}})
    case Host.Reply{1, handle, data}: http_decision(http_metadata(data), handle, provider)
    case Host.Reply{status, handle, data}: start_failed(handle, C.Error{C.TransportError{}, 0, ""})

def start(request: Result<&2, &2, R.RequestError, R.HTTPRequest>, credential: U32, provider: C.Provider) -> IO(StartResult):
  match request:
    case Fail{error}: IO.pure(StartResult, InvalidRequest{error})
    case Done{R.HTTPRequest{method, url, headers, body}}:
      do IO<StartResult>:
        reply : Host.Reply <- Host.HTTP.open(credential, method, url, headers, body)
        http_started(reply, provider)

def openrouter(credential: U32, request: R.OpenRouterRequest) -> IO(StartResult):
  start(R.openrouter(request), credential, C.OpenRouter{})

def responses(credential: U32, request: R.ResponsesRequest) -> IO(StartResult):
  start(R.responses(request), credential, C.Responses{})

def anthropic(credential: U32, request: R.AnthropicRequest) -> IO(StartResult):
  start(R.anthropic(request), credential, C.Anthropic{})

def claude(credential: U32, executable: String, request: R.ClaudeRequest) -> IO(StartResult):
  do IO<StartResult>:
    reply : Host.Reply <- Host.Process.open(credential, executable, R.claude_arguments(request), "")
    IO.pure(StartResult, started(reply, C.Claude{}, P.NDJSON{}))

def raw_error(s: P.RawState) -> P.Feed:
  match s:
    case P.RawState{f, stream, line, payload, a, b}: P.raw_event(P.reduce(P.TransportFailed{0, ""}, stream), f)

def reply_frame(reply: Host.Reply, state: P.RawState) -> P.Feed:
  match reply:
    case Host.Reply{1, handle, data}: P.feed(data, state)
    case Host.Reply{2, handle, data}: P.raw_end(state)
    case Host.Reply{3, handle, data}: P.Feed{state, []}
    case _: raw_error(state)

def poll_result(done: Bool, handle: U32, state: P.RawState, events: List<&2, P.TextEvent>) -> IO(Poll):
  match done:
    case False{}: IO.pure(Poll, Poll{TextSession{handle, state}, events})
    case True{}:
      do IO<Poll>:
        reply : Host.Reply <- Host.Transport.close(handle)
        IO.pure(Poll, Poll{TextSession{0, state}, events})

def poll_feed(handle: U32, +feed: P.Feed) -> IO(Poll):
  match feed:
    case P.Feed{+state, events}: poll_result(P.terminal(P.raw_stream(state)), handle, state, events)

def read(session: TextSession) -> IO(Poll):
  match session:
    case TextSession{0, state}: IO.pure(Poll, Poll{TextSession{0, state}, []})
    case TextSession{+handle, state}:
      do IO<Poll>:
        reply : Host.Reply <- Host.Stream.read(handle)
        poll_feed(handle, reply_frame(reply, state))

def cancel(session: TextSession) -> IO(Poll):
  match session:
    case TextSession{0, state}: IO.pure(Poll, Poll{TextSession{0, state}, []})
    case TextSession{handle, state}: poll_feed(handle, P.raw_cancel(state))

# ElevenLabs MP3 byte frames are reduced natively; the host never parses media.

type SpeechSession is Data:
  SpeechSession{handle: U32, state: S.SpeechState}
type SpeechStartResult is Data:
  SpeechStarted{session: SpeechSession}
  SpeechInvalidRequest{error: R.RequestError}
  SpeechStartFailed{error: C.Error}
type SpeechPoll is Data:
  SpeechPoll{session: SpeechSession, event: S.SpeechEvent}

def speech_start_failed(handle: U32, error: C.Error) -> IO(SpeechStartResult):
  match handle:
    case 0: IO.pure(SpeechStartResult, SpeechStartFailed{error})
    case _:
      do IO<SpeechStartResult>:
        reply : Host.Reply <- Host.Transport.close(handle)
        IO.pure(SpeechStartResult, SpeechStartFailed{error})

def speech_http_decision(metadata: Result<&2, &2, C.Error, U32>, handle: U32) -> IO(SpeechStartResult):
  match metadata:
    case Fail{error}: speech_start_failed(handle, error)
    case Done{status}: IO.pure(SpeechStartResult, SpeechStarted{SpeechSession{handle, S.initial()}})

def speech_started(reply: Host.Reply) -> IO(SpeechStartResult):
  match reply:
    case Host.Reply{1, 0, data}: IO.pure(SpeechStartResult, SpeechStartFailed{C.Error{C.ProtocolError{}, 0, ""}})
    case Host.Reply{1, handle, data}: speech_http_decision(http_metadata(data), handle)
    case Host.Reply{status, handle, data}: speech_start_failed(handle, C.Error{C.TransportError{}, 0, ""})

def speech_start(request: Result<&2, &2, R.RequestError, R.HTTPRequest>, credential: U32) -> IO(SpeechStartResult):
  match request:
    case Fail{error}: IO.pure(SpeechStartResult, SpeechInvalidRequest{error})
    case Done{R.HTTPRequest{method, url, headers, body}}:
      do IO<SpeechStartResult>:
        reply : Host.Reply <- Host.HTTP.open(credential, method, url, headers, body)
        speech_started(reply)

def speech(credential: U32, request: R.SpeechRequest) -> IO(SpeechStartResult):
  speech_start(R.speech(request), credential)

def speech_reply(reply: Host.ByteReply, state: S.SpeechState) -> S.SpeechTransition:
  match reply:
    case Host.ByteReply{1, handle, bytes}: S.reduce(S.SpeechData{bytes}, state)
    case Host.ByteReply{2, handle, bytes}: S.reduce(S.SpeechEnd{}, state)
    case Host.ByteReply{3, handle, bytes}: S.SpeechTransition{state, S.SpeechIgnored{}}
    case _: S.reduce(S.SpeechTransportError{0, ""}, state)

def speech_terminal(s: S.SpeechState) -> Bool:
  match s:
    case S.SpeechState{S.Receiving{}, count, accepted, prefix}: False{}
    case _: True{}

def speech_poll_result(done: Bool, handle: U32, state: S.SpeechState, event: S.SpeechEvent) -> IO(SpeechPoll):
  match done:
    case False{}: IO.pure(SpeechPoll, SpeechPoll{SpeechSession{handle, state}, event})
    case True{}:
      do IO<SpeechPoll>:
        reply : Host.Reply <- Host.Transport.close(handle)
        IO.pure(SpeechPoll, SpeechPoll{SpeechSession{0, state}, event})

def speech_poll(handle: U32, step: S.SpeechTransition) -> IO(SpeechPoll):
  match step:
    case S.SpeechTransition{+state, event}: speech_poll_result(speech_terminal(state), handle, state, event)

def speech_read(session: SpeechSession) -> IO(SpeechPoll):
  match session:
    case SpeechSession{0, state}: IO.pure(SpeechPoll, SpeechPoll{SpeechSession{0, state}, S.SpeechIgnored{}})
    case SpeechSession{+handle, state}:
      do IO<SpeechPoll>:
        reply : Host.ByteReply <- Host.Stream.read_bytes(handle)
        speech_poll(handle, speech_reply(reply, state))

def speech_cancel(session: SpeechSession) -> IO(SpeechPoll):
  match session:
    case SpeechSession{0, state}: IO.pure(SpeechPoll, SpeechPoll{SpeechSession{0, state}, S.SpeechIgnored{}})
    case SpeechSession{handle, state}: speech_poll(handle, S.reduce(S.SpeechCancel{}, state))
