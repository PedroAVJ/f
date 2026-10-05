import UI
import ../f/bend2/std/F/browser/input.bend as Native
import ../f/bend2/std/F/browser/host.bend as Host
import ../f/bend2/std/F/ui/kit.bend as K
import ../f/bend2/std/F/ui/primitives.bend as P
import ../f/bend2/std/F/ai/wire_json.bend as J
import ./components/mobile_conversation.bend as C
import ../f/bend2/std/F/ui/tokens.bend as T

type Message is Data:
  Message{id: String, role: K.Role, text: String, audio: String, duration: U32, picture: K.Picture, processing: String, requestId: String, caption: String}
type Voice is Data:
  Voice{phase: String, clip: String, duration: U32, transcript: String, level: U32}
type Call is Data:
  Call{phase: String, elapsed: U32, muted: Bool, speaker: Bool, reply: String, pending: Bool}
type Photo is Data:
  Photo{phase: String, id: String, asset: String, width: U32, height: U32, requestId: String}
type ImageFile is Data:
  ImageFile{source: String, asset: String}
type Local is Data:
  Local{language: String, query: String, voice: Voice, call: Call, physical: String, audioId: String, photo: Photo, files: List<&2, ImageFile>}
type Thread is Data:
  Thread{id: String, title: String, status: String, messages: List<&2, Message>, error: String, historyBefore: String, historyHasMore: Bool, historyIsLatest: Bool, replyId: String, replyText: String}
type Snapshot is Data:
  Snapshot{threads: List<&2, Thread>, selected: String, accepted: List<&2, String>, provider: String}
type Panel is Data:
  Closed{}
  Menu{}
  Search{}
  Jumped{index: U32, highlighted: Bool}
  Recording{}
  Calling{}
  RecoverCall{}
  Notice{text: String}
type Request is Data:
  Request{id: String, thread: String, text: String, kind: String}
type State is Data:
  State{session: Snapshot, draft: String, focus: K.Focus, panel: Panel, width: U32, height: U32, prefix: String, counter: U32, pending: Maybe<&2, Request>, online: Bool, error: String, local: Local}

def State.session(value: State) -> Snapshot:
  match value:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error, local}: session
def State.draft(value: State) -> String:
  match value:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error, local}: draft
def State.focus(value: State) -> K.Focus:
  match value:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error, local}: focus
def State.panel(value: State) -> Panel:
  match value:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error, local}: panel
def State.width(value: State) -> U32:
  match value:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error, local}: width
def State.height(value: State) -> U32:
  match value:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error, local}: height
def State.prefix(value: State) -> String:
  match value:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error, local}: prefix
def State.counter(value: State) -> U32:
  match value:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error, local}: counter
def State.pending(value: State) -> Maybe<&2, Request>:
  match value:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error, local}: pending
def State.online(value: State) -> Bool:
  match value:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error, local}: online
def State.error(value: State) -> String:
  match value:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error, local}: error
def Thread.id(value: Thread) -> String:
  match value:
    case Thread{id, title, status, messages, error, historyBefore, historyHasMore, historyIsLatest, replyId, replyText}: id
def Thread.title(value: Thread) -> String:
  match value:
    case Thread{id, title, status, messages, error, historyBefore, historyHasMore, historyIsLatest, replyId, replyText}: title
def Thread.status(value: Thread) -> String:
  match value:
    case Thread{id, title, status, messages, error, historyBefore, historyHasMore, historyIsLatest, replyId, replyText}: status
def Thread.messages(value: Thread) -> List<&2, Message>:
  match value:
    case Thread{id, title, status, messages, error, historyBefore, historyHasMore, historyIsLatest, replyId, replyText}: messages
def Thread.error(value: Thread) -> String:
  match value:
    case Thread{id, title, status, messages, error, historyBefore, historyHasMore, historyIsLatest, replyId, replyText}: error
def Thread.historyBefore(value: Thread) -> String:
  match value:
    case Thread{id, title, status, messages, error, historyBefore, historyHasMore, historyIsLatest, replyId, replyText}: historyBefore
def Thread.historyHasMore(value: Thread) -> Bool:
  match value:
    case Thread{id, title, status, messages, error, historyBefore, historyHasMore, historyIsLatest, replyId, replyText}: historyHasMore
def Thread.historyIsLatest(value: Thread) -> Bool:
  match value:
    case Thread{id, title, status, messages, error, historyBefore, historyHasMore, historyIsLatest, replyId, replyText}: historyIsLatest
def Request.id(value: Request) -> String:
  match value:
    case Request{id, thread, text, kind}: id
def Request.thread(value: Request) -> String:
  match value:
    case Request{id, thread, text, kind}: thread
def Request.text(value: Request) -> String:
  match value:
    case Request{id, thread, text, kind}: text
def Request.kind(value: Request) -> String:
  match value:
    case Request{id, thread, text, kind}: kind
def Snapshot.threads(value: Snapshot) -> List<&2, Thread>:
  match value:
    case Snapshot{threads, selected, accepted, provider}: threads
def Snapshot.selected(value: Snapshot) -> String:
  match value:
    case Snapshot{threads, selected, accepted, provider}: selected
def Snapshot.accepted(value: Snapshot) -> List<&2, String>:
  match value:
    case Snapshot{threads, selected, accepted, provider}: accepted
def State.with_session(state: State, value: Snapshot) -> State:
  match state:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error, local}: State{value, draft, focus, panel, width, height, prefix, counter, pending, online, error, local}
def State.with_draft(state: State, value: String) -> State:
  match state:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error, local}: State{session, value, focus, panel, width, height, prefix, counter, pending, online, error, local}
def State.with_focus(state: State, value: K.Focus) -> State:
  match state:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error, local}: State{session, draft, value, panel, width, height, prefix, counter, pending, online, error, local}
def State.with_panel(state: State, value: Panel) -> State:
  match state:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error, local}: State{session, draft, focus, value, width, height, prefix, counter, pending, online, error, local}
def State.with_width(state: State, value: U32) -> State:
  match state:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error, local}: State{session, draft, focus, panel, value, height, prefix, counter, pending, online, error, local}
def State.with_height(state: State, value: U32) -> State:
  match state:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error, local}: State{session, draft, focus, panel, width, value, prefix, counter, pending, online, error, local}
def State.with_prefix(state: State, value: String) -> State:
  match state:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error, local}: State{session, draft, focus, panel, width, height, value, counter, pending, online, error, local}
def State.with_counter(state: State, value: U32) -> State:
  match state:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error, local}: State{session, draft, focus, panel, width, height, prefix, value, pending, online, error, local}
def State.with_pending(state: State, value: Maybe<&2, Request>) -> State:
  match state:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error, local}: State{session, draft, focus, panel, width, height, prefix, counter, value, online, error, local}
def State.with_online(state: State, value: Bool) -> State:
  match state:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error, local}: State{session, draft, focus, panel, width, height, prefix, counter, pending, value, error, local}
def State.with_error(state: State, value: String) -> State:
  match state:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error, local}: State{session, draft, focus, panel, width, height, prefix, counter, pending, online, value, local}

def Message.id(value: Message) -> String:
  match value:
    case Message{id, role, text, audio, duration, picture, processing, requestId, caption}: id
def State.local(value: State) -> Local:
  match value:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error, local}: local
def State.with_local(state: State, value: Local) -> State:
  match state:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error, local}: State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error, value}
def physical_value(value: Local, +fallback: String) -> String:
  match value:
    case Local{language, query, voice, call, +physical, audioId, photo, files}: Bool.pick(String, String.is_empty(physical), fallback, physical)
def physical(+state: State) -> String: physical_value(State.local(state), State.prefix(state))
def with_physical_value(state: State, value: String, held: Local) -> State:
  match held:
    case Local{language, query, voice, call, physical, audioId, photo, files}: State.with_local(state, Local{language, query, voice, call, value, audioId, photo, files})
def with_physical(+state: State, value: String) -> State: with_physical_value(state, value, State.local(state))
def new_physical(+state: State, kind: String) -> State:
  State.with_counter(with_physical(state, State.prefix(state) ++ "-" ++ kind ++ "-session-" ++ U32.show(State.counter(state))), U32.add(State.counter(state), 1))
def audio_id_value(value: Local) -> String:
  match value:
    case Local{language, query, voice, call, physical, audioId, photo, files}: audioId
def audio_id(+state: State) -> String: audio_id_value(State.local(state))
def with_audio_id_value(state: State, value: String, held: Local) -> State:
  match held:
    case Local{language, query, voice, call, physical, audioId, photo, files}: State.with_local(state, Local{language, query, voice, call, physical, value, photo, files})
def with_audio_id(+state: State, value: String) -> State: with_audio_id_value(state, value, State.local(state))
def has_pending(value: Maybe<&2, Request>) -> Bool:
  match value:
    case Some{request}: True{}
    case None{}: False{}
