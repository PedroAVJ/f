import Base
import ../ai/transcription.bend as Speech

# Metadata is typed application state; bytes belong to an explicit host asset store.
type MediaKind is Data:
  AudioAsset{}
  PhotoAsset{}
  VideoAsset{}
  FileAsset{}
type Asset is Data:
  Asset{id: String, kind: MediaKind, mime_type: String, name: String, size: U32, duration_ms: U32}
type Attachment is Data:
  Attachment{message_id: String, asset: Asset}
type TranscriptionPhase is Data:
  AwaitingTranscription{}
  Transcribing{}
  Transcribed{}
  TranscriptionFailed{}
  TranscriptionCancelled{}
type Provenance is Data:
  Provenance{provider: String, model: String, source_asset_id: String}
type WordKind is Data:
  SpokenWord{}
  WordSpacing{}
  AudioEventWord{}
type TimedWord is Data:
  TimedWord{text: String, kind: WordKind, start: Maybe<&2, F32>, end: Maybe<&2, F32>, speaker_id: Maybe<&2, String>, logprob: Maybe<&2, F32>}
type Transcription is Data:
  Transcription{phase: TranscriptionPhase, attempt: U32, provenance: Provenance, words: List<&2, TimedWord>, text: String, error: String, retry_required: Bool}
type AudioMessage is Data:
  AudioMessage{message_id: String, asset: Asset, transcription: Transcription}
type AudioEvent is Data:
  QueueTranscription{}
  BeginTranscription{}
  TranscriptReceived{attempt: U32, text: String, words: List<&2, TimedWord>}
  TranscriptFailed{attempt: U32, error: String}
  CancelTranscription{attempt: U32}
  RestoreTranscription{}

def metadata_valid(asset: Asset) -> Bool:
  match asset:
    case Asset{id, AudioAsset{}, mime, name, +size, duration}: (size > 0 : U32) && (size <= 8388608 : U32) && String.starts_with(mime, "audio/")
    case Asset{id, PhotoAsset{}, mime, name, +size, duration}: (size > 0 : U32) && (size <= 8388608 : U32) && String.starts_with(mime, "image/")
    case Asset{id, VideoAsset{}, mime, name, +size, duration}: (size > 0 : U32) && (size <= 8388608 : U32) && String.starts_with(mime, "video/")
    case Asset{id, FileAsset{}, mime, name, +size, duration}: (size > 0 : U32) && (size <= 8388608 : U32)

def asset_id(asset: Asset) -> String:
  match asset:
    case Asset{id, kind, mime, name, size, duration}: id

def audio_new(id: String, +asset: Asset, model: String) -> AudioMessage:
  AudioMessage{id, asset, Transcription{AwaitingTranscription{}, 0, Provenance{"elevenlabs", model, asset_id(asset)}, [], "", "", False{}}}

def attachment_new(id: String, asset: Asset) -> Attachment:
  Attachment{id, asset}

def begin_pending(+attempt: U32, +provenance: Provenance) -> Transcription:
  Bool.pick(Transcription, (attempt < 3 : U32), Transcription{Transcribing{}, (attempt + 1 : U32), provenance, [], "", "", False{}}, Transcription{TranscriptionFailed{}, attempt, provenance, [], "", "Transcription retry limit reached", False{}})

def begin_transcription(t: Transcription) -> Transcription:
  match t:
    case Transcription{AwaitingTranscription{}, attempt, provenance, words, text, error, retry}: begin_pending(attempt, provenance)
    case Transcription{TranscriptionFailed{}, attempt, provenance, words, text, error, retry}: begin_pending(attempt, provenance)
    case Transcription{TranscriptionCancelled{}, attempt, provenance, words, text, error, retry}: begin_pending(attempt, provenance)
    case other: other

