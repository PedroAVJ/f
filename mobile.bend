import UI
import ../f/bend2/std/F/browser/input.bend as Native
import ../f/bend2/std/F/browser/host.bend as Host
import ../f/bend2/std/F/ui/kit.bend as K
import ../f/bend2/std/F/ui/primitives.bend as P
import ../f/bend2/std/F/ai/wire_json.bend as J
import ./components/mobile_conversation.bend as C

type Thread is Data:
  Thread{id: String, title: String, status: String, messages: List<&2, K.Line>, error: String, historyBefore: String, historyHasMore: Bool, historyIsLatest: Bool}
type Snapshot is Data:
  Snapshot{threads: List<&2, Thread>, selected: String, accepted: List<&2, String>}
type Panel is Data:
  Closed{}
  Menu{}
  History{}
  Notice{text: String}
type Request is Data:
  Request{id: String, thread: String, text: String}
type State is Data:
  State{session: Snapshot, draft: String, focus: K.Focus, panel: Panel, width: U32, height: U32, prefix: String, counter: U32, pending: Maybe<&2, Request>, online: Bool, error: String}

def State.session(value: State) -> Snapshot:
  match value:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error}: session
def State.draft(value: State) -> String:
  match value:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error}: draft
def State.focus(value: State) -> K.Focus:
  match value:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error}: focus
def State.panel(value: State) -> Panel:
  match value:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error}: panel
def State.width(value: State) -> U32:
  match value:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error}: width
def State.height(value: State) -> U32:
  match value:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error}: height
def State.prefix(value: State) -> String:
  match value:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error}: prefix
def State.counter(value: State) -> U32:
  match value:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error}: counter
def State.pending(value: State) -> Maybe<&2, Request>:
  match value:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error}: pending
def State.online(value: State) -> Bool:
  match value:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error}: online
def State.error(value: State) -> String:
  match value:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error}: error
def Thread.id(value: Thread) -> String:
  match value:
    case Thread{id, title, status, messages, error, historyBefore, historyHasMore, historyIsLatest}: id
def Thread.title(value: Thread) -> String:
  match value:
    case Thread{id, title, status, messages, error, historyBefore, historyHasMore, historyIsLatest}: title
def Thread.status(value: Thread) -> String:
  match value:
    case Thread{id, title, status, messages, error, historyBefore, historyHasMore, historyIsLatest}: status
def Thread.messages(value: Thread) -> List<&2, K.Line>:
  match value:
    case Thread{id, title, status, messages, error, historyBefore, historyHasMore, historyIsLatest}: messages
def Thread.error(value: Thread) -> String:
  match value:
    case Thread{id, title, status, messages, error, historyBefore, historyHasMore, historyIsLatest}: error
def Thread.historyBefore(value: Thread) -> String:
  match value:
    case Thread{id, title, status, messages, error, historyBefore, historyHasMore, historyIsLatest}: historyBefore
def Thread.historyHasMore(value: Thread) -> Bool:
  match value:
    case Thread{id, title, status, messages, error, historyBefore, historyHasMore, historyIsLatest}: historyHasMore
def Thread.historyIsLatest(value: Thread) -> Bool:
  match value:
    case Thread{id, title, status, messages, error, historyBefore, historyHasMore, historyIsLatest}: historyIsLatest
def Request.id(value: Request) -> String:
  match value:
    case Request{id, thread, text}: id
def Request.thread(value: Request) -> String:
  match value:
    case Request{id, thread, text}: thread
def Request.text(value: Request) -> String:
  match value:
    case Request{id, thread, text}: text
def Snapshot.threads(value: Snapshot) -> List<&2, Thread>:
  match value:
    case Snapshot{threads, selected, accepted}: threads
def Snapshot.selected(value: Snapshot) -> String:
  match value:
    case Snapshot{threads, selected, accepted}: selected
def Snapshot.accepted(value: Snapshot) -> List<&2, String>:
  match value:
    case Snapshot{threads, selected, accepted}: accepted
def State.with_session(state: State, value: Snapshot) -> State:
  match state:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error}: State{value, draft, focus, panel, width, height, prefix, counter, pending, online, error}
