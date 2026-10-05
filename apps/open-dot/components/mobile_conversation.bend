import ../../f/bend2/std/F/ui/kit.bend as K
import ../../f/bend2/std/F/ui/primitives.bend as P
import ../../f/bend2/std/F/ui/tokens.bend as T
import ../../f/bend2/std/F/ui/metrics.bend as M
import ../../f/bend2/std/F/ui/nearling.bend as N
import ../../f/bend2/std/F/ui/symbols.bend as S

def width() -> U32: 390
def height() -> U32: 844
def margin() -> U32: 16
def box(+w: U32) -> U32: U32.sub(U32.max(w, 320), U32.mul(2, margin()))
def body_y() -> U32: 16
def box_h(+h: U32) -> U32: U32.sub(U32.max(h, 240), U32.add(body_y(), 20))
def identity_frame(coords: N.Coordinates, animation: N.Animation) -> N.Frame:
  match coords:
    case N.Coordinates{+row, +col}: N.Frame{"pet_6a757813525481918ff260a223792af6", "nearling-original.png", animation, 0, True{}, row, col, U32.mul(col, 192), U32.mul(row, 208), 192, 208, 1536, 2288}
def identity(+animation: N.Animation) -> K.NearIdentity:
  K.identity(identity_frame(N.coordinates(animation, 0, True{}), animation))

def blocked(+name: String) -> String:
  Bool.pick(String, P.interactive(name) || String.starts_with(name, "button, disabled · "), "Blocked " ++ name, name)
def inactive(t: P.UI) -> P.UI:
  match t:
    case P.Last{}: P.Last{}
    case P.Leaf{name, shape, w, h, align, next}: P.Leaf{blocked(name), shape, w, h, align, inactive(next)}
    case P.Node{name, lay, w, h, align, first, next}: P.Node{blocked(name), lay, w, h, align, inactive(first), inactive(next)}
def sending_name(+name: String, +disabled: Bool) -> String:
  Bool.pick(String, disabled && String.eq(name, "button · Enviar"), "button, disabled · Enviar", name)
def disable_send(t: P.UI, +disabled: Bool, +attachment: Bool) -> P.UI:
  match t:
    case P.Last{}: P.Last{}
    case P.Leaf{+name, shape, w, h, align, next}: P.Leaf{Bool.pick(String, attachment && String.eq(name, "button · Dictar"), "button, disabled · Dictar", sending_name(name, disabled)), shape, w, h, align, disable_send(next, disabled, attachment)}
    case P.Node{+name, lay, w, h, align, first, next}: P.Node{Bool.pick(String, attachment && String.eq(name, "button · Dictar"), "button, disabled · Dictar", sending_name(name, disabled)), lay, w, h, align, disable_send(first, disabled, attachment), disable_send(next, disabled, attachment)}
def has_layers(xs: List<&2, P.UI>) -> Bool:
  match xs:
    case []: False{}
    case _: True{}
def dialog_w(+w: U32) -> U32: U32.min(480, box(w))
def dialog(+title: String, content: List<&2, P.UI>, +w: U32, +h: U32) -> P.UI:
  +pw = dialog_w(w)
  +panel = P.layout("Dialog content", P.Vertical{}, 12, 16, pw, 0, P.Leading{}, K.append_trees([K.sheet_top(title, U32.sub(pw, 32))], content))
  +ph = K.height(panel)
  P.layout("dialog · " ++ title, P.Depth{}, 0, 0, w, U32.max(h, ph), P.Leading{}, [K.scrim(w, U32.max(h, ph)),
    K.placed_at("Panel", U32.div(U32.sub(w, pw), 2), U32.div(U32.sub(U32.max(h, ph), ph), 2),
      P.layout("Dialog panel", P.Depth{}, 0, 0, pw, ph, P.Leading{}, [K.filled("Container", T.SurfaceRole.Surface{}, pw, ph, P.Corner{24}, K.edge(T.LineRole.Edge{})), panel]))])
def with_next(t: P.UI, next: P.UI) -> P.UI:
  match t:
    case P.Last{}: next
    case P.Leaf{name, shape, w, h, align, old}: P.Leaf{name, shape, w, h, align, next}
    case P.Node{name, lay, w, h, align, first, old}: P.Node{name, lay, w, h, align, first, next}
