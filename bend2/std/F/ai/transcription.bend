import Base
import ./wire_json.bend as J
import ./codecs.bend as C

type AudioMime is Data:
  WebM{}
  Ogg{}
  Wav{}
  MP3{}
  M4A{}
  Flac{}
  AAC{}
type AudioFile is Data:
  AudioFile{filename: String, mime: AudioMime, bytes: List<&2, U32>}
type Granularity is Data:
  NoTimestamps{}
  WordTimestamps{}
  CharacterTimestamps{}
type FileFormat is Data:
  EncodedAudio{}
  PCM16Mono16k{}
type TranscriptionRequest is Data:
  TranscriptionRequest{file: AudioFile, language: Maybe<&2, String>, diarize: Bool, speakers: Maybe<&2, U32>, timestamps: Granularity, tag_audio_events: Bool, format: FileFormat}
type FormField is Data:
  FormField{name: String, value: String}
type MultipartPlan is Data:
  MultipartPlan{url: String, fields: List<&2, FormField>, file: AudioFile}
type WordKind is Data:
  Word{}
  Spacing{}
  AudioEvent{}
type Character is Data:
  Character{text: String, start: Maybe<&2, F32>, end: Maybe<&2, F32>}
type TranscriptWord is Data:
  TranscriptWord{text: String, kind: WordKind, start: Maybe<&2, F32>, end: Maybe<&2, F32>, logprob: F32, speaker: Maybe<&2, String>, characters: List<&2, Character>}
type Transcript is Data:
  Transcript{text: String, language_code: String, language_probability: F32, words: List<&2, TranscriptWord>, transcription_id: Maybe<&2, String>, audio_duration_secs: Maybe<&2, F32>}

def mime(m: AudioMime) -> String:
  match m:
    case WebM{}: "audio/webm"
    case Ogg{}: "audio/ogg"
    case Wav{}: "audio/wav"
    case MP3{}: "audio/mpeg"
    case M4A{}: "audio/mp4"
    case Flac{}: "audio/flac"
    case AAC{}: "audio/aac"

def granularity(g: Granularity) -> String:
  match g:
    case NoTimestamps{}: "none"
    case WordTimestamps{}: "word"
    case CharacterTimestamps{}: "character"

def file_format(f: FileFormat) -> String:
  match f:
    case EncodedAudio{}: "other"
    case PCM16Mono16k{}: "pcm_s16le_16"

def boolean(b: Bool) -> String:
  match b:
    case True{}: "true"
    case False{}: "false"

def optional_language(language: Maybe<&2, String>) -> List<&2, FormField>:
  match language:
    case None{}: []
    case Some{s}: [FormField{"language_code", s}]

def optional_speakers(speakers: Maybe<&2, U32>) -> List<&2, FormField>:
  match speakers:
    case None{}: []
    case Some{s}: [FormField{"num_speakers", U32.show(s)}]

def language_chars(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{+c}, tail}: (((c >= 97 : U32) && (c <= 122 : U32)) || ((c >= 65 : U32) && (c <= 90 : U32))) && language_chars(tail)

def valid_language(language: Maybe<&2, String>) -> Bool:
  match language:
    case None{}: True{}
    case Some{+s}: ((String.length(s) >= 2n : Nat) && (String.length(s) <= 3n : Nat)) && language_chars(s)

def filename_chars(s: String) -> Bool:
  match s:
    case SNil{}: True{}
    case SCon{Chr{+c}, tail}: (((c >= 48 : U32) && (c <= 57 : U32)) || ((c >= 65 : U32) && (c <= 90 : U32)) || ((c >= 97 : U32) && (c <= 122 : U32)) || U32.is_eq(c, 45) || U32.is_eq(c, 95) || U32.is_eq(c, 46) || U32.is_eq(c, 32)) && filename_chars(tail)

def filename_first(s: String) -> Bool:
  match s:
    case SNil{}: False{}
    case SCon{Chr{+c}, tail}: ((c >= 48 : U32) && (c <= 57 : U32)) || ((c >= 65 : U32) && (c <= 90 : U32)) || ((c >= 97 : U32) && (c <= 122 : U32))

def valid_filename(+s: String) -> Bool:
  match s:
    case "": False{}
    case ".": False{}
    case "..": False{}
    case _: (String.length(s) <= 128n : Nat) && filename_first(s) && filename_chars(s)

# Counter stops at the bound before traversing any remaining oversized upload.
def count_bytes_run(items: List<&2, U32>, valid: Bool, +count: U32) -> Result<&2, &2, C.Error, U32>:
  match items valid:
    case _ False{}: Fail{C.Error{C.FrameLimit{}, 0, ""}}
    case Nil{} True{}: Done{count}
    case Con{+byte, rest} True{}: count_bytes_run(rest, (byte <= 255 : U32) && (count < 33554432 : U32), (count + 1 : U32))