def State.with_draft(state: State, value: String) -> State:
  match state:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error}: State{session, value, focus, panel, width, height, prefix, counter, pending, online, error}
def State.with_focus(state: State, value: K.Focus) -> State:
  match state:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error}: State{session, draft, value, panel, width, height, prefix, counter, pending, online, error}
def State.with_panel(state: State, value: Panel) -> State:
  match state:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error}: State{session, draft, focus, value, width, height, prefix, counter, pending, online, error}
def State.with_width(state: State, value: U32) -> State:
  match state:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error}: State{session, draft, focus, panel, value, height, prefix, counter, pending, online, error}
def State.with_height(state: State, value: U32) -> State:
  match state:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error}: State{session, draft, focus, panel, width, value, prefix, counter, pending, online, error}
def State.with_prefix(state: State, value: String) -> State:
  match state:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error}: State{session, draft, focus, panel, width, height, value, counter, pending, online, error}
def State.with_counter(state: State, value: U32) -> State:
  match state:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error}: State{session, draft, focus, panel, width, height, prefix, value, pending, online, error}
def State.with_pending(state: State, value: Maybe<&2, Request>) -> State:
  match state:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error}: State{session, draft, focus, panel, width, height, prefix, counter, value, online, error}
def State.with_online(state: State, value: Bool) -> State:
  match state:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error}: State{session, draft, focus, panel, width, height, prefix, counter, pending, value, error}
def State.with_error(state: State, value: String) -> State:
  match state:
    case State{session, draft, focus, panel, width, height, prefix, counter, pending, online, error}: State{session, draft, focus, panel, width, height, prefix, counter, pending, online, value}

def s() -> State:
  State{Snapshot{[], "", []}, "", K.Focus.Blurred{}, Closed{}, C.width(), C.height(), "", 1, None{}, False{}, "Conectando con tu Mac mini…"}
def placeholder() -> String: "Mensaje"
def selected_in(xs: List<&2, Thread>, +id: String) -> Maybe<&2, Thread>:
  match xs:
    case []: None{}
    case +t <> rest: Bool.pick(Maybe<&2, Thread>, String.eq(Thread.id(t), id), Some{t}, selected_in(rest, id))
def selected_or_empty(found: Maybe<&2, Thread>) -> Thread:
  match found:
    case Some{t}: t
    case None{}: Thread{"", "Conversación", "idle", [], "", "", False{}, True{}}
def selected(session: Snapshot) -> Thread:
  match session:
    case Snapshot{threads, id, accepted}: selected_or_empty(selected_in(threads, id))
def current(+state: State) -> Thread: selected(State.session(state))
def working(+state: State) -> Bool:
  +status = Thread.status(current(state))
  String.eq(status, "working") || String.eq(status, "running")
def can_send(+state: State) -> Bool:
  Bool.not(working(state)) && Bool.not(String.is_empty(State.prefix(state))) && Bool.not(String.is_empty(Thread.id(current(state)))) && Bool.not(String.is_empty(String.trim(State.draft(state))))
def is_menu(panel: Panel) -> Bool:
  match panel:
    case Menu{}: True{}
    case _: False{}
def is_closed(panel: Panel) -> Bool:
  match panel:
    case Closed{}: True{}
    case _: False{}
def is_history(panel: Panel) -> Bool:
  match panel:
    case History{}: True{}
    case _: False{}
def field(+value: J.Json, key: String) -> String: J.text(J.get(value, key))
def boolean_field(value: Maybe<&2, J.Json>, otherwise: Bool) -> Bool:
  match value:
    case Some{J.Boolean{b}}: b
    case _: otherwise
def line_text(+role: String, value: Maybe<&2, J.Json>) -> Result<&2, &2, String, K.Line>:
  match value:
    case Some{J.Text{text}}:
      Bool.pick(Result<&2, &2, String, K.Line>, String.eq(role, "user") || String.eq(role, "assistant"),
        Done{K.Line{Bool.pick(K.Role, String.eq(role, "user"), K.Role.Mine{}, K.Role.Near{}), text}}, Fail{"El historial del Mac mini no es válido."})
    case _: Fail{"El historial del Mac mini no es válido."}