def attachment_layer(+files: Bool, +w: U32, +h: U32) -> P.UI:
  +rows = K.attach_rows(Bool.pick(List<&2, K.Intent>, files, [K.Intent.Camera{}, K.Intent.Photo{}, K.Intent.Files{}], [K.Intent.Camera{}, K.Intent.Photo{}]), K.Lang.Es{}, U32.sub(K.attach_w(), 44))
  +items = P.layout("Items", P.Vertical{}, 12, 22, K.attach_w(), 0, P.Leading{}, rows)
  +panel = P.layout("group · Adjuntar", P.Depth{}, 0, 0, K.attach_w(), K.height(items), P.Leading{}, [K.glassy("Panel", K.attach_w(), K.height(items), P.Corner{40}, T.Backdrop.Content{}), items])
  P.layout("Attachment chooser", P.Depth{}, 0, 0, w, h, P.Leading{}, [P.rounded("button · Cerrar", P.Fill.None{}, w, h, P.Corner{0}, P.NoStroke{}, P.Leading{}), K.placed_at("Attachments", U32.add(margin(), 9), U32.sub(h, U32.min(h, U32.add(K.height(panel), 20))), panel)])
def photo_send(enabled: Bool, t: P.UI) -> P.UI:
  match enabled t:
    case False{} tree: tree
    case True{} P.Last{}: P.Last{}
    case True{} P.Leaf{name, shape, w, h, align, next}: P.Leaf{name, shape, w, h, align, photo_send(True{}, next)}
    case True{} P.Node{"button · Dictar", lay, w, h, align, first, next}: with_next(K.button_tree(K.send_button(False{})), photo_send(True{}, next))
    case True{} P.Node{name, lay, w, h, align, first, next}: P.Node{name, lay, w, h, align, photo_send(True{}, first), photo_send(True{}, next)}
def photo_box(+picture: K.Picture, +box: U32, +room: U32) -> U32:
  match picture:
    case K.Picture{asset, +width, +height, label}:
      U32.min(K.content_width(box), U32.max(2, U32.div(U32.mul(U32.div(U32.mul(room, width), U32.max(1, height)), 4), 3)))
def photo_preview(+picture: K.Picture, +sending: Bool, +box: U32, +room: U32) -> K.Item:
  +bubble = K.bubble_tree(K.bubble(K.Role.Mine{}, Bool.pick(K.Delivery, sending, K.Delivery.Sending{}, K.Delivery.Sent{}), K.Said.Photo{picture}, K.Presence.Shown{}, photo_box(picture, box, U32.sub(room, Bool.pick(U32, sending, 24, 0)))))
  +remove = K.renamed(K.button_tree(K.glass_button(K.Intent.Close{})), "button · Quitar foto")
  +pw = U32.max(K.width(bubble), K.width(remove))
  K.Said{K.Bubble{P.layout("Photo draft", P.Depth{}, 0, 0, pw, U32.max(K.height(bubble), K.height(remove)), P.Trailing{}, K.append_trees([K.placed_at("Photo", U32.sub(pw, K.width(bubble)), 0, bubble)], Bool.pick(List<&2, P.UI>, sending, [], [K.placed_at("Remove", U32.sub(pw, K.width(remove)), 0, remove)])))}}
# Named canvas content lets the native host scroll the thread independently.
def scroll_name(+name: String) -> String:
  Bool.pick(String, String.starts_with(name, "button · "), "button · scroll:" ++ String.drop(name, 9n),
  Bool.pick(String, String.starts_with(name, "button, disabled · "), "button, disabled · scroll:" ++ String.drop(name, 19n), "Scroll content · " ++ name))
def scroll_content(t: P.UI) -> P.UI:
  match t:
    case P.Last{}: P.Last{}
    case P.Leaf{name, shape, w, h, align, next}: P.Leaf{scroll_name(name), shape, w, h, align, scroll_content(next)}
    case P.Node{name, lay, w, h, align, first, next}: P.Node{scroll_name(name), lay, w, h, align, scroll_content(first), scroll_content(next)}