def count_bytes(bytes: List<&2, U32>, count: U32) -> Result<&2, &2, C.Error, U32>:
  count_bytes_run(bytes, True{}, count)

def speakers_valid(diarize: Bool, speakers: Maybe<&2, U32>) -> Bool:
  match diarize speakers:
    case _ None{}: True{}
    case False{} Some{n}: False{}
    case True{} Some{+n}: (n >= 1 : U32) && (n <= 32 : U32)

def fields(language: Maybe<&2, String>, diarize: Bool, speakers: Maybe<&2, U32>, timestamps: Granularity, tags: Bool, format: FileFormat) -> List<&2, FormField>:
  List.append(&2, FormField, [FormField{"model_id", "scribe_v2"}, FormField{"diarize", boolean(diarize)}, FormField{"timestamps_granularity", granularity(timestamps)}, FormField{"tag_audio_events", boolean(tags)}, FormField{"file_format", file_format(format)}], List.append(&2, FormField, optional_language(language), optional_speakers(speakers)))

def request_checked(valid: Bool, count: Result<&2, &2, C.Error, U32>, file: AudioFile, language: Maybe<&2, String>, diarize: Bool, speakers: Maybe<&2, U32>, timestamps: Granularity, tags: Bool, format: FileFormat) -> Result<&2, &2, C.Error, MultipartPlan>:
  match valid count:
    case False{} _: Fail{C.Error{C.ProtocolError{}, 0, ""}}
    case _ Fail{error}: Fail{error}
    case _ Done{0}: Fail{C.Error{C.ProtocolError{}, 0, ""}}
    case True{} Done{n}: Done{MultipartPlan{"https://api.elevenlabs.io/v1/speech-to-text", fields(language, diarize, speakers, timestamps, tags, format), file}}

def request_file(+file: AudioFile, +language: Maybe<&2, String>, +diarize: Bool, +speakers: Maybe<&2, U32>, timestamps: Granularity, tags: Bool, format: FileFormat) -> Result<&2, &2, C.Error, MultipartPlan>:
  match file:
    case AudioFile{+filename, m, +bytes}: request_checked(valid_filename(filename) && valid_language(language) && speakers_valid(diarize, speakers), count_bytes(bytes, 0), file, language, diarize, speakers, timestamps, tags, format)

def request(r: TranscriptionRequest) -> Result<&2, &2, C.Error, MultipartPlan>:
  match r:
    case TranscriptionRequest{+file, +language, +diarize, +speakers, timestamps, tags, format}: request_file(file, language, diarize, speakers, timestamps, tags, format)

# Private JSON readers validate the selected provider fields without exposing Json.
def fail() -> C.Error:
  C.Error{C.ProtocolError{}, 0, ""}

def string(value: Maybe<&2, J.Json>) -> Result<&2, &2, C.Error, String>:
  match value:
    case Some{J.Text{s}}: Done{s}
    case _: Fail{fail()}

def optional_string(value: Maybe<&2, J.Json>) -> Result<&2, &2, C.Error, Maybe<&2, String>>:
  match value:
    case None{}: Done{None{}}
    case Some{J.Null{}}: Done{None{}}
    case Some{J.Text{s}}: Done{Some{s}}
    case _: Fail{fail()}

def float_parsed(value: Maybe<&2, F32>) -> Result<&2, &2, C.Error, F32>:
  match value:
    case Some{n}: Done{n}
    case None{}: Fail{fail()}

def number(value: Maybe<&2, J.Json>) -> Result<&2, &2, C.Error, F32>:
  match value:
    case Some{J.Number{s}}: float_parsed(F32.read(s))
    case _: Fail{fail()}

def optional_number(value: Maybe<&2, J.Json>) -> Result<&2, &2, C.Error, Maybe<&2, F32>>:
  match value:
    case None{}: Done{None{}}
    case Some{J.Null{}}: Done{None{}}
    case _: do Result<&2, &2, C.Error, Maybe<&2, F32>>:
      n : F32 <- number(value)
      Done{Some{n}}

def kind(s: String) -> Result<&2, &2, C.Error, WordKind>:
  match s:
    case "word": Done{Word{}}
    case "spacing": Done{Spacing{}}
    case "audio_event": Done{AudioEvent{}}
    case _: Fail{C.Error{C.UnsupportedEvent{}, 0, ""}}

def nonnegative(n: Maybe<&2, F32>) -> Bool:
  match n:
    case None{}: True{}
    case Some{+n}: (n >= 0.0 : F32) && (n < 1000000000.0 : F32)

def timing(start: Maybe<&2, F32>, end: Maybe<&2, F32>) -> Bool:
  match start end:
    case Some{a} Some{b}: (b >= a : F32)
    case _ _: True{}

def character_checked(valid: Bool, text: String, start: Maybe<&2, F32>, end: Maybe<&2, F32>) -> Result<&2, &2, C.Error, Character>:
  match valid:
    case True{}: Done{Character{text, start, end}}
    case False{}: Fail{fail()}

