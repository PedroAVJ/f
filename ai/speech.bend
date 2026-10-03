import Base
import ./codecs.bend as C

# Incremental MP3 transport validation: prefix and bounds, not an audio decoder.
type SpeechPhase is Data:
  Receiving{}
  SpeechDone{}
  SpeechStopped{}
  SpeechBroken{}
type SpeechState is Data:
  SpeechState{phase: SpeechPhase, bytes_received: U32, accepted: Bool, prefix: List<&2, U32>}
type SpeechFrame is Data:
  SpeechData{bytes: List<&2, U32>}
  SpeechEnd{}
  SpeechCancel{}
  SpeechTransportError{status: U32, request_id: String}
type SpeechEvent is Data:
  SpeechBytes{bytes: List<&2, U32>}
  SpeechComplete{bytes_received: U32}
  SpeechCancelled{}
  SpeechFailed{error: C.Error}
  SpeechIgnored{}
type SpeechTransition is Data:
  SpeechTransition{state: SpeechState, event: SpeechEvent}
type PrefixStatus is Data:
  PrefixPending{}
  PrefixValid{}
  PrefixBad{}

def initial() -> SpeechState:
  SpeechState{Receiving{}, 0, False{}, []}

def valid_bytes(bytes: List<&2, U32>) -> Bool:
  match bytes:
    case Nil{}: True{}
    case Con{byte, tail}: (byte <= 255 : U32) && valid_bytes(tail)

def mp3_sync(valid: Bool) -> PrefixStatus:
  match valid:
    case True{}: PrefixValid{}
    case False{}: PrefixBad{}

def signature(bytes: List<&2, U32>) -> PrefixStatus:
  match bytes:
    case Nil{}: PrefixPending{}
    case Con{a, Nil{}}: PrefixPending{}
    case Con{a, Con{b, Nil{}}}: PrefixPending{}
    case Con{73, Con{68, Con{51, tail}}}: PrefixValid{}
    case Con{255, Con{+b, Con{c, tail}}}: mp3_sync((b >= 224 : U32) && (((b % 8 : U32) / 2 : U32) > 0 : U32) && ((b < 232 : U32) || (b >= 240 : U32)))
    case _: PrefixBad{}

def fail(error: C.Error, s: SpeechState) -> SpeechTransition:
  match s:
    case SpeechState{phase, count, accepted, prefix}: SpeechTransition{SpeechState{SpeechBroken{}, count, accepted, []}, SpeechFailed{error}}

def prefix_step(status: PrefixStatus, bytes: List<&2, U32>, count: U32) -> SpeechTransition:
  match status:
    case PrefixPending{}: SpeechTransition{SpeechState{Receiving{}, count, False{}, bytes}, SpeechIgnored{}}
    case PrefixValid{}: SpeechTransition{SpeechState{Receiving{}, count, True{}, []}, SpeechBytes{bytes}}
    case PrefixBad{}: fail(C.Error{C.ProtocolError{}, 0, ""}, SpeechState{Receiving{}, count, False{}, []})

def data_checked(ok: Bool, +bytes: List<&2, U32>, s: SpeechState) -> SpeechTransition:
  match ok s:
    case False{} _: fail(C.Error{C.FrameLimit{}, 0, ""}, s)
    case True{} SpeechState{phase, +count, True{}, prefix}: SpeechTransition{SpeechState{Receiving{}, (count + U32.from_nat(List.length(&2, U32, bytes)) : U32), True{}, []}, SpeechBytes{bytes}}
    case True{} SpeechState{phase, count, False{}, prefix}:
      +joined = List.append(&2, U32, prefix, bytes)
      prefix_step(signature(joined), joined, (count + U32.from_nat(List.length(&2, U32, bytes)) : U32))

def data(bytes_valid: Bool, +bytes: List<&2, U32>, +s: SpeechState) -> SpeechTransition:
  match bytes_valid s:
    case False{} _: fail(C.Error{C.ProtocolError{}, 0, ""}, s)
    case True{} SpeechState{phase, +count, accepted, prefix}: data_checked((List.length(&2, U32, bytes) <= 65536n : Nat) && (count <= 33554432 : U32) && (List.length(&2, U32, bytes) <= U32.to_nat((33554432 - count : U32)) : Nat), bytes, s)

def reduce(frame: SpeechFrame, +s: SpeechState) -> SpeechTransition:
  match frame s:
    case _ SpeechState{SpeechDone{}, count, accepted, prefix}: SpeechTransition{s, SpeechIgnored{}}
    case _ SpeechState{SpeechStopped{}, count, accepted, prefix}: SpeechTransition{s, SpeechIgnored{}}
    case _ SpeechState{SpeechBroken{}, count, accepted, prefix}: SpeechTransition{s, SpeechIgnored{}}
    case SpeechCancel{} SpeechState{phase, count, accepted, prefix}: SpeechTransition{SpeechState{SpeechStopped{}, count, accepted, []}, SpeechCancelled{}}
    case SpeechTransportError{status, id} _: fail(C.Error{C.TransportError{}, status, id}, s)
    case SpeechEnd{} SpeechState{phase, count, True{}, prefix}: SpeechTransition{SpeechState{SpeechDone{}, count, True{}, []}, SpeechComplete{count}}
    case SpeechEnd{} _: fail(C.Error{C.TruncatedStream{}, 0, ""}, s)
    case SpeechData{+bytes} _: data(valid_bytes(bytes), bytes, s)