def with_voice_value(+state: State, value: Voice, held: Local) -> State:
  match held:
    case Local{language, query, voice, call, physical, audioId, photo, files}: State.with_local(state, Local{language, query, value, call, physical, audioId, photo, files})
def with_voice(+state: State, value: Voice) -> State:
  with_voice_value(state, value, State.local(state))
def voice_retry_state(state: State, v: Voice) -> State:
  match v:
    case Voice{phase, clip, duration, transcript, level}: with_voice(state, Voice{"recorded", clip, duration, transcript, 0})
def language_value(+state: State, held: Local) -> String:
  match held:
    case Local{language, query, voice, call, physical, audioId, photo, files}: language
def language(+state: State) -> String:
  language_value(state, State.local(state))
def lang(+state: State) -> K.Lang: Bool.pick(K.Lang, String.eq(language(state), "es"), K.Lang.Es{}, K.Lang.En{})
def with_language_value(+state: State, value: String, held: Local) -> State:
  match held:
    case Local{language, query, voice, call, physical, audioId, photo, files}: State.with_local(state, Local{value, query, voice, call, physical, audioId, photo, files})
def with_language(+state: State, value: String) -> State:
  with_language_value(state, value, State.local(state))
def query_value(+state: State, held: Local) -> String:
  match held:
    case Local{language, query, voice, call, physical, audioId, photo, files}: query
def query(+state: State) -> String:
  query_value(state, State.local(state))
def with_query_value(+state: State, value: String, held: Local) -> State:
  match held:
    case Local{language, query, voice, call, physical, audioId, photo, files}: State.with_local(state, Local{language, value, voice, call, physical, audioId, photo, files})
def with_query(+state: State, value: String) -> State:
  with_query_value(state, value, State.local(state))
def voice_value(+state: State, held: Local) -> Voice:
  match held:
    case Local{language, query, voice, call, physical, audioId, photo, files}: voice
def voice(+state: State) -> Voice:
  voice_value(state, State.local(state))
def voice_phase_value(+state: State, held: Voice) -> String:
  match held:
    case Voice{phase, +clip, +duration, +transcript, level}: phase
def voice_phase(+state: State) -> String:
  voice_phase_value(state, voice(state))
def voice_duration_value(+state: State, held: Voice) -> U32:
  match held:
    case Voice{phase, +clip, +duration, +transcript, level}: duration
def voice_level(v: Voice) -> U32:
  match v:
    case Voice{phase, clip, duration, transcript, level}: level
def voice_duration(+state: State) -> U32:
  voice_duration_value(state, voice(state))
def call_value(+state: State, held: Local) -> Call:
  match held:
    case Local{language, query, voice, call, physical, audioId, photo, files}: call
def call(+state: State) -> Call:
  call_value(state, State.local(state))
def with_call_value(+state: State, value: Call, held: Local) -> State:
  match held:
    case Local{language, query, voice, call, physical, audioId, photo, files}: State.with_local(state, Local{language, query, voice, value, physical, audioId, photo, files})
def with_call(+state: State, value: Call) -> State:
  with_call_value(state, value, State.local(state))
def provider_value(+state: State, held: Snapshot) -> String:
  match held:
    case Snapshot{threads, selected, accepted, provider}: provider
def provider(+state: State) -> String:
  provider_value(state, State.session(state))
def call_tree_value(+state: State, held: Call) -> P.UI:
  match held:
    case Call{+phase, elapsed, muted, speaker, reply, pending}:
      C.call_view(K.Permission.Granted{}, K.LiveCall{
        Bool.pick(K.Phase, String.eq(phase, "authorizing"), K.Phase.Ringing{0}, K.Phase.Connected{0}),
        Bool.pick(K.Mic, muted, K.Mic.Muted{}, K.Mic.Live{}), Bool.pick(K.Speaker, speaker, K.Speaker.On{}, K.Speaker.Off{}), K.Moment{elapsed, K.Motion.Reduced{}}}, State.width(state), State.height(state))
def call_tree(+state: State) -> P.UI:
  call_tree_value(state, call(state))
def read_number(value: Maybe<&2, U32>) -> U32:
  match value:
    case Some{n}: n
    case None{}: 0
def role_align(role: K.Role) -> P.Align:
  match role:
    case K.Role.Mine{}: P.Trailing{}
    case K.Role.Near{}: P.Leading{}
def is_mine(role: K.Role) -> Bool:
  match role:
    case K.Role.Mine{}: True{}
    case _: False{}
def audio_item(+id: String, +role: K.Role, duration: U32, +processing: String, requestId: String) -> K.Item:
  +play = K.renamed(K.button_tree(K.say(K.ButtonKind.Plain{}, "Mensaje de voz · " ++ K.clock_text(duration))), "button · play:" ++ id)
  +status = Bool.pick(List<&2, P.UI>, String.eq(processing, "processing"), [K.paragraph("Voice processing", "Transcribiendo…", K.small_type(), K.ink(), 220, P.Leading{})],
    Bool.pick(List<&2, P.UI>, String.eq(processing, "failed") || String.eq(processing, "missing"), [K.renamed(K.button_tree(K.say(K.ButtonKind.Quiet{}, "Reintentar audio")), "button · retry-audio:" ++ requestId)], []))
  K.Said{K.Bubble{K.pill(role_align(role), Bool.pick(T.SurfaceRole, is_mine(role), T.SurfaceRole.Mine{}, T.SurfaceRole.Surface{}),
    P.layout("Voice message", P.Vertical{}, 4, 0, 0, 0, role_align(role), K.append_trees([play], status)), P.NoStroke{})}}
def s() -> State:
  State{Snapshot{[], "", [], "codex"}, "", K.Focus.Blurred{}, Closed{}, C.width(), C.height(), "", 1, None{}, False{}, "", Local{"en", "", Voice{"idle", "", 0, "", 0}, Call{"idle", 0, False{}, False{}, "", False{}}, "", "", Photo{"idle", "", "", 0, 0, ""}, []}}
def placeholder() -> String: "Mensaje"
def selected_in(xs: List<&2, Thread>, +id: String) -> Maybe<&2, Thread>:
  match xs:
    case []: None{}
    case +t <> rest: Bool.pick(Maybe<&2, Thread>, String.eq(Thread.id(t), id), Some{t}, selected_in(rest, id))
def selected_or_empty(found: Maybe<&2, Thread>) -> Thread:
  match found:
    case Some{t}: t
    case None{}: Thread{"", "Conversación", "idle", [], "", "", False{}, True{}, "", ""}
def selected(session: Snapshot) -> Thread:
  match session:
    case Snapshot{threads, id, accepted, provider}: selected_or_empty(selected_in(threads, id))
def current(+state: State) -> Thread: selected(State.session(state))
def working(+state: State) -> Bool:
  +status = Thread.status(current(state))
  String.eq(status, "working") || String.eq(status, "running")
def photo_ready_value(value: Photo) -> Bool:
  match value:
    case Photo{phase, id, asset, width, height, requestId}: String.eq(phase, "selected") && Bool.not(String.is_empty(id))
def photo_value(value: Local) -> Photo:
  match value:
    case Local{language, query, voice, call, physical, audioId, photo, files}: photo
def photo(+state: State) -> Photo: photo_value(State.local(state))
def photo_ready(+state: State) -> Bool: photo_ready_value(photo(state))
def has_photo_value(value: Photo) -> Bool:
  match value:
    case Photo{phase, id, asset, width, height, requestId}: Bool.not(String.eq(phase, "idle"))
def has_photo(+state: State) -> Bool: has_photo_value(photo(state))
def can_send(+state: State) -> Bool:
  (Bool.not(has_photo(state)) || photo_ready(state)) && Bool.not(String.is_empty(State.prefix(state))) && Bool.not(String.is_empty(Thread.id(current(state)))) && (Bool.not(String.is_empty(String.trim(State.draft(state)))) || photo_ready(state))
def is_menu(panel: Panel) -> Bool:
  match panel:
    case Menu{}: True{}
    case _: False{}
def is_closed(panel: Panel) -> Bool:
  match panel:
    case Closed{}: True{}
    case Jumped{index, highlighted}: True{}
    case _: False{}
def can_record(+state: State) -> Bool:
  is_closed(State.panel(state)) && Bool.not(has_pending(State.pending(state))) && Bool.not(has_photo(state))
def field(+value: J.Json, key: String) -> String: J.text(J.get(value, key))
def boolean_field(value: Maybe<&2, J.Json>, otherwise: Bool) -> Bool:
  match value:
    case Some{J.Boolean{b}}: b
    case _: otherwise
def number(value: Maybe<&2, J.Json>) -> U32:
  match value:
    case Some{J.Number{n}}: read_number(U32.read(n))
    case _: 0
def audio_url(value: Maybe<&2, J.Json>) -> String:
  match value:
    case Some{v}: field(v, "url")
    case None{}: ""