def joined_line(first: Result<&2, &2, String, K.Line>, tail: Result<&2, &2, String, List<&2, K.Line>>) -> Result<&2, &2, String, List<&2, K.Line>>:
  match first:
    case Fail{e}: Fail{e}
    case Done{line}:
      match tail:
        case Fail{e}: Fail{e}
        case Done{xs}: Done{line <> xs}
def lines(values: List<&2, J.Json>) -> Result<&2, &2, String, List<&2, K.Line>>:
  match values:
    case []: Done{[]}
    case +value <> rest:
      joined_line(line_text(field(value, "role"), J.get(value, "text")), lines(rest))
def thread_lines(+id: String, title: String, +status: String, error: String, before: String, more: Bool, latest: Bool, result: Result<&2, &2, String, List<&2, K.Line>>) -> Result<&2, &2, String, Thread>:
  match result:
    case Fail{e}: Fail{e}
    case Done{history}:
      Bool.pick(Result<&2, &2, String, Thread>, Bool.not(String.is_empty(id)) &&
        (String.eq(status, "idle") || String.eq(status, "working") || String.eq(status, "running") || String.eq(status, "failed") || String.eq(status, "error")),
        Done{Thread{id, title, status, history, error, before, more, latest}}, Fail{"La conversación del Mac mini no es válida."})
def thread_messages(id: String, title: String, status: String, error: String, before: String, more: Bool, latest: Bool, value: Maybe<&2, J.Json>) -> Result<&2, &2, String, Thread>:
  match value:
    case Some{J.Array{xs}}: thread_lines(id, title, status, error, before, more, latest, lines(xs))
    case _: Fail{"La conversación del Mac mini no es válida."}
def parse_thread(+value: J.Json) -> Result<&2, &2, String, Thread>:
  thread_messages(field(value, "id"), field(value, "title"), field(value, "status"), field(value, "error"),
    field(value, "historyBefore"), boolean_field(J.get(value, "historyHasMore"), False{}), boolean_field(J.get(value, "historyIsLatest"), True{}), J.get(value, "messages"))
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
    case Some{t}: Done{Snapshot{threads, id, []}}
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
    case Snapshot{threads, selected, old}:
      match result:
        case Done{ids}: Done{Snapshot{threads, selected, ids}}
        case Fail{e}: Fail{e}
def snapshot_ack(result: Result<&2, &2, String, Snapshot>, accepted: Result<&2, &2, String, List<&2, String>>) -> Result<&2, &2, String, Snapshot>:
  match result:
    case Done{session}: snapshot_receipts(session, accepted)
    case Fail{e}: Fail{e}
def decoded_snapshot(+value: J.Json) -> Result<&2, &2, String, Snapshot>:
  snapshot_ack(snapshot_field(field(value, "selectedThreadId"), J.get(value, "threads")), accepted_field(J.get(value, "acceptedRequestIds")))
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
def reconcile_request(+state: State, pending: Maybe<&2, Request>) -> State:
  match pending:
    case None{}: state
    case Some{+request}:
      Bool.pick(State, has_receipt(Snapshot.accepted(State.session(state)), Request.id(request)),
        State.with_pending(Bool.pick(State, String.eq(String.trim(State.draft(state)), Request.text(request)), State.with_draft(state, ""), state), None{}), state)
def reconcile(+state: State) -> State:
  reconcile_request(state, State.pending(state))
def restore_pending(+state: State, +request: Request) -> State:
  reconcile(State.with_pending(Bool.pick(State, String.is_empty(State.draft(state)), State.with_draft(state, Request.text(request)), state), Some{request}))
def pending_value(+state: State, +value: J.Json) -> State:
  +id = field(value, "id")
  +thread = field(value, "thread")
  +text = field(value, "text")
  Bool.pick(State, Bool.not(String.is_empty(id)) && Nat.is_le(String.length(id), 160n) &&
    Bool.not(String.is_empty(thread)) && Nat.is_le(String.length(thread), 128n) &&
    Bool.not(String.is_empty(String.trim(text))) && Nat.is_le(String.length(text), 32000n),
    restore_pending(state, Request{id, thread, text}), failed(state, "No se pudo recuperar el envío pendiente."))
