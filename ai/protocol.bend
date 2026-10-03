import Base
import ./codecs.bend as C

type TextEvent is Data:
  TextDelta{text: String}
  TextComplete{}
  TextCancelled{}
  TextFailed{error: C.Error}
  TextIgnored{}
type Phase is Data:
  Streaming{}
  Completed{}
  Cancelled{}
  Failed{}
type StreamState is Data:
  StreamState{provider: C.Provider, phase: Phase, text: String, frames: U32, finished: Bool, usage: C.Usage}
type Frame is Data:
  DataFrame{data: String}
  EndFrame{}
  CancelFrame{}
  TransportFailed{status: U32, request_id: String}
type Transition is Data:
  Transition{state: StreamState, event: TextEvent}

def initial(provider: C.Provider) -> StreamState:
  StreamState{provider, Streaming{}, "", 0, False{}, C.Usage{0, 0}}

def text(s: StreamState) -> String:
  match s:
    case StreamState{p, phase, text, frames, finish, usage}: text

def terminal(s: StreamState) -> Bool:
  match s:
    case StreamState{p, Streaming{}, text, frames, finish, usage}: False{}
    case _: True{}

def error_summary(error: C.Error) -> String:
  match error:
    case C.Error{C.TransportError{}, s, id}: "transport_error"
    case C.Error{C.ProtocolError{}, s, id}: "protocol_error"
    case C.Error{C.TruncatedStream{}, s, id}: "truncated_stream"
    case C.Error{C.ProviderError{}, s, id}: "provider_error"
    case C.Error{C.FrameLimit{}, s, id}: "frame_limit"
    case C.Error{C.UnsupportedEvent{}, s, id}: "unsupported_event"

def fail(error: C.Error, s: StreamState) -> Transition:
  match s:
    case StreamState{p, phase, text, n, finish, usage}: Transition{StreamState{p, Failed{}, text, n, finish, usage}, TextFailed{error}}

def complete(ok: Bool, s: StreamState) -> Transition:
  match ok s:
    case True{} StreamState{p, phase, text, n, finish, usage}: Transition{StreamState{p, Completed{}, text, n, finish, usage}, TextComplete{}}
    case False{} _: fail(C.Error{C.TruncatedStream{}, 0, ""}, s)

def complete_ready(p: C.Provider, finished: Bool) -> Bool:
  match p:
    case C.OpenRouter{}: finished
    case C.Anthropic{}: finished
    case _: True{}

def apply_delta(ok: Bool, +delta: String, s: StreamState) -> Transition:
  match ok s:
    case True{} StreamState{p, phase, text, n, finish, usage}: Transition{StreamState{p, phase, text ++ delta, n, finish, usage}, TextDelta{delta}}
    case False{} _: fail(C.Error{C.FrameLimit{}, 0, ""}, s)

def apply_result(result: Result<&2, &2, C.Error, C.ProviderEvent>, +s: StreamState) -> Transition:
  match result s:
    case Fail{error} _: fail(error, s)
    case Done{C.Delta{+delta}} StreamState{p, phase, +txt, n, False{}, usage}: apply_delta(((String.length(txt) + String.length(delta) : Nat) <= 1048576n : Nat), delta, s)
    case Done{C.Delta{delta}} StreamState{p, phase, txt, n, True{}, usage}: fail(C.Error{C.ProtocolError{}, 0, ""}, s)
    case Done{C.Finished{C.Stop{}}} StreamState{p, phase, txt, n, False{}, usage}: Transition{StreamState{p, phase, txt, n, True{}, usage}, TextIgnored{}}
    case Done{C.Finished{C.ToolCalls{}}} _: fail(C.Error{C.UnsupportedEvent{}, 0, ""}, s)
    case Done{C.Finished{reason}} _: fail(C.Error{C.TruncatedStream{}, 0, ""}, s)
    case Done{C.DoneEvent{}} StreamState{+p, phase, txt, n, +finished, usage}: complete(complete_ready(p, finished), s)
    case Done{C.UsageEvent{new}} StreamState{p, phase, txt, n, finished, old}: Transition{StreamState{p, phase, txt, n, finished, new}, TextIgnored{}}
    case Done{C.Identity{id}} _: Transition{s, TextIgnored{}}
    case Done{C.Ignored{}} _: Transition{s, TextIgnored{}}