def scroll_thread(t: P.UI) -> P.UI:
  match t:
    case P.Last{}: P.Last{}
    case P.Leaf{name, shape, w, h, align, next}: P.Leaf{name, shape, w, h, align, scroll_thread(next)}
    case P.Node{"Thread area", lay, +w, +h, align, first, next}:
      with_next(P.layout("Thread area", P.Depth{}, 0, 0, w, h, P.Leading{}, [P.rounded("Scroll viewport · Conversation", P.Fill.None{}, w, h, P.Corner{0}, P.NoStroke{}, P.Leading{}), K.aligned(scroll_content(first), P.Leading{})]), scroll_thread(next))
    case P.Node{name, lay, w, h, align, first, next}: P.Node{name, lay, w, h, align, scroll_thread(first), scroll_thread(next)}
def composer_text_width(+box: U32) -> U32: U32.sub(K.inner_of(box), 184)
def composer_control(+label: String, drawing: S.Drawing) -> P.UI:
  P.layout("button · " ++ label, P.Depth{}, 0, 0, 44, 44, P.Middle{}, [K.pill_container(K.ComposerSize.Compact{}, False{}, 44, 44, 0), K.glyph(drawing, 22)])
def composer(+placeholder: String, +draft: String, +focus: K.Focus, +attachment: Bool, +disabled: Bool, +working: Bool, +box: U32) -> P.UI:
  +cw = K.inner_of(box)
  +tw = composer_text_width(box)
  +empty = String.is_empty(draft)
  +focused = K.is_focused(focus)
  +lines = K.shown_lines(K.Lines.Growing{K.inline_line_limit()}, Bool.pick(String, empty, placeholder, draft), Bool.pick(U32, focused, U32.sub(tw, 3), tw))
  +visible = K.last_lines(lines, K.inline_line_limit())
  +height = K.field_height(K.count(visible))
  +text = P.layout("Field text", P.Vertical{}, 0, 0, tw, 0, P.Middle{}, K.field_lines(visible, Bool.pick(T.TextRole, empty, K.hint(), K.ink()), focused))
  +field = P.layout("textbox · " ++ placeholder, P.Depth{}, 0, 0, U32.add(tw, 28), height, P.Middle{}, [K.value_leaf(draft), K.pill_container(K.ComposerSize.Compact{}, focused, U32.add(tw, 28), height, 0), text])
  +camera = Bool.pick(P.UI, working, composer_control("Detener", S.Drawing{"Stop reply", "0", "0", "2", [S.Path{"M6 6H18V18H6Z"}]}), composer_control("Cámara", K.camera()))
  +last = Bool.pick(P.UI, Bool.not(empty) || attachment, K.button_tree(K.send_button(disabled)), composer_control("Dictar", K.mic()))
  P.layout("group · Escribir mensaje", P.Horizontal{}, 8, 0, cw, height, P.Middle{}, [K.aligned(composer_control("Adjuntar", K.icon_or(K.intent_icon(K.Intent.Attach{}))), P.Trailing{}), field, K.aligned(camera, P.Trailing{}), K.aligned(last, P.Trailing{})])
def conversation(+placeholder: String, +draft: String, +history: List<&2, K.Item>, +focus: K.Focus, +status: String, +attachment: Bool, +disabled: Bool, +working: Bool, +layers: List<&2, P.UI>, +w: U32, +h: U32) -> P.UI:
  +messages = Bool.pick(K.Remote<&2, List<&2, K.Item>>, String.is_empty(status), K.Ready{history}, K.Failed{Some{history}})
  +c = composer(placeholder, draft, focus, attachment, disabled, working, box(w))
  +thread = K.thread_tree(K.thread(K.ThreadState{messages, 0, K.Typing.Hidden{}, 0, K.Settled{}, K.still()}, box(w)))
  +body = P.layout("Body", P.Vertical{}, 12, 0, box(w), box_h(h), P.Leading{}, [P.layout("Thread area", P.Depth{}, 0, 0, box(w), U32.sub(box_h(h), U32.add(K.height(c), 12)), P.Leading{}, [K.aligned(thread, P.Trailing{})]), K.aligned(c, P.Middle{})])
  +base = P.layout("Conversation", P.Depth{}, 0, 0, w, h, P.Leading{}, [K.placed_at("Body", margin(), body_y(), scroll_thread(body))])
  P.layout("Conversation", P.Depth{}, 0, 0, w, h, P.Leading{}, K.append_trees([Bool.pick(P.UI, has_layers(layers), inactive(base), base)], layers))