def result_transcription(attempt: U32, text: String, words: List<&2, TimedWord>, +t: Transcription) -> Transcription:
  match t:
    case Transcription{Transcribing{}, +current, provenance, old_words, old, error, retry}:
      Bool.pick(Transcription, U32.is_eq(attempt, current), Transcription{Transcribed{}, current, provenance, words, text, "", False{}}, t)
    case _: t

def fail_transcription(attempt: U32, error: String, +t: Transcription) -> Transcription:
  match t:
    case Transcription{Transcribing{}, +current, provenance, words, text, old, retry}:
      Bool.pick(Transcription, U32.is_eq(attempt, current), Transcription{TranscriptionFailed{}, current, provenance, [], "", error, (current < 3 : U32)}, t)
    case _: t

def cancel_transcription(attempt: U32, +t: Transcription) -> Transcription:
  match t:
    case Transcription{Transcribing{}, +current, provenance, words, text, error, retry}:
      Bool.pick(Transcription, U32.is_eq(attempt, current), Transcription{TranscriptionCancelled{}, current, provenance, [], "", "", (current < 3 : U32)}, t)
    case Transcription{AwaitingTranscription{}, +current, provenance, words, text, error, retry}: Transcription{TranscriptionCancelled{}, current, provenance, [], "", "", (current < 3 : U32)}
    case _: t

def restored_pending(+attempt: U32, +provenance: Provenance) -> Transcription:
  Bool.pick(Transcription, (attempt < 3 : U32), Transcription{AwaitingTranscription{}, attempt, provenance, [], "", "", True{}}, Transcription{TranscriptionFailed{}, attempt, provenance, [], "", "Transcription retry limit reached", False{}})

def restore_transcription(t: Transcription) -> Transcription:
  match t:
    case Transcription{Transcribing{}, attempt, provenance, words, text, error, retry}: restored_pending(attempt, provenance)
    case Transcription{AwaitingTranscription{}, attempt, provenance, words, text, error, retry}: restored_pending(attempt, provenance)
    case other: other

def queue_transcription(t: Transcription) -> Transcription:
  match t:
    case Transcription{AwaitingTranscription{}, attempt, provenance, words, text, error, retry}: Transcription{AwaitingTranscription{}, attempt, provenance, [], "", "", False{}}
    case Transcription{TranscriptionFailed{}, attempt, provenance, words, text, error, retry}: Transcription{AwaitingTranscription{}, attempt, provenance, [], "", "", False{}}
    case Transcription{TranscriptionCancelled{}, attempt, provenance, words, text, error, retry}: Transcription{AwaitingTranscription{}, attempt, provenance, [], "", "", False{}}
    case other: other

def update_transcription(event: AudioEvent, t: Transcription) -> Transcription:
  match event:
    case QueueTranscription{}: queue_transcription(t)
    case BeginTranscription{}: begin_transcription(t)
    case TranscriptReceived{attempt, text, words}: result_transcription(attempt, text, words, t)
    case TranscriptFailed{attempt, error}: fail_transcription(attempt, error, t)
    case CancelTranscription{attempt}: cancel_transcription(attempt, t)
    case RestoreTranscription{}: restore_transcription(t)

def reduce_audio(event: AudioEvent, message: AudioMessage) -> AudioMessage:
  match message:
    case AudioMessage{id, asset, t}: AudioMessage{id, asset, update_transcription(event, t)}

def transcription_status(t: Transcription) -> String:
  match t:
    case Transcription{AwaitingTranscription{}, attempt, provenance, words, text, error, retry}: "pending"
    case Transcription{Transcribing{}, attempt, provenance, words, text, error, retry}: "running"
    case Transcription{Transcribed{}, attempt, provenance, words, text, error, retry}: "ready"
    case Transcription{TranscriptionFailed{}, attempt, provenance, words, text, error, retry}: "failed"
    case Transcription{TranscriptionCancelled{}, attempt, provenance, words, text, error, retry}: "cancelled"