def character(+v: J.Json) -> Result<&2, &2, C.Error, Character>:
  do Result<&2, &2, C.Error, Character>:
    text : String <- string(J.get(v, "text"))
    +start : Maybe<&2, F32> <- optional_number(J.get(v, "start"))
    +end : Maybe<&2, F32> <- optional_number(J.get(v, "end"))
    character_checked(nonnegative(start) && nonnegative(end) && timing(start, end), text, start, end)

def characters_list(xs: List<&2, J.Json>, fuel: U32) -> Result<&2, &2, C.Error, List<&2, Character>>:
  match xs fuel:
    case Nil{} _: Done{[]}
    case _ 0: Fail{C.Error{C.FrameLimit{}, 0, ""}}
    case Con{v, tail} +n: do Result<&2, &2, C.Error, List<&2, Character>>:
      item : Character <- character(v)
      rest : List<&2, Character> <- characters_list(tail, (n - 1 : U32))
      Done{Con{item, rest}}

def characters(value: Maybe<&2, J.Json>) -> Result<&2, &2, C.Error, List<&2, Character>>:
  match value:
    case None{}: Done{[]}
    case Some{J.Array{xs}}: characters_list(xs, 10000)
    case _: Fail{fail()}

def word_checked(valid: Bool, text: String, kind: WordKind, start: Maybe<&2, F32>, end: Maybe<&2, F32>, logprob: F32, speaker: Maybe<&2, String>, chars: List<&2, Character>) -> Result<&2, &2, C.Error, TranscriptWord>:
  match valid:
    case True{}: Done{TranscriptWord{text, kind, start, end, logprob, speaker, chars}}
    case False{}: Fail{fail()}

def word(+v: J.Json) -> Result<&2, &2, C.Error, TranscriptWord>:
  do Result<&2, &2, C.Error, TranscriptWord>:
    text : String <- string(J.get(v, "text"))
    word_type : String <- string(J.get(v, "type"))
    k : WordKind <- kind(word_type)
    +start : Maybe<&2, F32> <- optional_number(J.get(v, "start"))
    +end : Maybe<&2, F32> <- optional_number(J.get(v, "end"))
    +logprob : F32 <- number(J.get(v, "logprob"))
    speaker : Maybe<&2, String> <- optional_string(J.get(v, "speaker_id"))
    chars : List<&2, Character> <- characters(J.get(v, "characters"))
    word_checked(nonnegative(start) && nonnegative(end) && timing(start, end) && (logprob <= 0.0 : F32) && (logprob > (0.0 - 1000000000.0 : F32) : F32), text, k, start, end, logprob, speaker, chars)

def words_list(xs: List<&2, J.Json>, fuel: U32) -> Result<&2, &2, C.Error, List<&2, TranscriptWord>>:
  match xs fuel:
    case Nil{} _: Done{[]}
    case _ 0: Fail{C.Error{C.FrameLimit{}, 0, ""}}
    case Con{v, tail} +n: do Result<&2, &2, C.Error, List<&2, TranscriptWord>>:
      item : TranscriptWord <- word(v)
      rest : List<&2, TranscriptWord> <- words_list(tail, (n - 1 : U32))
      Done{Con{item, rest}}

def words(value: Maybe<&2, J.Json>) -> Result<&2, &2, C.Error, List<&2, TranscriptWord>>:
  match value:
    case Some{J.Array{xs}}: words_list(xs, 100000)
    case _: Fail{fail()}

def transcript_checked(valid: Bool, text: String, language: String, probability: F32, words: List<&2, TranscriptWord>, id: Maybe<&2, String>, duration: Maybe<&2, F32>) -> Result<&2, &2, C.Error, Transcript>:
  match valid:
    case True{}: Done{Transcript{text, language, probability, words, id, duration}}
    case False{}: Fail{fail()}

def transcript(+v: J.Json) -> Result<&2, &2, C.Error, Transcript>:
  do Result<&2, &2, C.Error, Transcript>:
    text : String <- string(J.get(v, "text"))
    language : String <- string(J.get(v, "language_code"))
    +probability : F32 <- number(J.get(v, "language_probability"))
    ws : List<&2, TranscriptWord> <- words(J.get(v, "words"))
    id : Maybe<&2, String> <- optional_string(J.get(v, "transcription_id"))
    +duration : Maybe<&2, F32> <- optional_number(J.get(v, "audio_duration_secs"))
    transcript_checked((probability >= 0.0 : F32) && (probability <= 1.0 : F32) && nonnegative(duration), text, language, probability, ws, id, duration)

def parsed(value: Result<&1, &1, String, J.Json>) -> Result<&2, &2, C.Error, Transcript>:
  match value:
    case Fail{message}: Fail{fail()}
    case Done{v}: transcript(v)

def decode(+wire: String) -> Result<&2, &2, C.Error, Transcript>:
  parsed(J.read(wire))