def text_of(t: P.UI) -> String:
  match t:
    case P.Last{}: ""
    case P.Leaf{name, P.Shape{geometry, fill, stroke, effects}, w, h, align, next}:
      match geometry:
        case P.Text{text, text_type}: text ++ " " ++ text_of(next)
        case _: text_of(next)
    case P.Node{name, lay, w, h, align, first, next}: text_of(first) ++ text_of(next)
def speaker_of(t: P.UI) -> String:
  match t:
    case P.Last{}: "Near"
    case P.Leaf{name, shape, w, h, align, next}: Bool.pick(String, String.starts_with(name, "listitem · Tú:"), "Tú", speaker_of(next))
    case P.Node{name, lay, w, h, align, first, next}: Bool.pick(String, String.starts_with(name, "listitem · Tú:"), "Tú", speaker_of(first))
# Recursive branches must stop at their limit, not evaluate discarded work.
def choose(-A: Type, condition: Bool, yes: Unit -> A, no: Unit -> A) -> A:
  match condition:
    case True{}: yes(Unit{})
    case False{}: no(Unit{})
def take_u(s: String, +n: U32) -> String:
  match s:
    case SNil{}: ""
    case SCon{+c, t}: choose(String, U32.is_zero(n), u => "", u => SCon{c, take_u(t, U32.sub(n, 1))})
def drop_u(s: String, +n: U32) -> String:
  match s:
    case SNil{}: ""
    case SCon{+c, +t}: choose(String, U32.is_zero(n), u => SCon{c, t}, u => drop_u(t, U32.sub(n, 1)))
def index_go(h: String, +needle: String, +i: U32) -> Maybe<&2, U32>:
  match h:
    case SNil{}: None{}
    case SCon{+c, +t}: choose(Maybe<&2, U32>, String.starts_with(SCon{c, t}, needle), u => Some{i}, u => index_go(t, needle, U32.add(i, 1)))
def found_at(at: Maybe<&2, U32>, +id: U32, +label: String, +text: String, +q: String) -> List<&2, K.Found>:
  match at:
    case None{}: []
    case Some{+p}: [K.Found{id, label, take_u(text, p), take_u(drop_u(text, p), U32.from_nat(String.length(q))), drop_u(text, U32.add(p, U32.from_nat(String.length(q))))}]
def item_found(i: K.Item, +id: U32, +q: String) -> List<&2, K.Found>:
  match i:
    case K.Said{K.Bubble{+tree}}:
      +text = String.trim(text_of(tree))
      choose(List<&2, K.Found>, String.is_empty(q), u => [K.Found{id, speaker_of(tree), "", "", text}], u => found_at(index_go(String.to_lower(text), String.to_lower(q), 0), id, speaker_of(tree), text, q))
    case _: []
def found_go(xs: List<&2, K.Item>, +id: U32, +q: String, acc: List<&2, K.Found>) -> List<&2, K.Found>:
  match xs:
    case []: acc
    case item <> rest: found_go(rest, U32.add(id, 1), q, List.append(&2, K.Found, item_found(item, id, q), acc))
def first_found(xs: List<&2, K.Found>, +n: U32) -> List<&2, K.Found>:
  match xs:
    case []: []
    case +x <> rest: choose(List<&2, K.Found>, U32.is_zero(n), u => [], u => x <> first_found(rest, U32.sub(n, 1)))
def no_found(xs: List<&2, K.Found>) -> Bool:
  match xs:
    case []: True{}
    case _: False{}
def search_results(+query: String, history: List<&2, K.Item>, +limit: U32) -> K.Results:
  +q = String.trim(query)
  +found = first_found(found_go(history, 0, q, []), limit)
  Bool.pick(K.Results, String.is_empty(q), K.Results.Recent{found}, Bool.pick(K.Results, no_found(found), K.Results.Nothing{q}, K.Results.Matches{found}))
def search_view(+query: String, history: List<&2, K.Item>, +w: U32, +h: U32) -> P.UI:
  +inner = U32.sub(w, 40)
  K.sheet_tree(K.sheet("Buscar", K.SheetBody.Find{K.search("Buscar en la conversación", K.FieldState{query, K.Focus.Focused{}}, search_results(query, history, U32.min(8, U32.max(1, U32.div(U32.sub(U32.max(h, 160), 160), 80)))), inner)}, K.Settled{}, K.still(), w, h))
