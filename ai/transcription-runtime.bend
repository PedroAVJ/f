import Base
import ./transcription.bend as T
import ./codecs.bend as C
import ./runtime.bend as Runtime
import ./native-host/host.bend as Host

type TranscriptionPhase is Data:
  Reading{}
  Ready{}
  Cancelled{}
  Failed{}
type TranscriptionSession is Data:
  TranscriptionSession{handle: U32, buffer: String, characters: U32, phase: TranscriptionPhase}
type TranscriptionStart is Data:
  Started{session: TranscriptionSession}
  StartFailed{error: C.Error}
type TranscriptionEvent is Data:
  Pending{}
  Completed{transcript: T.Transcript}
  CancelledEvent{}
  FailedEvent{error: C.Error}
  Ignored{}
type TranscriptionPoll is Data:
  TranscriptionPoll{session: TranscriptionSession, event: TranscriptionEvent}

def host_fields(fields: List<&2, T.FormField>) -> List<&2, Host.FormField>:
  match fields:
    case Nil{}: []
    case Con{T.FormField{name, value}, tail}: Con{Host.FormField{name, value}, host_fields(tail)}

def start_failed(handle: U32, error: C.Error) -> IO(TranscriptionStart):
  match handle:
    case 0: IO.pure(TranscriptionStart, StartFailed{error})
    case _:
      do IO<TranscriptionStart>:
        reply : Host.Reply <- Host.Transport.close(handle)
        IO.pure(TranscriptionStart, StartFailed{error})

def metadata_checked(metadata: Result<&2, &2, C.Error, U32>, handle: U32) -> IO(TranscriptionStart):
  match metadata:
    case Fail{error}: start_failed(handle, error)
    case Done{status}: IO.pure(TranscriptionStart, Started{TranscriptionSession{handle, "", 0, Reading{}}})

def opened(reply: Host.Reply) -> IO(TranscriptionStart):
  match reply:
    case Host.Reply{1, 0, data}: IO.pure(TranscriptionStart, StartFailed{C.Error{C.ProtocolError{}, 0, ""}})
    case Host.Reply{1, handle, data}: metadata_checked(Runtime.http_metadata(data), handle)
    case Host.Reply{status, handle, data}: start_failed(handle, C.Error{C.TransportError{}, 0, ""})

def open_plan(credential: U32, plan: Result<&2, &2, C.Error, T.MultipartPlan>) -> IO(TranscriptionStart):
  match plan:
    case Fail{error}: IO.pure(TranscriptionStart, StartFailed{error})
    case Done{T.MultipartPlan{url, fields, T.AudioFile{filename, mime, bytes}}}:
      do IO<TranscriptionStart>:
        reply : Host.Reply <- Host.HTTP.multipart_open(credential, url, "{}", host_fields(fields), filename, T.mime(mime), bytes)
        opened(reply)

def open(credential: U32, request: T.TranscriptionRequest) -> IO(TranscriptionStart):
  open_plan(credential, T.request(request))

def final(handle: U32, phase: TranscriptionPhase, event: TranscriptionEvent) -> IO(TranscriptionPoll):
  do IO<TranscriptionPoll>:
    reply : Host.Reply <- Host.Transport.close(handle)
    IO.pure(TranscriptionPoll, TranscriptionPoll{TranscriptionSession{0, "", 0, phase}, event})

def decoded(handle: U32, result: Result<&2, &2, C.Error, T.Transcript>) -> IO(TranscriptionPoll):
  match result:
    case Fail{error}: final(handle, Failed{}, FailedEvent{error})
    case Done{transcript}: final(handle, Ready{}, Completed{transcript})

def data_checked(valid: Bool, handle: U32, buffer: String, chars: U32, data: String) -> IO(TranscriptionPoll):
  match valid:
    case False{}: final(handle, Failed{}, FailedEvent{C.Error{C.FrameLimit{}, 0, ""}})
    case True{}: IO.pure(TranscriptionPoll, TranscriptionPoll{TranscriptionSession{handle, buffer ++ data, chars, Reading{}}, Pending{}})

def read_reply(reply: Host.Reply, +s: TranscriptionSession) -> IO(TranscriptionPoll):
  match reply s:
    case Host.Reply{1, h, +data} TranscriptionSession{handle, buffer, +count, phase}:
      +chars = U32.from_nat(String.length(data))
      data_checked((chars <= 1048576 : U32) && (count <= 4194304 : U32) && (chars <= (4194304 - count : U32) : U32), handle, buffer, (count + chars : U32), data)
    case Host.Reply{2, h, data} TranscriptionSession{handle, buffer, count, phase}: decoded(handle, T.decode(buffer))
    case Host.Reply{3, h, data} _: IO.pure(TranscriptionPoll, TranscriptionPoll{s, Pending{}})
    case _ TranscriptionSession{handle, buffer, count, phase}: final(handle, Failed{}, FailedEvent{C.Error{C.TransportError{}, 0, ""}})

def read(+s: TranscriptionSession) -> IO(TranscriptionPoll):
  match s:
    case TranscriptionSession{0, buffer, count, phase}: IO.pure(TranscriptionPoll, TranscriptionPoll{s, Ignored{}})
    case TranscriptionSession{+handle, buffer, count, Reading{}}:
      do IO<TranscriptionPoll>:
        reply : Host.Reply <- Host.Stream.read(handle)
        read_reply(reply, s)
    case _: IO.pure(TranscriptionPoll, TranscriptionPoll{s, Ignored{}})

def cancel(+s: TranscriptionSession) -> IO(TranscriptionPoll):
  match s:
    case TranscriptionSession{0, buffer, count, phase}: IO.pure(TranscriptionPoll, TranscriptionPoll{s, Ignored{}})
    case TranscriptionSession{handle, buffer, count, Reading{}}: final(handle, Cancelled{}, CancelledEvent{})
    case _: IO.pure(TranscriptionPoll, TranscriptionPoll{s, Ignored{}})