def audio_caption(value: Maybe<&2, J.Json>) -> String:
  match value:
    case None{}: ""
    case Some{v}: field(v, "caption")
def audio_processing(value: Maybe<&2, J.Json>) -> String:
  match value:
    case None{}: ""
    case Some{v}: field(v, "transcriptionStatus")
def audio_duration(value: Maybe<&2, J.Json>) -> U32:
  match value:
    case Some{v}: number(J.get(v, "durationMs"))
    case None{}: 0
def message_audio_id(id: String, value: Maybe<&2, J.Json>) -> String:
  match value:
    case Some{v}: field(v, "id")
    case None{}: id
def message_id(+value: J.Json) -> String:
  message_audio_id(field(value, "id"), J.get(value, "audio"))
def decoded_picture(value: Maybe<&2, J.Json>) -> K.Picture:
  match value:
    case None{}: K.Picture{"", 0, 0, ""}
    case Some{+value}: K.Picture{field(value, "url"), number(J.get(value, "width")), number(J.get(value, "height")), "Foto"}
def line_text(+value: J.Json) -> Result<&2, &2, String, Message>:
  +role = field(value, "role")
  Bool.pick(Result<&2, &2, String, Message>, String.eq(role, "user") || String.eq(role, "assistant"),
    Done{Message{message_id(value), Bool.pick(K.Role, String.eq(role, "user"), K.Role.Mine{}, K.Role.Near{}), field(value, "text"), audio_url(J.get(value, "audio")), audio_duration(J.get(value, "audio")), decoded_picture(J.get(value, "image")), audio_processing(J.get(value, "audio")), field(value, "clientId"), audio_caption(J.get(value, "audio"))}}, Fail{"Invalid conversation message."})
def joined_line(first: Result<&2, &2, String, Message>, tail: Result<&2, &2, String, List<&2, Message>>) -> Result<&2, &2, String, List<&2, Message>>:
  match first:
    case Fail{e}: Fail{e}
    case Done{line}:
      match tail:
        case Fail{e}: Fail{e}
        case Done{xs}: Done{line <> xs}
def lines(values: List<&2, J.Json>) -> Result<&2, &2, String, List<&2, Message>>:
  match values:
    case []: Done{[]}
    case value <> rest: joined_line(line_text(value), lines(rest))
def thread_lines(+id: String, title: String, +status: String, error: String, before: String, more: Bool, latest: Bool, replyId: String, replyText: String, result: Result<&2, &2, String, List<&2, Message>>) -> Result<&2, &2, String, Thread>:
  match result:
    case Fail{e}: Fail{e}
    case Done{history}:
      Bool.pick(Result<&2, &2, String, Thread>, Bool.not(String.is_empty(id)) &&
        (String.eq(status, "idle") || String.eq(status, "working") || String.eq(status, "running") || String.eq(status, "failed") || String.eq(status, "error")),
        Done{Thread{id, title, status, history, error, before, more, latest, replyId, replyText}}, Fail{"La conversación del Mac mini no es válida."})
def thread_messages(id: String, title: String, status: String, error: String, before: String, more: Bool, latest: Bool, replyId: String, replyText: String, value: Maybe<&2, J.Json>) -> Result<&2, &2, String, Thread>:
  match value:
    case Some{J.Array{xs}}: thread_lines(id, title, status, error, before, more, latest, replyId, replyText, lines(xs))
    case _: Fail{"La conversación del Mac mini no es válida."}
def latest_field(value: Maybe<&2, J.Json>, key: String) -> String:
  match value:
    case Some{v}: field(v, key)
    case None{}: ""
def Thread.reply_id(value: Thread) -> String:
  match value:
    case Thread{id, title, status, messages, error, before, more, latest, replyId, replyText}: replyId
def Thread.reply_text(value: Thread) -> String:
  match value:
    case Thread{id, title, status, messages, error, before, more, latest, replyId, replyText}: replyText
def parse_thread(+value: J.Json) -> Result<&2, &2, String, Thread>:
  thread_messages(field(value, "id"), field(value, "title"), field(value, "status"), field(value, "error"),
    field(value, "historyBefore"), boolean_field(J.get(value, "historyHasMore"), False{}), boolean_field(J.get(value, "historyIsLatest"), True{}), latest_field(J.get(value, "latestAssistant"), "id"), latest_field(J.get(value, "latestAssistant"), "text"), J.get(value, "messages"))
def joined_thread(first: Result<&2, &2, String, Thread>, tail: Result<&2, &2, String, List<&2, Thread>>) -> Result<&2, &2, String, List<&2, Thread>>:
  match first:
    case Fail{e}: Fail{e}
    case Done{thread}:
      match tail:
        case Fail{e}: Fail{e}
        case Done{xs}: Done{thread <> xs}
def parse_threads(values: List<&2, J.Json>) -> Result<&2, &2, String, List<&2, Thread>>:
  match values:
    case []: Done{[]}
    case value <> rest: joined_thread(parse_thread(value), parse_threads(rest))
def snapshot_selected(threads: List<&2, Thread>, id: String, found: Maybe<&2, Thread>) -> Result<&2, &2, String, Snapshot>:
  match found:
    case Some{t}: Done{Snapshot{threads, id, [], "codex"}}
    case None{}: Fail{"No se encontró la conversación seleccionada."}
def snapshot_threads(+id: String, result: Result<&2, &2, String, List<&2, Thread>>) -> Result<&2, &2, String, Snapshot>:
  match result:
    case Fail{e}: Fail{e}
    case Done{+threads}: snapshot_selected(threads, id, selected_in(threads, id))
def snapshot_field(id: String, value: Maybe<&2, J.Json>) -> Result<&2, &2, String, Snapshot>:
  match value:
    case Some{J.Array{xs}}: snapshot_threads(id, parse_threads(xs))
    case _: Fail{"El Mac mini devolvió una respuesta no válida."}
def accepted_tail(text: String, result: Result<&2, &2, String, List<&2, String>>) -> Result<&2, &2, String, List<&2, String>>:
  match result:
    case Done{xs}: Done{text <> xs}
    case Fail{e}: Fail{e}
def accepted_strings(values: List<&2, J.Json>) -> Result<&2, &2, String, List<&2, String>>:
  match values:
    case []: Done{[]}
    case J.Text{text} <> rest: accepted_tail(text, accepted_strings(rest))
    case _: Fail{"Los recibos del Mac mini no son válidos."}
def accepted_field(value: Maybe<&2, J.Json>) -> Result<&2, &2, String, List<&2, String>>:
  match value:
    case None{}: Done{[]}
    case Some{J.Array{xs}}: accepted_strings(xs)
    case _: Fail{"Los recibos del Mac mini no son válidos."}
def snapshot_receipts(session: Snapshot, result: Result<&2, &2, String, List<&2, String>>) -> Result<&2, &2, String, Snapshot>:
  match session:
    case Snapshot{threads, selected, old, provider}:
      match result:
        case Done{ids}: Done{Snapshot{threads, selected, ids, provider}}
        case Fail{e}: Fail{e}
def snapshot_ack(result: Result<&2, &2, String, Snapshot>, accepted: Result<&2, &2, String, List<&2, String>>) -> Result<&2, &2, String, Snapshot>:
  match result:
    case Done{session}: snapshot_receipts(session, accepted)
    case Fail{e}: Fail{e}
def snapshot_provider(result: Result<&2, &2, String, Snapshot>, +provider: String) -> Result<&2, &2, String, Snapshot>:
  match result:
    case Fail{e}: Fail{e}
    case Done{Snapshot{threads, selected, accepted, old}}:
      Done{Snapshot{threads, selected, accepted, Bool.pick(String, String.eq(provider, "claude"), "claude", "codex")}}
def decoded_snapshot(+value: J.Json) -> Result<&2, &2, String, Snapshot>:
  snapshot_provider(snapshot_ack(snapshot_field(field(value, "selectedThreadId"), J.get(value, "threads")), accepted_field(J.get(value, "acceptedRequestIds"))), field(value, "provider"))
def snapshot_json(result: Result<&1, &1, String, J.Json>) -> Result<&2, &2, String, Snapshot>:
  match result:
    case Done{value}: decoded_snapshot(value)
    case Fail{e}: Fail{"El Mac mini devolvió una respuesta no válida."}
def decode_snapshot(raw: String) -> Result<&2, &2, String, Snapshot>:
  snapshot_json(J.read(raw))
def failed(state: State, error: String) -> State:
  State.with_error(State.with_online(state, False{}), error)
def has_receipt(ids: List<&2, String>, +id: String) -> Bool:
  match ids:
    case []: False{}
    case first <> rest: String.eq(first, id) || has_receipt(rest, id)
def is_recovery(panel: Panel) -> Bool:
  match panel:
    case RecoverCall{}: True{}
    case _: False{}