def sheet_width(+w: U32) -> U32: Bool.pick(U32, K.is_side(K.sheet_size(w)), K.sheet_w(), w)
def editor_view(+draft: String, +focus: K.Focus, +disabled: Bool, +w: U32, +h: U32) -> P.UI:
  +one = K.plain(K.Lines.Growing{1}, "Mensaje", [], K.FieldState{"", focus})
  +base = K.height(K.sheet_panel(K.is_side(K.sheet_size(w)), "Editar mensaje", K.SheetBody.Editor{one}, sheet_width(w), h))
  +lines = U32.add(1, U32.div(U32.sub(h, base), K.line_height(K.body())))
  disable_send(K.sheet_tree(K.sheet("Editar mensaje", K.SheetBody.Editor{K.plain(K.Lines.Growing{lines}, "Mensaje", [], K.FieldState{draft, focus})}, K.Settled{}, K.still(), w, h)), disabled, False{})
def detail_view(+content: P.UI, +w: U32, +h: U32) -> P.UI:
  +pw = sheet_width(w)
  +inner = U32.sub(pw, 40)
  +empty : K.SheetBody = K.SheetBody.Detail{K.Bubble{K.spacer("Message", 0, 0, P.Leading{})}, "", []}
  +base = K.height(K.sheet_panel(K.is_side(K.sheet_size(w)), "Mensaje completo", empty, pw, h))
  +room = U32.sub(h, base)
  +scroll = P.layout("Message detail", P.Depth{}, 0, 0, inner, room, P.Leading{}, [P.rounded("Scroll viewport · Message", P.Fill.None{}, inner, room, P.Corner{0}, P.NoStroke{}, P.Leading{}), K.aligned(scroll_content(content), P.Leading{})])
  K.sheet_tree(K.sheet("Mensaje completo", K.SheetBody.Detail{K.Bubble{scroll}, "", []}, K.Settled{}, K.still(), w, h))
def meter_bars(n: Nat, +level: U32) -> List<&2, P.UI>:
  match n:
    case 0n: []
    case Succ{+k}:
      +height = U32.add(3, U32.div(U32.mul(level, U32.add(8, U32.mod(U32.mul(U32.from_nat(k), 7), 17))), 100))
      P.rounded("Audio level", P.Fill.None{}, 2, height, P.Full{}, P.Stroke{T.LineRole.Ink{}, T.State.Rest{}, "2"}, P.Middle{}) <> meter_bars(k, level)
def recording_composer(+elapsed: U32, +phase: String, +level: U32, +box: U32) -> P.UI:
  +ready = String.eq(phase, "recorded")
  +recording = String.eq(phase, "recording")
  +enabled = ready || recording
  +cw = K.composer_w(box)
  +meter_w = U32.sub(cw, 184)
  +control = Bool.pick(String, ready, "Reproducir grabación", "Detener grabación")
  +path = Bool.pick(String, ready, "M8 5L20 12L8 19Z", "M6 6H18V18H6Z")
  +cancel = P.layout(Bool.pick(String, String.eq(phase, "uploading"), "button, disabled · Cancelar", "button · Cancelar"), P.Depth{}, 0, 0, 44, 44, P.Middle{}, [K.glyph(S.Drawing{"Cancel", "0", "0", "2", [S.Path{"M6 6L18 18M18 6L6 18"}]}, 18)])
  +middle = P.layout("Recording meter", P.Horizontal{}, 4, 0, U32.sub(cw, 132), 44, P.Middle{}, [K.paragraph("Recording timer", K.clock_text(elapsed), K.small_type(), K.ink(), 48, P.Middle{}), P.layout("Audio meter", P.Horizontal{}, 3, 0, meter_w, 32, P.Middle{}, meter_bars(U32.to_nat(U32.div(meter_w, 5)), level))])
  +stop = P.layout(Bool.pick(String, enabled, "button · ", "button, disabled · ") ++ control, P.Depth{}, 0, 0, 44, 44, P.Middle{}, [K.glyph_in(S.Drawing{"Recording control", "0", "0", "2", [S.Path{path}]}, 18, Bool.pick(T.State, enabled, T.State.Rest{}, T.State.Disabled{}))])
  +send = K.renamed(K.button_tree(K.send_button(Bool.not(enabled))), Bool.pick(String, enabled, "button · Enviar mensaje de voz", "button, disabled · Enviar mensaje de voz"))
  P.layout("group · Mensaje de voz", P.Depth{}, 0, 0, cw, 44, P.Middle{}, [K.pill_container(K.composer_size(box), False{}, cw, 44, 0), P.layout("Recording controls", P.Horizontal{}, 0, 0, cw, 44, P.Middle{}, [cancel, middle, stop, send])])