def data_checked(ok: Bool, data: String, +s: StreamState) -> Transition:
  match ok s:
    case False{} _: fail(C.Error{C.FrameLimit{}, 0, ""}, s)
    case True{} StreamState{+p, phase, txt, n, finished, usage}: apply_result(C.decode(p, data), StreamState{p, phase, txt, (n + 1 : U32), finished, usage})

def reduce(frame: Frame, +s: StreamState) -> Transition:
  match frame s:
    case _ StreamState{p, Completed{}, txt, n, finished, usage}: Transition{s, TextIgnored{}}
    case _ StreamState{p, Cancelled{}, txt, n, finished, usage}: Transition{s, TextIgnored{}}
    case _ StreamState{p, Failed{}, txt, n, finished, usage}: Transition{s, TextIgnored{}}
    case CancelFrame{} StreamState{p, phase, txt, n, finished, usage}: Transition{StreamState{p, Cancelled{}, txt, n, finished, usage}, TextCancelled{}}
    case TransportFailed{status, id} _: fail(C.Error{C.TransportError{}, status, id}, s)
    case EndFrame{} _: fail(C.Error{C.TruncatedStream{}, 0, ""}, s)
    case DataFrame{+data} StreamState{p, phase, txt, +n, finished, usage}: data_checked((n < 100000 : U32) && (String.length(data) <= 1048576n : Nat), data, s)

# Raw transport framing: HTTP SSE and official CLI NDJSON use the same reducer.
type Framing is Data:
  SSE{}
  NDJSON{}
type RawState is Data:
  RawState{framing: Framing, stream: StreamState, line: String, payload: String, line_chars: U32, payload_chars: U32}
type Feed is Data:
  Feed{state: RawState, events: List<&2, TextEvent>}

def raw_initial(provider: C.Provider, framing: Framing) -> RawState:
  RawState{framing, initial(provider), "", "", 0, 0}

def raw_stream(s: RawState) -> StreamState:
  match s:
    case RawState{f, stream, line, payload, n, m}: stream

def append_event(events: List<&2, TextEvent>, event: TextEvent) -> List<&2, TextEvent>:
  match events:
    case Nil{}: [event]
    case Con{head, tail}: Con{head, append_event(tail, event)}

def strip_cr_reverse(s: String) -> String:
  match s:
    case SCon{'\r', tail}: String.reverse(tail)
    case _: String.reverse(s)

def strip_cr(s: String) -> String:
  strip_cr_reverse(String.reverse(s))

def strip_space(s: String) -> String:
  match s:
    case SCon{' ', tail}: tail
    case _: s

def raw_event(t: Transition, framing: Framing) -> Feed:
  match t:
    case Transition{stream, event}: Feed{RawState{framing, stream, "", "", 0, 0}, [event]}

def sse_empty(empty: Bool, stream: StreamState, payload: String) -> Feed:
  match empty:
    case True{}: Feed{RawState{SSE{}, stream, "", "", 0, 0}, []}
    case False{}: raw_event(reduce(DataFrame{payload}, stream), SSE{})

def sse_data(ok: Bool, stream: StreamState, payload: String, data: String, chars: U32) -> Feed:
  match ok:
    case False{}: raw_event(fail(C.Error{C.FrameLimit{}, 0, ""}, stream), SSE{})
    case True{}: Feed{RawState{SSE{}, stream, "", payload ++ data, 0, chars}, []}

def sse_join(empty: Bool, payload: String, data: String) -> String:
  match empty:
    case True{}: payload ++ data
    case False{}: payload ++ "\n" ++ data