def pending_field(state: State, value: Maybe<&2, J.Json>) -> State:
  match value:
    case Some{v}: pending_value(state, v)
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
def clicked(+state: State, +label: String) -> State:
  Bool.pick(State, String.eq(label, "Menú"), State.with_panel(state, Menu{}),
  Bool.pick(State, String.eq(label, "Cerrar"), State.with_panel(state, Closed{}),
  Bool.pick(State, String.eq(label, "Ver conversación"), State.with_panel(state, History{}),
  Bool.pick(State, String.eq(label, "Llamar a Near"), State.with_panel(state, Notice{"Las llamadas aún no están conectadas."}),
  Bool.pick(State, String.eq(label, "Adjuntar"), State.with_panel(state, Notice{"Los archivos aún no están conectados."}),
  Bool.pick(State, String.eq(label, "Dictar"), State.with_panel(state, Notice{"El dictado aún no está conectado."}), state))))))
def update(+state: State, input: Native.Input) -> State:
  match input:
    case Native.Resized{w, h}: resized(state, w, h)
    case Native.Clicked{+label}:
      Bool.pick(State, is_closed(State.panel(state)) || String.eq(label, "Cerrar") ||
        (is_menu(State.panel(state)) && String.eq(label, "Ver conversación")), clicked(state, label), state)
    case Native.Typed{label, value}:
      Bool.pick(State, is_closed(State.panel(state)) && String.eq(label, placeholder()), State.with_draft(state, value), state)
    case Native.Focused{label}:
      Bool.pick(State, is_closed(State.panel(state)) && String.eq(label, placeholder()), State.with_focus(state, K.Focus.Focused{}), state)
    case Native.Blurred{label}:
      Bool.pick(State, String.eq(label, placeholder()), State.with_focus(state, K.Focus.Blurred{}), state)
    case _: state
def status(+state: State) -> String:
  Bool.pick(String, String.eq(State.error(state), "Conectando con tu Mac mini…"), State.error(state),
  Bool.pick(String, Bool.not(State.online(state)), "Sin conexión con tu Mac mini",
  Bool.pick(String, Bool.not(String.is_empty(State.error(state))), "Error · Abre el menú para verlo",
    Bool.pick(String, working(state), "Codex está trabajando…", "Codex · Mac mini"))))
def panel_layers(panel: Panel, +state: State, +w: U32, +h: U32) -> List<&2, P.UI>:
  match panel:
    case Closed{}: []
    case History{}: []
    case Notice{text}: [C.dialog("Dot", [K.paragraph("Notice", text, K.body(), K.ink(), U32.sub(C.dialog_w(w), 32), P.Leading{})], w, h)]
    case Menu{}:
      [C.dialog("Dot", K.append_trees([K.button_tree(K.say(K.ButtonKind.Quiet{}, "Ver conversación"))],
        K.append_trees(Bool.pick(List<&2, P.UI>, working(state), [K.button_tree(K.say(K.ButtonKind.Quiet{}, "Detener"))], []),
          Bool.pick(List<&2, P.UI>, String.is_empty(State.error(state)), [], [K.paragraph("Error", State.error(state), K.small_type(), K.ink(), U32.sub(C.dialog_w(w), 32), P.Leading{})]))), w, h)]
def panel_tree(+state: State) -> List<&2, P.UI>:
  panel_layers(State.panel(state), state, State.width(state), State.height(state))
def panel_view(+state: State, panel: Panel, history: List<&2, K.Line>) -> K.UI:
  match panel:
    case History{}: K.tree(C.history_view(history, Thread.historyHasMore(current(state)), Thread.historyIsLatest(current(state)), State.width(state), State.height(state)))
    case _: K.tree(C.conversation(placeholder(), State.draft(state), history, State.focus(state), status(state), Bool.not(can_send(state)), panel_tree(state), State.width(state), State.height(state)))
def f(+state: State) -> K.UI:
  panel_view(state, State.panel(state), Thread.messages(current(state)))