def replace_composer(t: P.UI, +composer: P.UI) -> P.UI:
  match t:
    case P.Last{}: P.Last{}
    case P.Leaf{name, shape, w, h, align, next}: P.Leaf{blocked(name), shape, w, h, align, replace_composer(next, composer)}
    case P.Node{"group · Escribir mensaje", lay, w, h, align, first, next}: with_next(composer, replace_composer(next, composer))
    case P.Node{name, lay, w, h, align, first, next}: P.Node{blocked(name), lay, w, h, align, replace_composer(first, composer), replace_composer(next, composer)}
def recording_view(history: List<&2, K.Item>, +elapsed_ms: U32, +phase: String, +level: U32, +error: String, +w: U32, +h: U32) -> P.UI:
  +error_h = Bool.pick(U32, String.is_empty(error), 0, 56)
  +base = conversation("Mensaje", "", history, K.Focus.Blurred{}, "", False{}, True{}, False{}, [], w, U32.sub(h, error_h))
  P.layout("Near", P.Depth{}, 0, 0, w, h, P.Leading{}, K.append_trees([replace_composer(base, recording_composer(elapsed_ms, phase, level, box(w)))], Bool.pick(List<&2, P.UI>, String.is_empty(error), [], [K.placed_at("Recording error", margin(), U32.sub(h, 56), K.paragraph("status · Error", error, K.small_type(), K.ink(), box(w), P.Leading{}))])))
def call_view(permission: K.Permission, slice: K.CallSlice(permission), +w: U32, +h: U32) -> P.UI:
  +controls = K.call_controls_tree(K.call_controls(permission, slice))
  +pet = Bool.pick(P.UI, U32.is_lt(h, 340), K.identity_compact(identity(N.Idle{})), K.identity_tree(identity(N.Idle{})))
  +body = P.layout("Call body", P.Vertical{}, Bool.pick(U32, U32.is_lt(h, 340), 12, 32), 0, U32.min(w, 320), 0, P.Middle{}, [K.aligned(pet, P.Middle{}), controls])
  P.layout("Near call", P.Depth{}, 0, 0, w, h, P.Leading{}, [K.placed_at("Call", U32.div(U32.sub(w, K.width(body)), 2), U32.max(48, U32.div(U32.sub(h, K.height(body)), 2)), body), K.placed_at("Back", margin(), 16, K.button_tree(K.back_button()))])

type Copy is Data:
  Copy{es: String, en: String}
def copies() -> List<&2, Copy>:
  [Copy{"Quitar archivo", "Remove file"}, Copy{"Notificaciones", "Notifications"}, Copy{"Transcribiendo…", "Transcribing…"}, Copy{"Reintentar audio", "Retry audio"}, Copy{"Mensaje de voz · ", "Voice message · "}, Copy{"Foto", "Photo"}, Copy{"Quitar foto", "Remove photo"}, Copy{"Cargando foto…", "Loading photo…"}, Copy{"No se pudo cargar la foto.", "Could not load the photo."}, Copy{"No se pudo cargar", "Could not load"}, Copy{"Reintentar", "Retry"}, Copy{"Enviando…", "Sending…"}, Copy{"Near terminó sin una respuesta de voz.", "Near finished without a spoken reply."}, Copy{"Mensaje", "Message"}, Copy{"Dictar", "Voice message"}, Copy{"Dictate", "Voice message"}, Copy{"Mensaje de voz", "Voice message"}, Copy{"Buscar en la conversación", "Search conversation"}, Copy{"Buscar", "Search"}, Copy{"Recientes", "Recent"}, Copy{"Resultados", "Results"}, Copy{"Sin resultados", "No results"}, Copy{"Aún no hay mensajes", "No messages yet"}, Copy{"Conversación", "Conversation"}, Copy{"Escribir mensaje", "Write message"}, Copy{"Modelo", "Model"}, Copy{"Detener", "Stop"}, Copy{"Tú", "You"}, Copy{"Detener grabación", "Stop recording"}, Copy{"Reproducir grabación", "Play recording"}, Copy{"Enviar mensaje de voz", "Send voice message"}, Copy{"Silenciado", "Muted"}, Copy{"Llamada terminada", "Call ended"}, Copy{"Llamando a Near…", "Calling Near…"}, Copy{"Near necesita tu micrófono para hablar contigo.", "Near needs your microphone to talk with you."}, Copy{"Acepta el permiso del navegador para continuar.", "Allow microphone access on your iPhone to continue."}, Copy{"El micrófono está bloqueado. Actívalo en los ajustes del navegador.", "Microphone access is blocked. Enable it in iPhone Settings."}]