def sse_line_append(stream: StreamState, +payload: String, +data: String, chars: U32) -> Feed:
  sse_data((((String.length(payload) + String.length(data) : Nat) + 1n : Nat) <= 1048576n : Nat), stream, "", sse_join(String.is_empty(payload), payload, data), chars)

def sse_line_data(is_data: Bool, +line: String, stream: StreamState, +payload: String, chars: U32) -> Feed:
  match is_data:
    case False{}: Feed{RawState{SSE{}, stream, "", payload, 0, chars}, []}
    case True{}: sse_line_append(stream, payload, strip_space(String.drop(line, 5n)), chars)

def sse_line(empty: Bool, +line: String, stream: StreamState, +payload: String, chars: U32) -> Feed:
  match empty:
    case True{}: sse_empty(String.is_empty(payload), stream, payload)
    case False{}: sse_line_data(String.eq(String.take(line, 5n), "data:"), line, stream, payload, chars)

def ndjson_line(empty: Bool, line: String, stream: StreamState) -> Feed:
  match empty:
    case True{}: Feed{RawState{NDJSON{}, stream, "", "", 0, 0}, []}
    case False{}: raw_event(reduce(DataFrame{line}, stream), NDJSON{})

def process_line(f: Framing, +line: String, stream: StreamState, payload: String, chars: U32) -> Feed:
  match f:
    case SSE{}: sse_line(String.is_empty(line), line, stream, payload, chars)
    case NDJSON{}: ndjson_line(String.is_empty(line), line, stream)

def line_done(s: RawState) -> Feed:
  match s:
    case RawState{f, stream, line, payload, n, m}: process_line(f, strip_cr(line), stream, payload, m)

def reverse_events(xs: List<&2, TextEvent>, acc: List<&2, TextEvent>) -> List<&2, TextEvent>:
  match xs:
    case Nil{}: acc
    case Con{head, tail}: reverse_events(tail, Con{head, acc})

def feed_state(step: Feed) -> RawState:
  match step:
    case Feed{state, events}: state

def feed_events(step: Feed) -> List<&2, TextEvent>:
  match step:
    case Feed{state, events}: events

def feed_char(ok: Bool, c: Char, +s: RawState) -> Feed:
  match ok s:
    case False{} RawState{f, stream, line, payload, n, m}: raw_event(fail(C.Error{C.FrameLimit{}, 0, ""}, stream), f)
    case True{} RawState{f, stream, line, payload, +n, m}: Feed{RawState{f, stream, line ++ SCon{c, SNil{}}, payload, (n + 1 : U32), m}, []}

def feed_run(data: String, +s: RawState, acc: List<&2, TextEvent>) -> Feed:
  match data s:
    case _ RawState{f, StreamState{p, Completed{}, txt, n, done, usage}, line, payload, a, b}: Feed{s, reverse_events(acc, [])}
    case _ RawState{f, StreamState{p, Failed{}, txt, n, done, usage}, line, payload, a, b}: Feed{s, reverse_events(acc, [])}
    case _ RawState{f, StreamState{p, Cancelled{}, txt, n, done, usage}, line, payload, a, b}: Feed{s, reverse_events(acc, [])}
    case SNil{} _: Feed{s, reverse_events(acc, [])}
    case SCon{'\n', rest} _:
      +step = line_done(s)
      feed_run(rest, feed_state(step), reverse_events(feed_events(step), acc))
    case SCon{c, rest} RawState{f, stream, line, payload, +n, m}:
      +step = feed_char((n < 1048576 : U32), c, s)
      feed_run(rest, feed_state(step), reverse_events(feed_events(step), acc))

def feed(data: String, s: RawState) -> Feed:
  feed_run(data, s, [])

def raw_end(s: RawState) -> Feed:
  match s:
    case RawState{f, stream, line, payload, n, m}: raw_event(reduce(EndFrame{}, stream), f)

def raw_cancel(s: RawState) -> Feed:
  match s:
    case RawState{f, stream, line, payload, n, m}: raw_event(reduce(CancelFrame{}, stream), f)