def close_recovery(+state: State) -> State:
  Bool.pick(State, is_recovery(State.panel(state)), State.with_panel(state, Closed{}), state)
def close_panel(+state: State) -> State:
  Bool.pick(State, is_recovery(State.panel(state)) && has_pending(State.pending(state)), state, State.with_panel(state, Closed{}))
def with_photo_value(state: State, value: Photo, held: Local) -> State:
  match held:
    case Local{language, query, voice, call, physical, audioId, photo, files}: State.with_local(state, Local{language, query, voice, call, physical, audioId, value, files})
def with_photo(+state: State, value: Photo) -> State: with_photo_value(state, value, State.local(state))
def reconcile_request(+state: State, pending: Maybe<&2, Request>) -> State:
  match pending:
    case None{}: state
    case Some{+request}:
      Bool.pick(State, has_receipt(Snapshot.accepted(State.session(state)), Request.id(request)),
        close_recovery(State.with_pending(Bool.pick(State, String.eq(Request.kind(request), "image"), with_photo(Bool.pick(State, String.eq(State.draft(state), Request.text(request)), State.with_draft(state, ""), state), Photo{"idle", "", "", 0, 0, ""}),
          Bool.pick(State, (String.eq(Request.kind(request), "text") || String.eq(Request.kind(request), "audio")) && String.eq(String.trim(State.draft(state)), String.trim(Request.text(request))), State.with_draft(state, ""), state)), None{})), state)
def reconcile(+state: State) -> State:
  reconcile_request(state, State.pending(state))
def restore_pending(+state: State, +request: Request) -> State:
  reconcile(State.with_pending(Bool.pick(State, String.is_empty(State.draft(state)), State.with_draft(state, Request.text(request)), state), Some{request}))
def pending_audio(+state: State, +value: J.Json) -> State:
  +id = field(value, "id")
  +thread = field(value, "thread")
  +clip = field(value, "clipId")
  Bool.pick(State, Bool.not(String.is_empty(id)) && Bool.not(String.is_empty(thread)) && Bool.not(String.is_empty(clip)),
    Bool.pick(State, has_receipt(Snapshot.accepted(State.session(state)), id), State.with_panel(with_voice(State.with_pending(Bool.pick(State, String.eq(State.draft(state), field(value, "text")), State.with_draft(state, ""), state), None{}), Voice{"idle", "", 0, "", 0}), Closed{}),
      reconcile(State.with_panel(with_voice(with_audio_id(State.with_pending(state, Some{Request{id, thread, field(value, "text"), "audio"}}), id), Voice{"recorded", clip, number(J.get(value, "durationMs")), field(value, "transcript"), 0}), Recording{}))), failed(state, "Could not restore the voice message."))
def pending_value(+state: State, +value: J.Json) -> State:
  +id = field(value, "id")
  +thread = field(value, "thread")
  +text = field(value, "text")
  Bool.pick(State, Bool.not(String.is_empty(id)) && Nat.is_le(String.length(id), 160n) &&
    Bool.not(String.is_empty(thread)) && Nat.is_le(String.length(thread), 128n) &&
    Bool.not(String.is_empty(String.trim(text))) && Nat.is_le(String.length(text), 32000n),
    restore_pending(state, Request{id, thread, text, "text"}), failed(state, "No se pudo recuperar el envío pendiente."))
def accepted_photo(+state: State, caption: String) -> State:
  with_photo(State.with_pending(Bool.pick(State, String.eq(State.draft(state), caption), State.with_draft(state, ""), state), None{}), Photo{"idle", "", "", 0, 0, ""})
def pending_image(+state: State, +v: J.Json) -> State:
  +id = field(v, "id")
  Bool.pick(State, has_receipt(Snapshot.accepted(State.session(state)), id),
    accepted_photo(state, field(v, "text")),
    State.with_pending(Bool.pick(State, String.is_empty(State.draft(state)), State.with_draft(state, field(v, "text")), state), Some{Request{id, field(v, "thread"), field(v, "text"), "image"}}))
def pending_field(+state: State, value: Maybe<&2, J.Json>) -> State:
  match value:
    case Some{+v}: Bool.pick(State, String.eq(field(v, "kind"), "audio"), pending_audio(state, v),
      Bool.pick(State, String.eq(field(v, "kind"), "image"), pending_image(state, v), Bool.pick(State, String.eq(field(v, "kind"), "call"), reconcile(State.with_panel(State.with_pending(state, Some{Request{field(v, "id"), field(v, "thread"), field(v, "text"), "call"}}), RecoverCall{})), pending_value(state, v))))
    case None{}: failed(state, "No se pudo recuperar el envío pendiente.")
def adopted(state: State, +session: Snapshot) -> State:
  reconcile(State.with_error(State.with_online(State.with_session(state, session), True{}), Thread.error(selected(session))))
def decoded_reply(state: State, result: Result<&2, &2, String, Snapshot>, +sent: Bool) -> State:
  match result:
    case Done{session}:
      +next = adopted(state, session)
      Bool.pick(State, sent, State.with_pending(State.with_draft(next, ""), None{}), next)
    case Fail{e}: failed(state, e)
def apply_reply(+state: State, reply: Host.Reply, +sent: Bool) -> State:
  match reply:
    case Host.Reply{1, +data}: decoded_reply(state, decode_snapshot(data), sent)
    case Host.Reply{status, +data}:
      failed(state, Bool.pick(String, String.is_empty(data), "No se pudo conectar con tu Mac mini. Reintenta el envío.", String.take(data, 240n)))
def resized(state: State, +w: U32, +h: U32) -> State:
  State.with_height(State.with_width(state, U32.max(w, 320)), U32.max(h, 240))
def is_search(panel: Panel) -> Bool:
  match panel:
    case Search{}: True{}
    case _: False{}
def is_recording(panel: Panel) -> Bool:
  match panel:
    case Recording{}: True{}
    case _: False{}
def is_calling(panel: Panel) -> Bool:
  match panel:
    case Calling{}: True{}
    case _: False{}
def matches(+label: String, es: String, en: String) -> Bool: String.eq(label, es) || String.eq(label, en)
def clicked(+state: State, +label: String) -> State:
  Bool.pick(State, matches(label, "Menú", "Menu"), State.with_panel(state, Menu{}),
  Bool.pick(State, matches(label, "Cerrar", "Close"), State.with_panel(state, Closed{}),
  Bool.pick(State, matches(label, "Buscar", "Search"), State.with_panel(state, Search{}),
  state)))
def update(+state: State, input: Native.Input) -> State:
  match input:
    case Native.Resized{w, h}: resized(state, w, h)
    case Native.Clicked{label}: clicked(state, label)
    case Native.Typed{label, +value}:
      Bool.pick(State, is_closed(State.panel(state)) && matches(label, "Mensaje", "Message"), State.with_draft(state, value),
      Bool.pick(State, is_search(State.panel(state)), with_query(state, value), state))
    case Native.Focused{label}:
      Bool.pick(State, is_closed(State.panel(state)) && matches(label, "Mensaje", "Message"), State.with_focus(state, K.Focus.Focused{}), state)
    case Native.Blurred{label}:
      Bool.pick(State, matches(label, "Mensaje", "Message"), State.with_focus(state, K.Focus.Blurred{}), state)
    case _: state
def cache_error(xs: List<&2, ImageFile>) -> String:
  match xs:
    case []: ""
    case ImageFile{source, +asset} <> rest: Bool.pick(String, String.starts_with(asset, "error:"), String.drop(asset, 6n), cache_error(rest))
def image_files_value(value: Local) -> List<&2, ImageFile>:
  match value:
    case Local{language, query, voice, call, physical, audioId, photo, files}: files
def image_files(+state: State) -> List<&2, ImageFile>: image_files_value(State.local(state))
def status(+state: State) -> String: Bool.pick(String, String.is_empty(State.error(state)), cache_error(image_files(state)), State.error(state))
def text_item(role: K.Role, text: String, +w: U32) -> K.Item:
  match role:
    case K.Role.Mine{}: K.Said{K.bubble(K.Role.Mine{}, K.Delivery.Sent{}, K.Said.Words{text}, K.Presence.Shown{}, K.content_width(C.box(w)))}
    case K.Role.Near{}: K.Said{K.bubble(K.Role.Near{}, Unit{}, K.Said.Words{text}, K.Presence.Shown{}, K.content_width(C.box(w)))}
def picture_asset(value: K.Picture) -> String:
  match value:
    case K.Picture{asset, width, height, label}: asset
def file_asset(xs: List<&2, ImageFile>, +source: String) -> String:
  match xs:
    case []: ""
    case ImageFile{+key, asset} <> rest: Bool.pick(String, String.eq(key, source), asset, file_asset(rest, source))