def copied(xs: List<&2, Copy>, +text: String, +lang: K.Lang) -> String:
  match xs:
    case []: text
    case Copy{+es, +en} <> rest: Bool.pick(String, String.eq(text, es) || String.eq(text, en), K.es_en(lang, es, en), copied(rest, text, lang))
def action_copy(xs: List<&2, K.Intent>, +text: String, +lang: K.Lang) -> String:
  match xs:
    case []: copied(copies(), text, lang)
    case +intent <> rest: Bool.pick(String, String.eq(text, K.intent_label(intent)), Bool.pick(String, String.eq(text, "Dictar"), K.es_en(lang, "Mensaje de voz", "Voice message"), K.intent_text(intent, lang)), action_copy(rest, text, lang))
def copy_text(+text: String, +lang: K.Lang) -> String:
  Bool.pick(String, String.eq(text, "No se confirmó un mensaje de la llamada anterior."), K.es_en(lang, text, "A message from the previous call was not confirmed."),
  Bool.pick(String, String.eq(text, "Reintentar transcripción"), K.es_en(lang, "Reintentar transcripción", "Retry transcription"),
  Bool.pick(String, String.eq(text, "Dictar") || String.eq(text, "Dictate"), K.es_en(lang, "Mensaje de voz", "Voice message"),
  Bool.pick(String, String.eq(text, "Acepta el permiso del navegador para continuar."), K.es_en(lang, "Acepta el permiso del micrófono en tu iPhone para continuar.", "Allow microphone access on your iPhone to continue."),
  Bool.pick(String, String.eq(text, "El micrófono está bloqueado. Actívalo en los ajustes del navegador."), K.es_en(lang, "El micrófono está bloqueado. Actívalo en los ajustes del iPhone.", "Microphone access is blocked. Enable it in iPhone Settings."),
  Bool.pick(String, String.starts_with(text, "Mensaje de voz · "), K.es_en(lang, "Mensaje de voz · ", "Voice message · ") ++ drop_u(text, 17),
  Bool.pick(String, String.starts_with(text, "Ir al mensaje "), K.es_en(lang, "Ir al mensaje ", "Go to message ") ++ drop_u(text, 14),
  Bool.pick(String, String.starts_with(text, "Sin resultados para «"), K.es_en(lang, "Sin resultados para «", "No results for “") ++ drop_u(text, 21),
  Bool.pick(String, String.starts_with(text, "En llamada · "), K.es_en(lang, "En llamada · ", "In call · ") ++ drop_u(text, 13),
  Bool.pick(String, String.starts_with(text, "Procesando audio… "), K.es_en(lang, "Procesando audio… ", "Processing audio… ") ++ drop_u(text, 18),
  Bool.pick(String, String.starts_with(text, "Enviando mensaje de voz… "), K.es_en(lang, "Enviando mensaje de voz… ", "Sending voice message… ") ++ drop_u(text, 24),
  Bool.pick(String, String.starts_with(text, "Grabando · "), K.es_en(lang, "Grabando · ", "Recording · ") ++ drop_u(text, 11),
  Bool.pick(String, String.starts_with(text, "Grabación lista · "), K.es_en(lang, "Grabación lista · ", "Recording ready · ") ++ drop_u(text, 18), action_copy(K.intents(), text, lang))))))))))))))