# Replies consume only a completed derived transcript; the audio record stays canonical.
type ReplyPhase is Data:
  ReplyIdle{}
  ReplyPending{}
  ReplyRunning{}
  ReplyReady{}
  ReplyFailed{}
  ReplyCancelled{}
type AudioReply is Data:
  AudioReply{message_id: String, response_id: String, phase: ReplyPhase, error: String}
type ReplyEvent is Data:
  EnqueueReply{}
  StartReply{response_id: String}
  FinishReply{response_id: String}
  FailReply{response_id: String, error: String}
  CancelReply{}
  RestoreReply{}

def reply_new(id: String) -> AudioReply:
  AudioReply{id, "", ReplyIdle{}, ""}

def reduce_reply(event: ReplyEvent, +reply: AudioReply) -> AudioReply:
  match event reply:
    case EnqueueReply{} AudioReply{id, response, ReplyIdle{}, error}: AudioReply{id, "", ReplyPending{}, ""}
    case EnqueueReply{} AudioReply{id, response, ReplyFailed{}, error}: AudioReply{id, "", ReplyPending{}, ""}
    case EnqueueReply{} AudioReply{id, response, ReplyCancelled{}, error}: AudioReply{id, "", ReplyPending{}, ""}
    case StartReply{response} AudioReply{id, old, ReplyPending{}, error}: AudioReply{id, response, ReplyRunning{}, ""}
    case FinishReply{+response} AudioReply{id, +current, ReplyRunning{}, error}:
      Bool.pick(AudioReply, String.eq(response, current), AudioReply{id, current, ReplyReady{}, ""}, reply)
    case FailReply{+response, error} AudioReply{id, +current, ReplyRunning{}, old}:
      Bool.pick(AudioReply, String.eq(response, current), AudioReply{id, current, ReplyFailed{}, error}, reply)
    case CancelReply{} AudioReply{id, response, ReplyPending{}, error}: AudioReply{id, response, ReplyCancelled{}, ""}
    case CancelReply{} AudioReply{id, response, ReplyRunning{}, error}: AudioReply{id, response, ReplyCancelled{}, ""}
    case RestoreReply{} AudioReply{id, response, ReplyPending{}, error}: AudioReply{id, response, ReplyCancelled{}, "Reply was interrupted; request it explicitly."}
    case RestoreReply{} AudioReply{id, response, ReplyRunning{}, error}: AudioReply{id, response, ReplyCancelled{}, "Reply was interrupted; request it explicitly."}
    case _ _: reply

def reply_status(reply: AudioReply) -> String:
  match reply:
    case AudioReply{id, response, ReplyIdle{}, error}: "none"
    case AudioReply{id, response, ReplyPending{}, error}: "pending"
    case AudioReply{id, response, ReplyRunning{}, error}: "running"
    case AudioReply{id, response, ReplyReady{}, error}: "ready"
    case AudioReply{id, response, ReplyFailed{}, error}: "failed"
    case AudioReply{id, response, ReplyCancelled{}, error}: "cancelled"

# Native AI decoding can deliver the typed transcript without a Json public hole.
def native_word_kind(kind: Speech.WordKind) -> WordKind:
  match kind:
    case Speech.Word{}: SpokenWord{}
    case Speech.Spacing{}: WordSpacing{}
    case Speech.AudioEvent{}: AudioEventWord{}

def native_words(words: List<&2, Speech.TranscriptWord>) -> List<&2, TimedWord>:
  match words:
    case Nil{}: []
    case Con{Speech.TranscriptWord{text, kind, start, end, logprob, speaker, characters}, tail}:
      Con{TimedWord{text, native_word_kind(kind), start, end, speaker, Some{logprob}}, native_words(tail)}

def native_transcript(attempt: U32, transcript: Speech.Transcript, message: AudioMessage) -> AudioMessage:
  match transcript:
    case Speech.Transcript{text, language, probability, words, id, duration}: reduce_audio(TranscriptReceived{attempt, text, native_words(words)}, message)