def picture_bubble(role: K.Role, shown: K.Picture, +w: U32) -> K.Item:
  match role:
    case K.Role.Mine{}: K.Said{K.bubble(K.Role.Mine{}, K.Delivery.Sent{}, K.Said.Photo{shown}, K.Presence.Shown{}, K.content_width(C.box(w)))}
    case K.Role.Near{}: K.Said{K.bubble(K.Role.Near{}, Unit{}, K.Said.Photo{shown}, K.Presence.Shown{}, K.content_width(C.box(w)))}
def picture_item(role: K.Role, value: K.Picture, +files: List<&2, ImageFile>, +w: U32) -> K.Item:
  match value:
    case K.Picture{asset, width, height, label}:
      +cached = file_asset(files, asset)
      +shown : K.Picture = K.Picture{cached, width, height, label}
      Bool.pick(K.Item, String.starts_with(cached, "error:"), K.Said{K.Bubble{K.status_line(K.alert(), "No se pudo cargar la foto.")}},
      Bool.pick(K.Item, String.is_empty(cached), K.Said{K.Bubble{K.status_line(K.spinner(14), "Cargando foto…")}}, picture_bubble(role, shown, w)))
def role_label(role: K.Role) -> String:
  match role:
    case K.Role.Mine{}: "Tú"
    case K.Role.Near{}: "Near"
def captioned_picture(+item: K.Item, +text: String, +role: K.Role, +w: U32) -> K.Item:
  match item:
    case K.Said{+bubble}:
      Bool.pick(K.Item, String.is_empty(text), item, K.Said{K.Bubble{P.layout("listitem · " ++ role_label(role) ++ ": " ++ text, P.Vertical{}, 8, 0, 0, 0, role_align(role), [K.aligned(K.bubble_tree(bubble), role_align(role)), K.aligned(K.item_tree(text_item(role, text, w)), role_align(role))])}})
    case _: item
def message_item(message: Message, +w: U32, +files: List<&2, ImageFile>) -> K.Item:
  match message:
    case Message{+id, +role, +text, +audio, duration, +picture, processing, requestId, caption}:
      Bool.pick(K.Item, String.is_empty(picture_asset(picture)), Bool.pick(K.Item, String.is_empty(audio), text_item(role, text, w), captioned_picture(audio_item(id, role, duration, processing, requestId), caption, role, w)), captioned_picture(picture_item(role, picture, files, w), text, role, w))
def message_items(xs: List<&2, Message>, +w: U32, +files: List<&2, ImageFile>) -> List<&2, K.Item>:
  match xs:
    case []: []
    case message <> rest: message_item(message, w, files) <> message_items(rest, w, files)
def panel_layers(panel: Panel, +state: State, +w: U32, +h: U32) -> List<&2, P.UI>:
  match panel:
    case Notice{text}: [C.dialog("Near", [K.paragraph("Notice", text, K.body(), K.ink(), U32.sub(C.dialog_w(w), 32), P.Leading{})], w, h)]
    case RecoverCall{}: [C.dialog("Near", [K.paragraph("Recovery", "No se confirmó un mensaje de la llamada anterior.", K.body(), K.ink(), U32.sub(C.dialog_w(w), 32), P.Leading{}), K.button_tree(K.act(K.ButtonKind.Primary{}, K.Intent.RetrySend{}, K.Form.Text{}))], w, h)]
    case Menu{}: [C.dialog("Near", K.append_trees([K.button_tree(K.act(K.ButtonKind.Quiet{}, K.Intent.Search{}, K.Form.Text{}))], Bool.pick(List<&2, P.UI>, working(state), [K.button_tree(K.say(K.ButtonKind.Quiet{}, "Detener"))], [])), w, h)]
    case _: []
def panel_tree(+state: State) -> List<&2, P.UI>: panel_layers(State.panel(state), state, State.width(state), State.height(state))
def jump_items(xs: List<&2, Message>, +index: U32, +highlighted: Bool, +w: U32, +files: List<&2, ImageFile>) -> List<&2, K.Item>:
  match xs:
    case []: []
    case message <> rest:
      +item = message_item(message, w, files)
      Bool.pick(List<&2, K.Item>, U32.is_zero(index), [Bool.pick(K.Item, highlighted, K.marked(item, 0), item)], item <> jump_items(rest, U32.sub(index, 1), highlighted, w, files))
def photo_items(value: Photo, +w: U32, +h: U32) -> List<&2, K.Item>:
  match value:
    case Photo{+phase, id, +asset, width, height, requestId}:
      Bool.pick(List<&2, K.Item>, String.is_empty(asset), [], [C.photo_preview(K.Picture{asset, width, height, "Foto"}, String.eq(phase, "uploading"), C.box(w), U32.sub(C.box_h(h), 72))])
def panel_view(+state: State, panel: Panel, history: List<&2, Message>) -> K.UI:
  match panel:
    case Search{}: C.view(C.search_view(query(state), message_items(history, State.width(state), image_files(state)), State.width(state), State.height(state)))
    case Jumped{index, highlighted}: C.view(C.conversation(placeholder(), State.draft(state), jump_items(history, index, highlighted, State.width(state), image_files(state)), State.focus(state), status(state), has_photo(state), Bool.not(can_send(state)), [], State.width(state), State.height(state)))
    case Recording{}: C.view(C.recording_view(message_items(history, State.width(state), image_files(state)), voice_duration(state), voice_phase(state), voice_level(voice(state)), State.error(state), State.width(state), State.height(state)))
    case Calling{}: C.view(call_tree(state))
    case _: C.view(C.conversation(placeholder(), State.draft(state), K.append_items(message_items(history, State.width(state), image_files(state)), K.append_items(photo_items(photo(state), State.width(state), State.height(state)), Bool.pick(List<&2, K.Item>, working(state), [K.Waiting{K.still_indicator()}], []))), State.focus(state), status(state), has_photo(state), Bool.not(can_send(state)), panel_tree(state), State.width(state), State.height(state)))
def f(+state: State) -> K.UI: panel_view(state, State.panel(state), Thread.messages(current(state)))
def request_pending(pending: Maybe<&2, Request>, +state: State, +text: String, +thread: String) -> Request:
  match pending:
    case Some{+request}:
      Bool.pick(Request, String.eq(Request.kind(request), "text") && String.eq(Request.text(request), text) && String.eq(Request.thread(request), thread), request,
        Request{State.prefix(state) ++ "-" ++ U32.show(State.counter(state)), thread, text, "text"})
    case None{}: Request{State.prefix(state) ++ "-" ++ U32.show(State.counter(state)), thread, text, "text"}
def request_for(+state: State) -> Request:
  request_pending(State.pending(state), state, String.trim(State.draft(state)), Thread.id(current(state)))
def prepare(+state: State, request: Request) -> State:
  State.with_counter(State.with_pending(state, Some{request}), U32.add(State.counter(state), 1))
def turn_body(request: Request) -> String:
  match request:
    case Request{id, thread, text, kind}:
      "{\"url\":\"/api/turn\",\"body\":{\"text\":" ++ J.quote(text) ++ ",\"threadId\":" ++ J.quote(thread) ++ ",\"requestId\":" ++ J.quote(id) ++ "}}"
def command_reply(+state: State, reply: Host.Reply) -> IO(State):
  match reply:
    case Host.Reply{1, data}: IO.pure(State, state)
    case Host.Reply{status, +data}: IO.pure(State, Bool.pick(State, is_recovery(State.panel(state)), State.with_error(state, data), State.with_panel(State.with_error(state, data), Notice{data})))
def command(+state: State, +action: String, extra: String) -> IO(State):
  IO.bind(Host.Reply, State, Host.request(10, "{\"action\":" ++ J.quote(action) ++ ",\"session\":" ++ J.quote(physical(state)) ++ extra ++ "}"), reply => command_reply(state, reply))
def after_call_reply_value(+state: State, held: Call) -> IO(State):
  match held:
    case Call{phase, +elapsed, +muted, +speaker, +old, +pending}:
      +text = Thread.reply_text(current(state))
      +ready = is_calling(State.panel(state)) && pending && Bool.not(working(state)) && Bool.not(String.is_empty(text)) && Bool.not(String.eq(Thread.reply_id(current(state)), old))
      Bool.pick(IO(State), is_calling(State.panel(state)) && pending && Bool.not(working(state)) && Bool.not(String.is_empty(State.error(state))), command(State.with_panel(with_call(state, Call{"idle", elapsed, muted, speaker, old, False{}}), Notice{State.error(state)}), "end", ""),
      Bool.pick(IO(State), ready, command(with_call(state, Call{"speaking", elapsed, muted, speaker, Thread.reply_id(current(state)), False{}}), "speak", ",\"text\":" ++ J.quote(text)),
      Bool.pick(IO(State), is_calling(State.panel(state)) && pending && Bool.not(working(state)),
        command(State.with_panel(with_call(state, Call{"idle", elapsed, muted, speaker, old, False{}}), Notice{"Near terminó sin una respuesta de voz."}), "end", ""), IO.pure(State, state))))