def history_copy(+text: String, +lang: K.Lang) -> String:
  Bool.pick(String, String.eq(text, "Leer más"), K.es_en(lang, "Leer más", "Read more"),
  Bool.pick(String, String.eq(text, "Editar mensaje"), K.es_en(lang, "Editar mensaje", "Edit message"),
  Bool.pick(String, String.eq(text, "Mensaje completo"), K.es_en(lang, "Mensaje completo", "Full message"),
  Bool.pick(String, String.starts_with(text, "Leer mensaje "), K.es_en(lang, "Leer mensaje ", "Read message ") ++ drop_u(text, 13),
  Bool.pick(String, String.eq(text, "Mensajes anteriores"), K.es_en(lang, "Mensajes anteriores", "Earlier messages"), Bool.pick(String, String.eq(text, "Mensajes recientes"), K.es_en(lang, "Mensajes recientes", "Latest messages"), copy_text(text, lang)))))))
def scroll_copy(+text: String, +lang: K.Lang) -> String:
  Bool.pick(String, String.starts_with(text, "scroll:"), "scroll:" ++ history_copy(drop_u(text, 7), lang), history_copy(text, lang))
def locale_name(+name: String, +lang: K.Lang) -> String:
  Bool.pick(String, String.starts_with(name, "button, disabled · "), "button, disabled · " ++ scroll_copy(drop_u(name, 19), lang),
  Bool.pick(String, String.starts_with(name, "button · "), "button · " ++ scroll_copy(drop_u(name, 9), lang),
  Bool.pick(String, String.starts_with(name, "textbox · "), "textbox · " ++ copy_text(drop_u(name, 10), lang),
  Bool.pick(String, String.starts_with(name, "heading · "), "heading · " ++ history_copy(drop_u(name, 10), lang),
  Bool.pick(String, String.starts_with(name, "dialog · "), "dialog · " ++ scroll_copy(drop_u(name, 9), lang),
  Bool.pick(String, String.starts_with(name, "group · "), "group · " ++ copy_text(drop_u(name, 8), lang),
  Bool.pick(String, String.starts_with(name, "status · "), "status · " ++ scroll_copy(drop_u(name, 9), lang), name)))))))
def empty_value(t: P.UI) -> Bool:
  match t:
    case P.Leaf{name, shape, w, h, align, next}: String.eq(name, "value · ")
    case _: False{}
def reference_effects(xs: List<&2, P.Effect>) -> List<&2, P.Effect>:
  match xs:
    case []: []
    case P.Glass{blur, saturation, refraction, highlight, tint, edge, over} <> rest:
      P.Glass{blur, saturation, refraction, 2, tint, edge, over} <> reference_effects(rest)
    case effect <> rest: effect <> reference_effects(rest)
def localize_shape(+shape: P.Shape, +lang: K.Lang, +copy: Bool) -> P.Shape:
  match shape:
    case P.Shape{geometry, fill, stroke, effects}:
      match geometry:
        case P.Text{+text, text_type}: P.Shape{P.Text{Bool.pick(String, copy, history_copy(text, lang), text), text_type}, fill, stroke, effects}
        case _: P.Shape{geometry, fill, stroke, reference_effects(effects)}
def localized_go(t: P.UI, +lang: K.Lang, +copy: Bool) -> P.UI:
  match t:
    case P.Last{}: P.Last{}
    case P.Leaf{+name, shape, w, h, align, next}: P.Leaf{locale_name(name, lang), localize_shape(shape, lang, copy), w, h, align, localized_go(next, lang, copy)}
    case P.Node{+name, lay, w, h, align, +first, next}:
      +own_copy = Bool.pick(Bool, String.starts_with(name, "button · ") || String.starts_with(name, "button, disabled · ") || String.starts_with(name, "Blocked button · ") || String.starts_with(name, "Blocked button, disabled · "), True{}, Bool.pick(Bool, String.starts_with(name, "listitem · ") || String.starts_with(name, "Scroll content · listitem · ") || String.eq(name, "Snippet"), False{}, Bool.pick(Bool, String.starts_with(name, "textbox · "), empty_value(first), copy)))
      P.Node{locale_name(name, lang), lay, w, h, align, localized_go(first, lang, own_copy), localized_go(next, lang, copy)}
def localized(t: P.UI, lang: K.Lang) -> P.UI: localized_go(t, lang, True{})
def view(t: P.UI) -> K.UI: K.UI.Drawn{r => localized(t, K.lang_of(r))}