def request_pending(pending: Maybe<&2, Request>, +state: State, +text: String, +thread: String) -> Request:
  match pending:
    case Some{+request}:
      Bool.pick(Request, String.eq(Request.text(request), text) && String.eq(Request.thread(request), thread), request,
        Request{State.prefix(state) ++ "-" ++ U32.show(State.counter(state)), thread, text})
    case None{}: Request{State.prefix(state) ++ "-" ++ U32.show(State.counter(state)), thread, text}
def request_for(+state: State) -> Request:
  request_pending(State.pending(state), state, String.trim(State.draft(state)), Thread.id(current(state)))
def prepare(+state: State, request: Request) -> State:
  State.with_counter(State.with_pending(state, Some{request}), U32.add(State.counter(state), 1))
def turn_body(request: Request) -> String:
  match request:
    case Request{id, thread, text}:
      "{\"url\":\"/api/turn\",\"body\":{\"text\":" ++ J.quote(text) ++ ",\"threadId\":" ++ J.quote(thread) ++ ",\"requestId\":" ++ J.quote(id) ++ "}}"
def fetch_session(+state: State) -> IO(State):
  IO.bind(Host.Reply, State, Host.fetch("/api/session"), reply => IO.pure(State, apply_reply(state, reply, False{})))
def history_url(+state: State, label: String) -> String:
  Bool.pick(String, String.eq(label, "Anteriores"), "/api/session?before=" ++ Thread.historyBefore(current(state)), "/api/session")
def fetch_history(+state: State, label: String) -> IO(State):
  IO.bind(Host.Reply, State, Host.fetch(history_url(state, label)), reply => IO.pure(State, apply_reply(state, reply, False{})))
def send(+state: State) -> IO(State):
  +request = request_for(state)
  +prepared = prepare(state, request)
  IO.bind(Host.Reply, State, Host.post(turn_body(request)), reply => IO.pure(State, apply_reply(prepared, reply, True{})))
def stop(+state: State) -> IO(State):
  +closed = State.with_panel(state, Closed{})
  IO.bind(Host.Reply, State, Host.post("{\"url\":\"/api/stop\",\"body\":{\"threadId\":" ++ J.quote(Thread.id(current(state))) ++ "}}"), reply => IO.pure(State, apply_reply(closed, reply, False{})))
def input_step(+state: State, +input: Native.Input) -> IO(State):
  match input:
    case Native.Clicked{+label}:
      Bool.pick(IO(State), is_history(State.panel(state)) && String.eq(label, "Cerrar"), fetch_session(State.with_panel(state, Closed{})),
      Bool.pick(IO(State), is_history(State.panel(state)) && (String.eq(label, "Recientes") || (String.eq(label, "Anteriores") && Thread.historyHasMore(current(state)))), fetch_history(state, label),
      Bool.pick(IO(State), is_closed(State.panel(state)) && String.eq(label, "Enviar") && can_send(state), send(state),
      Bool.pick(IO(State), is_menu(State.panel(state)) && String.eq(label, "Detener") && working(state), stop(state), IO.pure(State, update(state, input))))))
    case _: IO.pure(State, update(state, input))
def session_prefix(+state: State, +prefix: String) -> State:
  Bool.pick(State, Bool.not(String.is_empty(prefix)) && Nat.is_le(String.length(prefix), 96n), State.with_prefix(state, prefix), state)
def event_json(+state: State, +reply: Host.Reply, result: Result<&1, &1, String, J.Json>) -> IO(State):
  match result:
    case Done{+value}:
      +action = field(value, "action")
      Bool.pick(IO(State), String.eq(action, "refresh"), Bool.pick(IO(State), is_history(State.panel(state)), IO.pure(State, state), fetch_session(state)),
      Bool.pick(IO(State), String.eq(action, "session"), IO.pure(State, session_prefix(state, field(value, "value"))),
      Bool.pick(IO(State), String.eq(action, "pending"), IO.pure(State, pending_field(state, J.get(value, "data"))), input_step(state, Native.of(reply)))))
    case Fail{e}: input_step(state, Native.of(reply))
def event_step(+state: State, +reply: Host.Reply) -> IO(State):
  match reply:
    case Host.Reply{1, +data}: event_json(state, reply, J.read(data))
    case _: IO.pure(State, failed(state, "No se pudo leer una acción del teléfono."))