def after_call_reply(+state: State) -> IO(State):
  after_call_reply_value(state, call(state))
def load_picture(+state: State, +source: String) -> IO(State):
  Bool.pick(IO(State), String.starts_with(source, "/api/image/") && String.is_empty(file_asset(image_files(state), source)),
    IO.bind(Host.Reply, State, Host.request(12, "{\"action\":\"load\",\"session\":" ++ J.quote(State.prefix(state)) ++ ",\"imageId\":" ++ J.quote(String.drop(source, 11n)) ++ ",\"url\":" ++ J.quote(source) ++ "}"), reply => IO.pure(State, state)), IO.pure(State, state))
def load_pictures(xs: List<&2, Message>, state: State) -> IO(State):
  match xs:
    case []: IO.pure(State, state)
    case Message{id, role, text, audio, duration, picture, processing, requestId, caption} <> rest: IO.bind(State, State, load_picture(state, picture_asset(picture)), next => load_pictures(rest, next))
def session_media(+state: State) -> IO(State): load_pictures(Thread.messages(current(state)), state)
def fetch_session(+state: State) -> IO(State):
  IO.bind(Host.Reply, State, Host.fetch(Bool.pick(String, is_calling(State.panel(state)), "/api/session?call=1", "/api/session")), reply => IO.bind(State, State, after_call_reply(apply_reply(state, reply, False{})), next => session_media(next)))
def send_text(+state: State) -> IO(State):
  +request = request_for(state)
  +prepared = prepare(state, request)
  IO.bind(Host.Reply, State, Host.post(turn_body(request)), reply => IO.pure(State, apply_reply(prepared, reply, True{})))
def stop(+state: State) -> IO(State):
  +closed = State.with_panel(state, Closed{})
  IO.bind(Host.Reply, State, Host.post("{\"url\":\"/api/stop\",\"body\":{\"threadId\":" ++ J.quote(Thread.id(current(state))) ++ "}}"), reply => IO.pure(State, apply_reply(closed, reply, False{})))
def start_record(+state: State) -> IO(State):
  command(State.with_error(State.with_panel(with_voice(with_audio_id(new_physical(state, "voice"), ""), Voice{"authorizing", "", 0, "", 0}), Recording{}), ""), "record", ",\"transcription\":\"server\"")
def cancelled_record(+state: State, reply: Host.Reply) -> IO(State):
  match reply:
    case Host.Reply{1, data}: IO.pure(State, State.with_panel(with_audio_id(with_voice(state, Voice{"idle", "", 0, "", 0}), ""), Closed{}))
    case Host.Reply{status, data}: IO.pure(State, State.with_error(state, data))
def cancel_record(+state: State) -> IO(State):
  IO.bind(Host.Reply, State, Host.request(10, "{\"action\":\"record-cancel\",\"session\":" ++ J.quote(physical(state)) ++ "}"), reply => cancelled_record(state, reply))
def audio_failed(state: State, value: Voice, error: String) -> IO(State):
  match value:
    case Voice{phase, +clip, +duration, +transcript, level}: IO.pure(State, State.with_error(with_voice(state, Voice{"recorded", clip, duration, transcript, 0}), error))
def audio_adopted(+old: State, +next: State) -> IO(State):
  IO.pure(State, Bool.pick(State, String.is_empty(State.error(next)), State.with_panel(with_voice(next, Voice{"idle", "", 0, "", 0}), Closed{}),
    State.with_panel(voice_retry_state(next, voice(old)), Recording{})))
def audio_uploaded(+state: State, reply: Host.Reply) -> IO(State):
  match reply:
    case Host.Reply{1, data}: audio_adopted(state, apply_reply(state, reply, False{}))
    case Host.Reply{status, +data}: audio_failed(state, voice(state), data)
def audio_request_id(+state: State, clip: String, pending: Maybe<&2, Request>) -> String:
  Bool.pick(String, String.is_empty(audio_id(state)), State.prefix(state) ++ "-audio-" ++ clip, audio_id(state))
def voice_caption_value(pending: Maybe<&2, Request>, +state: State, +id: String) -> String:
  match pending:
    case Some{+request}: Bool.pick(String, String.eq(Request.kind(request), "audio") && String.eq(Request.id(request), id), Request.text(request), State.draft(state))
    case None{}: State.draft(state)
def voice_caption(+state: State, id: String) -> String:
  voice_caption_value(State.pending(state), state, id)
def upload_voice(+state: State, v: Voice) -> IO(State):
  match v:
    case Voice{phase, +clip, +duration, +transcript, level}:
      +id = audio_request_id(state, clip, State.pending(state))
      +caption = voice_caption(state, id)
      +prepared = State.with_pending(with_voice(with_audio_id(state, id), Voice{"uploading", clip, duration, transcript, 0}), Some{Request{id, Thread.id(current(state)), caption, "audio"}})
      IO.bind(Host.Reply, State, Host.request(11, "{\"url\":\"/api/audio\",\"body\":{\"requestId\":" ++ J.quote(id) ++ ",\"threadId\":" ++ J.quote(Thread.id(current(state))) ++ ",\"clipId\":" ++ J.quote(clip) ++ ",\"durationMs\":" ++ U32.show(duration) ++ ",\"transcript\":\"\",\"processing\":\"server\",\"text\":" ++ J.quote(caption) ++ "}}"), reply => audio_uploaded(prepared, reply))
def voice_elapsed(state: State, v: Voice, elapsed: U32, meter: U32) -> State:
  match v:
    case Voice{phase, clip, duration, transcript, level}: with_voice(state, Voice{phase, clip, elapsed, transcript, U32.min(100, meter)})
def voice_message_event(+state: State, +data: J.Json) -> IO(State):
  +phase = field(data, "phase")
  +next = with_voice(Bool.pick(State, String.eq(phase, "recorded"), State.with_error(state, field(data, "transcriptionError")), state), Voice{phase, field(data, "clipId"), number(J.get(data, "durationMs")), field(data, "transcript"), 0})
  Bool.pick(IO(State), String.eq(phase, "elapsed"), IO.pure(State, voice_elapsed(state, voice(state), number(J.get(data, "elapsedMs")), number(J.get(data, "level")))),
  Bool.pick(IO(State), String.eq(phase, "error"), IO.pure(State, State.with_panel(State.with_error(state, field(data, "error")), Notice{field(data, "error")})),
  Bool.pick(IO(State), String.eq(phase, "cancelled"), IO.pure(State, State.with_panel(next, Closed{})),
  Bool.pick(IO(State), String.eq(phase, "recorded") && String.eq(voice_phase(state), "sending-recording"), upload_voice(next, voice(next)),
  IO.pure(State, Bool.pick(State, String.eq(phase, "recorded"), State.with_panel(next, Recording{}), next))))))
def send_voice(+state: State) -> IO(State):
  Bool.pick(IO(State), String.eq(voice_phase(state), "recording"),
    command(with_voice(state, Voice{"sending-recording", "", voice_duration(state), "", 0}), "record-stop", ""), upload_voice(state, voice(state)))
def retry_audio(+state: State, requestId: String) -> IO(State):
  IO.bind(Host.Reply, State, Host.post("{\"url\":\"/api/audio/retry\",\"body\":{\"requestId\":" ++ J.quote(requestId) ++ "}}"), reply => IO.pure(State, apply_reply(state, reply, False{})))
def play_recording(state: State, v: Voice) -> IO(State):
  match v:
    case Voice{phase, +clip, +duration, +transcript, level}: command(state, "play", ",\"clipId\":" ++ J.quote(clip))
def play_found(+state: State, found: Maybe<&2, Message>) -> IO(State):
  match found:
    case None{}: IO.pure(State, state)
    case Some{Message{id, role, text, audio, duration, picture, processing, requestId, caption}}: command(state, "play", ",\"clipId\":" ++ J.quote(id) ++ ",\"url\":" ++ J.quote(audio))
def find_message(xs: List<&2, Message>, +id: String) -> Maybe<&2, Message>:
  match xs:
    case []: None{}
    case +m <> rest:
      +mid = Message.id(m)
      Bool.pick(Maybe<&2, Message>, String.eq(mid, id), Some{m}, find_message(rest, id))
def start_call(+state: State) -> IO(State):
  command(State.with_panel(with_call(new_physical(state, "call"), Call{"authorizing", 0, False{}, False{}, Thread.reply_id(current(state)), False{}}), Calling{}), "call", ",\"locale\":" ++ J.quote(language(state)))
def call_body(request: Request) -> String:
  match request:
    case Request{id, thread, text, kind}: "{\"url\":\"/api/turn\",\"body\":{\"mode\":\"call\",\"text\":" ++ J.quote(text) ++ ",\"threadId\":" ++ J.quote(thread) ++ ",\"requestId\":" ++ J.quote(id) ++ "}}"
def call_submitted(+state: State, reply: Host.Reply) -> IO(State):
  match reply:
    case Host.Reply{1, data}: fetch_session(apply_reply(state, reply, False{}))
    case _: command(State.with_panel(apply_reply(state, reply, False{}), RecoverCall{}), "end", "")
def retry_call_pending(state: State, value: Maybe<&2, Request>) -> IO(State):
  match value:
    case Some{request}: IO.bind(Host.Reply, State, Host.post(call_body(request)), reply => IO.pure(State, apply_reply(state, reply, False{})))
    case None{}: IO.pure(State, State.with_panel(state, Closed{}))
def call_text_value(+state: State, text: String, held: Call) -> IO(State):
  match held:
    case Call{phase, elapsed, muted, speaker, reply, pending}:
      +request : Request = Request{State.prefix(state) ++ "-call-" ++ U32.show(State.counter(state)), Thread.id(current(state)), text, "call"}
      +next = with_call(prepare(state, request), Call{"thinking", elapsed, muted, speaker, reply, True{}})
      IO.bind(Host.Reply, State, Host.post(call_body(request)), result => call_submitted(next, result))
def call_text(+state: State, text: String) -> IO(State):
  call_text_value(state, text, call(state))
def call_event_value(+state: State, +data: J.Json, held: Call) -> IO(State):
  match held:
    case Call{+old, elapsed, muted, speaker, reply, +pending}:
      +phase = field(data, "phase")
      +next = with_call(state, Call{Bool.pick(String, String.eq(phase, "elapsed"), old, phase), number(J.get(data, "elapsedMs")), boolean_field(J.get(data, "muted"), muted), boolean_field(J.get(data, "speaker"), speaker), reply, pending})
      Bool.pick(IO(State), String.eq(phase, "transcript") && Bool.not(working(next)) && Bool.not(pending), call_text(next, field(data, "text")),
      Bool.pick(IO(State), String.eq(phase, "spoken"), command(next, "listen", ""),
      Bool.pick(IO(State), String.eq(phase, "ended"), IO.pure(State, State.with_panel(next, Closed{})),
      Bool.pick(IO(State), String.eq(phase, "error"), IO.pure(State, State.with_panel(State.with_error(next, field(data, "error")), Notice{field(data, "error")})), IO.pure(State, next)))))
def call_event(+state: State, +data: J.Json) -> IO(State):
  call_event_value(state, data, call(state))
def voice_event(+state: State, value: Maybe<&2, J.Json>) -> IO(State):
  match value:
    case Some{+data}:
      +state = Bool.pick(State, boolean_field(J.get(data, "restored"), False{}), with_audio_id(with_physical(state, field(data, "session")), field(data, "requestId")), state)
      Bool.pick(IO(State), Bool.not(String.eq(field(data, "session"), physical(state))), IO.pure(State, state),
      Bool.pick(IO(State), String.eq(field(data, "mode"), "call") && is_calling(State.panel(state)), call_event(state, data),
      Bool.pick(IO(State), String.eq(field(data, "mode"), "message"), voice_message_event(state, data),
      Bool.pick(IO(State), String.eq(field(data, "mode"), "playback") && String.eq(field(data, "phase"), "error"), IO.pure(State, State.with_panel(State.with_error(state, field(data, "error")), Notice{field(data, "error")})), IO.pure(State, state)))))
    case None{}: IO.pure(State, state)
def fetch_search(+state: State) -> IO(State):
  IO.bind(Host.Reply, State, Host.post("{\"url\":\"/api/search\",\"body\":{\"query\":" ++ J.quote(query(state)) ++ "}}"), reply => IO.pure(State, apply_reply(state, reply, False{})))
def digits_until(s: String) -> String:
  match s:
    case SNil{}: ""
    case SCon{+c, tail}: Bool.pick(String, Char.is_digit(c), SCon{c, digits_until(tail)}, "")
def found_index(+label: String) -> U32:
  +raw = Bool.pick(String, String.starts_with(label, "Ir al mensaje "), String.drop(label, 14n), String.drop(label, 14n))
  U32.sub(read_number(U32.read(digits_until(raw))), 1)
def refresh(+state: State, panel: Panel) -> IO(State):
  match panel:
    case Search{}: IO.pure(State, state)
    case Jumped{index, highlighted}: IO.pure(State, State.with_panel(state, Jumped{index, False{}}))
    case _: fetch_session(state)
def photo_command(+state: State, +action: String, extra: String) -> IO(State):
  IO.bind(Host.Reply, State, Host.request(12, "{\"action\":" ++ J.quote(action) ++ ",\"session\":" ++ J.quote(physical(state)) ++ extra ++ "}"), reply => command_reply(state, reply))
def pick_photo(+state: State) -> IO(State):
  photo_command(with_photo(new_physical(state, "photo"), Photo{"picking", "", "", 0, 0, ""}), "pick", ",\"caption\":" ++ J.quote(State.draft(state)))
def cancelled_photo(+state: State, reply: Host.Reply) -> IO(State):
  match reply:
    case Host.Reply{1, data}: IO.pure(State, with_photo(state, Photo{"idle", "", "", 0, 0, ""}))
    case Host.Reply{status, data}: IO.pure(State, State.with_error(state, data))
def cancel_photo(+state: State) -> IO(State):
  IO.bind(Host.Reply, State, Host.request(12, "{\"action\":\"cancel\",\"session\":" ++ J.quote(physical(state)) ++ "}"), reply => cancelled_photo(state, reply))
def photo_uploaded(+state: State, held: Photo, reply: Host.Reply) -> IO(State):
  match held:
    case Photo{phase, id, asset, width, height, +requestId}:
      match reply:
        case Host.Reply{1, data}:
          +next = apply_reply(state, reply, False{})
          IO.pure(State, Bool.pick(State, has_receipt(Snapshot.accepted(State.session(next)), requestId), with_photo(next, Photo{"idle", "", "", 0, 0, ""}), with_photo(next, Photo{"selected", id, asset, width, height, requestId})))
        case Host.Reply{status, data}: IO.pure(State, State.with_error(with_photo(state, Photo{"selected", id, asset, width, height, requestId}), data))
def photo_request(+state: State, +id: String, +receipt: String, pending: Maybe<&2, Request>) -> Request:
  match pending:
    case Some{+request}: Bool.pick(Request, String.eq(Request.kind(request), "image"), request, Request{receipt, Thread.id(current(state)), State.draft(state), "image"})
    case None{}: Request{receipt, Thread.id(current(state)), State.draft(state), "image"}
def upload_photo_request(+state: State, held: Photo, +request: Request) -> IO(State):
  match held:
    case Photo{phase, +id, +asset, +width, +height, +requestId}:
      +receipt = Request.id(request)
      +saved : Photo = Photo{"uploading", id, asset, width, height, receipt}
      +next = State.with_pending(with_photo(state, saved), Some{request})
      IO.bind(Host.Reply, State, Host.request(13, "{\"url\":\"/api/image\",\"body\":{\"requestId\":" ++ J.quote(receipt) ++ ",\"threadId\":" ++ J.quote(Request.thread(request)) ++ ",\"imageId\":" ++ J.quote(id) ++ ",\"text\":" ++ J.quote(Request.text(request)) ++ ",\"width\":" ++ U32.show(width) ++ ",\"height\":" ++ U32.show(height) ++ "}}"), reply => photo_uploaded(next, saved, reply))
def upload_photo(+state: State, +held: Photo) -> IO(State):
  match held:
    case Photo{phase, +id, asset, width, height, +requestId}: upload_photo_request(state, held, photo_request(state, id, Bool.pick(String, String.is_empty(requestId), State.prefix(state) ++ "-image-" ++ id, requestId), State.pending(state)))
def send(+state: State) -> IO(State): Bool.pick(IO(State), photo_ready(state), upload_photo(state, photo(state)), send_text(state))
def with_files_value(state: State, value: List<&2, ImageFile>, held: Local) -> State:
  match held:
    case Local{language, query, voice, call, physical, audioId, photo, files}: State.with_local(state, Local{language, query, voice, call, physical, audioId, photo, value})
def with_files(+state: State, value: List<&2, ImageFile>) -> State: with_files_value(state, value, State.local(state))
def ready_file(file: ImageFile, +rest: List<&2, ImageFile>) -> List<&2, ImageFile>:
  match file:
    case ImageFile{source, +asset}: Bool.pick(List<&2, ImageFile>, String.starts_with(asset, "error:"), rest, ImageFile{source, asset} <> rest)
def ready_files(xs: List<&2, ImageFile>) -> List<&2, ImageFile>:
  match xs:
    case []: []
    case +file <> rest: ready_file(file, ready_files(rest))
def reload(+state: State) -> IO(State): fetch_session(close_panel(with_files(state, ready_files(image_files(state)))))
def input_step(+state: State, +input: Native.Input) -> IO(State):
  match input:
    case Native.Typed{label, +value}: Bool.pick(IO(State), is_search(State.panel(state)), fetch_search(with_query(state, value)), IO.pure(State, update(state, input)))
    case Native.Clicked{+label}:
      Bool.pick(IO(State), is_closed(State.panel(state)) && matches(label, "Adjuntar", "Attach") && Bool.not(has_pending(State.pending(state))) && Bool.not(has_photo(state)), pick_photo(state),
      Bool.pick(IO(State), matches(label, "Quitar foto", "Remove photo") && photo_ready(state), cancel_photo(state),
      Bool.pick(IO(State), is_search(State.panel(state)) && (String.starts_with(label, "Ir al mensaje ") || String.starts_with(label, "Go to message ")), IO.pure(State, State.with_panel(state, Jumped{found_index(label), True{}})),
      Bool.pick(IO(State), matches(label, "Reintentar carga", "Retry loading") || matches(label, "Cerrar", "Close"), reload(state),
      Bool.pick(IO(State), is_recovery(State.panel(state)) && matches(label, "Reintentar envío", "Retry sending"), retry_call_pending(state, State.pending(state)),
      Bool.pick(IO(State), String.starts_with(label, "play:"), play_found(state, find_message(Thread.messages(current(state)), String.drop(label, 5n))),
      Bool.pick(IO(State), matches(label, "Mensaje de voz", "Voice message") && can_record(state), start_record(state),
      Bool.pick(IO(State), is_closed(State.panel(state)) && matches(label, "Llamar a Near", "Call Near") && Bool.not(working(state)) && Bool.not(has_pending(State.pending(state))) && Bool.not(has_photo(state)), start_call(state),
      Bool.pick(IO(State), is_recording(State.panel(state)) && matches(label, "Detener grabación", "Stop recording"), command(state, "record-stop", ""),
      Bool.pick(IO(State), is_recording(State.panel(state)) && matches(label, "Enviar mensaje de voz", "Send voice message") && (String.eq(voice_phase(state), "recorded") || String.eq(voice_phase(state), "recording")), send_voice(state),
      Bool.pick(IO(State), is_closed(State.panel(state)) && String.starts_with(label, "retry-audio:") && Bool.not(working(state)), retry_audio(state, String.drop(label, 12n)),
      Bool.pick(IO(State), is_recording(State.panel(state)) && matches(label, "Reproducir grabación", "Play recording"), play_recording(state, voice(state)),
      Bool.pick(IO(State), is_recording(State.panel(state)) && matches(label, "Cancelar", "Cancel"), cancel_record(state),
      Bool.pick(IO(State), is_calling(State.panel(state)) && (matches(label, "Colgar", "Hang up") || matches(label, "Volver al chat", "Back to the chat")), command(State.with_panel(state, Closed{}), "end", ""),
      Bool.pick(IO(State), is_calling(State.panel(state)) && matches(label, "Silenciar", "Mute"), command(state, "mute", ""),
      Bool.pick(IO(State), is_calling(State.panel(state)) && matches(label, "Activar micrófono", "Unmute"), command(state, "unmute", ""),
      Bool.pick(IO(State), is_calling(State.panel(state)) && matches(label, "Altavoz", "Speaker"), command(state, "speaker", ",\"enabled\":true"),
      Bool.pick(IO(State), is_calling(State.panel(state)) && matches(label, "Quitar altavoz", "Speaker off"), command(state, "speaker", ",\"enabled\":false"),
      Bool.pick(IO(State), matches(label, "Buscar", "Search"), fetch_search(State.with_panel(state, Search{})),
      Bool.pick(IO(State), is_search(State.panel(state)) && matches(label, "Cerrar", "Close"), fetch_session(State.with_panel(state, Closed{})),
      Bool.pick(IO(State), is_closed(State.panel(state)) && matches(label, "Enviar", "Send") && can_send(state), send(state),
      Bool.pick(IO(State), matches(label, "Detener", "Stop") && working(state), stop(state), IO.pure(State, update(state, input))))))))))))))))))))))))
    case Native.Focused{label}: Bool.pick(IO(State), is_closed(State.panel(state)) && matches(label, "Mensaje", "Message"), fetch_session(update(State.with_panel(state, Closed{}), input)), IO.pure(State, update(state, input)))
    case _: IO.pure(State, update(state, input))
def session_prefix(+state: State, +prefix: String) -> State:
  Bool.pick(State, Bool.not(String.is_empty(prefix)) && Nat.is_le(String.length(prefix), 96n), State.with_prefix(state, prefix), state)
def image_loaded(+state: State, +value: J.Json) -> State:
  with_files(state, ImageFile{"/api/image/" ++ field(value, "imageId"), field(value, "url")} <> image_files(state))
def image_load_failed(+state: State, +value: J.Json) -> State:
  with_files(state, ImageFile{"/api/image/" ++ field(value, "imageId"), "error:" ++ field(value, "error")} <> image_files(state))
def image_selection_failed(state: State, value: Photo) -> State:
  match value:
    case Photo{phase, +id, asset, width, height, requestId}: with_photo(state, Bool.pick(Photo, String.is_empty(id), Photo{"idle", "", "", 0, 0, ""}, Photo{"selected", id, asset, width, height, requestId}))
def restored_image_request(+state: State, +value: J.Json) -> State:
  Bool.pick(State, Bool.not(String.is_empty(field(value, "requestId"))) && Bool.not(String.is_empty(field(value, "threadId"))) && Bool.not(has_pending(State.pending(state))),
    State.with_pending(state, Some{Request{field(value, "requestId"), field(value, "threadId"), field(value, "caption"), "image"}}), state)
def image_event_value(+state: State, +value: J.Json) -> IO(State):
  +phase = field(value, "phase")
  +id = field(value, "requestId")
  Bool.pick(IO(State), String.eq(phase, "loaded") && String.eq(field(value, "session"), State.prefix(state)), IO.pure(State, image_loaded(state, value)),
  Bool.pick(IO(State), String.eq(phase, "error") && String.eq(field(value, "session"), State.prefix(state)) && Bool.not(String.is_empty(field(value, "imageId"))), IO.pure(State, image_load_failed(state, value)),
  Bool.pick(IO(State), Bool.not(String.eq(field(value, "session"), physical(state))), IO.pure(State, state),
  Bool.pick(IO(State), String.eq(phase, "selected"), IO.pure(State,
    Bool.pick(State, Bool.not(String.is_empty(id)) && has_receipt(Snapshot.accepted(State.session(state)), id), accepted_photo(state, field(value, "caption")),
    with_photo(restored_image_request(Bool.pick(State, boolean_field(J.get(value, "restored"), False{}) && String.is_empty(State.draft(state)), State.with_draft(state, field(value, "caption")), state), value), Photo{"selected", field(value, "imageId"), field(value, "url"), number(J.get(value, "width")), number(J.get(value, "height")), id}))),
  Bool.pick(IO(State), String.eq(phase, "cancelled"), IO.pure(State, with_photo(state, Photo{"idle", "", "", 0, 0, ""})),
  Bool.pick(IO(State), String.eq(phase, "error"), IO.pure(State, State.with_panel(State.with_error(image_selection_failed(state, photo(state)), field(value, "error")), Notice{field(value, "error")})), IO.pure(State, state)))))))
def image_event(+state: State, value: Maybe<&2, J.Json>) -> IO(State):
  match value:
    case Some{+v}: image_event_value(Bool.pick(State, boolean_field(J.get(v, "restored"), False{}), with_physical(state, field(v, "session")), state), v)
    case None{}: IO.pure(State, state)
def event_json(+state: State, +reply: Host.Reply, result: Result<&1, &1, String, J.Json>) -> IO(State):
  match result:
    case Done{+value}:
      +action = field(value, "action")
      Bool.pick(IO(State), String.eq(action, "refresh"), refresh(state, State.panel(state)),
      Bool.pick(IO(State), String.eq(action, "voice"), voice_event(state, J.get(value, "data")),
      Bool.pick(IO(State), String.eq(action, "image"), image_event(state, J.get(value, "data")),
      Bool.pick(IO(State), String.eq(action, "language"), IO.pure(State, with_language(state, field(value, "value"))),
      Bool.pick(IO(State), String.eq(action, "session"), IO.pure(State, session_prefix(state, field(value, "value"))),
      Bool.pick(IO(State), String.eq(action, "pending"), IO.pure(State, pending_field(state, J.get(value, "data"))), input_step(state, Native.of(reply))))))))
    case Fail{e}: input_step(state, Native.of(reply))
def event_step(+state: State, +reply: Host.Reply) -> IO(State):
  match reply:
    case Host.Reply{1, +data}: event_json(state, reply, J.read(data))
    case _: IO.pure(State, failed(state, "No se pudo leer una acción del teléfono."))
