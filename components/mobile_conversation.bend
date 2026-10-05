import ../../f/bend2/std/F/ui/kit.bend as K
import ../../f/bend2/std/F/ui/primitives.bend as P
import ../../f/bend2/std/F/ui/tokens.bend as T
import ../../f/bend2/std/F/ui/metrics.bend as M
import ../../f/bend2/std/F/ui/nearling.bend as N

def width() -> U32: 390
def height() -> U32: 844
def margin() -> U32: 16
def box(+w: U32) -> U32: U32.sub(U32.max(w, 320), U32.mul(2, margin()))
def body_y() -> U32: 128
def box_h(+h: U32) -> U32: U32.sub(U32.max(h, 240), U32.add(body_y(), 20))
def identity_frame(coords: N.Coordinates, animation: N.Animation) -> N.Frame:
  match coords:
    case N.Coordinates{+row, +col}: N.Frame{"pet_6a757813525481918ff260a223792af6", "nearling-original.png", animation, 0, True{}, row, col, U32.mul(col, 192), U32.mul(row, 208), 192, 208, 1536, 2288}
def identity(+animation: N.Animation) -> K.NearIdentity:
  K.identity(identity_frame(N.coordinates(animation, 0, True{}), animation))
def header(+w: U32) -> P.UI:
  K.header_tree(K.header(K.glass_button(K.Intent.Menu{}), identity(N.Idle{}), K.glass_button(K.Intent.Call{}), box(w)))

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
def photo_send(t: P.UI, +enabled: Bool) -> P.UI:
  match t:
    case P.Last{}: P.Last{}
    case P.Leaf{name, shape, w, h, align, next}: P.Leaf{name, shape, w, h, align, photo_send(next, enabled)}
    case P.Node{+name, lay, w, h, align, first, +next}:
      Bool.pick(P.UI, enabled && String.eq(name, "button · Dictar"), with_next(K.button_tree(K.send_button(False{})), photo_send(next, enabled)), P.Node{name, lay, w, h, align, photo_send(first, enabled), photo_send(next, enabled)})
def photo_box(+picture: K.Picture, +box: U32, +room: U32) -> U32:
  match picture:
    case K.Picture{asset, +width, +height, label}:
      U32.min(K.content_width(box), U32.max(2, U32.div(U32.mul(U32.div(U32.mul(room, width), U32.max(1, height)), 4), 3)))
def photo_preview(+picture: K.Picture, +sending: Bool, +box: U32, +room: U32) -> K.Item:
  +bubble = K.bubble_tree(K.bubble(K.Role.Mine{}, Bool.pick(K.Delivery, sending, K.Delivery.Sending{}, K.Delivery.Sent{}), K.Said.Photo{picture}, K.Presence.Shown{}, photo_box(picture, box, U32.sub(room, Bool.pick(U32, sending, 24, 0)))))
  +remove = K.renamed(K.button_tree(K.glass_button(K.Intent.Close{})), "button · Quitar foto")
  +pw = U32.max(K.width(bubble), K.width(remove))
  K.Said{K.Bubble{P.layout("Photo draft", P.Depth{}, 0, 0, pw, U32.max(K.height(bubble), K.height(remove)), P.Trailing{}, K.append_trees([K.placed_at("Photo", U32.sub(pw, K.width(bubble)), 0, bubble)], Bool.pick(List<&2, P.UI>, sending, [], [K.placed_at("Remove", U32.sub(pw, K.width(remove)), 0, remove)])))}}
def conversation(+placeholder: String, +draft: String, history: List<&2, K.Item>, +focus: K.Focus, +status: String, +attachment: Bool, +disabled: Bool, +layers: List<&2, P.UI>, +w: U32, +h: U32) -> P.UI:
  +room = K.thread_room(placeholder, box(w), box_h(h), draft, focus, K.AttachMenu.Closed{})
  +shown = K.newest(history, box(w), U32.sub(room, Bool.pick(U32, String.is_empty(status), 0, 56)))
  +messages = Bool.pick(K.Remote<&2, List<&2, K.Item>>, String.is_empty(status), K.Ready{shown}, K.Failed{Some{shown}})
  +body = disable_send(photo_send(K.conversation_tree(K.conversation(placeholder, box(w), box_h(h), K.Settled{}, K.SettledState{messages, draft, focus, K.AttachMenu.Closed{}})), attachment && String.is_empty(draft)), disabled, attachment)
  +base = P.layout("Near", P.Depth{}, 0, 0, w, h, P.Leading{}, [K.placed_at("Body", margin(), body_y(), body), K.placed_at("Header", margin(), 16, header(w))])
  P.layout("Near", P.Depth{}, 0, 0, w, h, P.Leading{}, K.append_trees([Bool.pick(P.UI, has_layers(layers), inactive(base), base)], layers))

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
def take_u(s: String, +n: U32) -> String:
  match s:
    case SNil{}: ""
    case SCon{+c, t}: Bool.pick(String, U32.is_zero(n), "", SCon{c, take_u(t, U32.sub(n, 1))})
def drop_u(s: String, +n: U32) -> String:
  match s:
    case SNil{}: ""
    case SCon{+c, +t}: Bool.pick(String, U32.is_zero(n), SCon{c, t}, drop_u(t, U32.sub(n, 1)))
def index_go(h: String, +needle: String, +i: U32) -> Maybe<&2, U32>:
  match h:
    case SNil{}: None{}
    case SCon{+c, +t}: Bool.pick(Maybe<&2, U32>, String.starts_with(SCon{c, t}, needle), Some{i}, index_go(t, needle, U32.add(i, 1)))
def found_at(at: Maybe<&2, U32>, +id: U32, +label: String, +text: String, +q: String) -> List<&2, K.Found>:
  match at:
    case None{}: []
    case Some{+p}: [K.Found{id, label, take_u(text, p), take_u(drop_u(text, p), U32.from_nat(String.length(q))), drop_u(text, U32.add(p, U32.from_nat(String.length(q))))}]
def item_found(i: K.Item, +id: U32, +q: String) -> List<&2, K.Found>:
  match i:
    case K.Said{K.Bubble{+tree}}:
      +text = String.trim(text_of(tree))
      Bool.pick(List<&2, K.Found>, String.is_empty(q), [K.Found{id, speaker_of(tree), "", "", text}], found_at(index_go(String.to_lower(text), String.to_lower(q), 0), id, speaker_of(tree), text, q))
    case _: []
def found_go(xs: List<&2, K.Item>, +id: U32, +q: String, acc: List<&2, K.Found>) -> List<&2, K.Found>:
  match xs:
    case []: acc
    case item <> rest: found_go(rest, U32.add(id, 1), q, List.append(&2, K.Found, item_found(item, id, q), acc))
def first_found(xs: List<&2, K.Found>, +n: U32) -> List<&2, K.Found>:
  match xs:
    case []: []
    case +x <> rest: Bool.pick(List<&2, K.Found>, U32.is_zero(n), [], x <> first_found(rest, U32.sub(n, 1)))
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
def recording_view(+elapsed_ms: U32, +phase: String, +error: String, +w: U32, +h: U32) -> P.UI:
  +ready = String.eq(phase, "recorded")
  +recording = String.eq(phase, "recording")
  +copy = Bool.pick(String, ready, "Grabación lista · ", Bool.pick(String, recording, "Grabando · ", Bool.pick(String, String.eq(phase, "uploading"), "Enviando mensaje de voz… ", "Procesando audio… ")))
  dialog("Mensaje de voz", K.append_trees([K.paragraph("Recording status", copy ++ K.clock_text(elapsed_ms), K.body(), K.ink(), U32.sub(dialog_w(w), 32), P.Middle{})],
    K.append_trees(Bool.pick(List<&2, P.UI>, ready, [K.button_tree(K.say(K.ButtonKind.Quiet{}, "Reproducir grabación")), K.button_tree(K.say(K.ButtonKind.Primary{}, "Enviar mensaje de voz"))],
      Bool.pick(List<&2, P.UI>, recording, [K.button_tree(K.say(K.ButtonKind.Primary{}, "Detener grabación"))], [])),
      K.append_trees(Bool.pick(List<&2, P.UI>, ready && Bool.not(String.is_empty(error)), [K.button_tree(K.say(K.ButtonKind.Quiet{}, "Reintentar transcripción"))], []),
      K.append_trees(Bool.pick(List<&2, P.UI>, String.eq(phase, "uploading"), [], [K.button_tree(K.act(K.ButtonKind.Quiet{}, K.Intent.Cancel{}, K.Form.Text{}))]),
        Bool.pick(List<&2, P.UI>, String.is_empty(error), [], [K.paragraph("Error", error, K.small_type(), K.ink(), U32.sub(dialog_w(w), 32), P.Leading{})]))))), w, h)
def call_view(permission: K.Permission, slice: K.CallSlice(permission), +w: U32, +h: U32) -> P.UI:
  +controls = K.call_controls_tree(K.call_controls(permission, slice))
  +pet = Bool.pick(P.UI, U32.is_lt(h, 340), K.identity_compact(identity(N.Idle{})), K.identity_tree(identity(N.Idle{})))
  +body = P.layout("Call body", P.Vertical{}, Bool.pick(U32, U32.is_lt(h, 340), 12, 32), 0, U32.min(w, 320), 0, P.Middle{}, [K.aligned(pet, P.Middle{}), controls])
  P.layout("Near call", P.Depth{}, 0, 0, w, h, P.Leading{}, [K.placed_at("Call", U32.div(U32.sub(w, K.width(body)), 2), U32.max(48, U32.div(U32.sub(h, K.height(body)), 2)), body), K.placed_at("Back", margin(), 16, K.button_tree(K.back_button()))])

type Copy is Data:
  Copy{es: String, en: String}
def copies() -> List<&2, Copy>:
  [Copy{"Foto", "Photo"}, Copy{"Quitar foto", "Remove photo"}, Copy{"Cargando foto…", "Loading photo…"}, Copy{"No se pudo cargar la foto.", "Could not load the photo."}, Copy{"No se pudo cargar", "Could not load"}, Copy{"Reintentar", "Retry"}, Copy{"Enviando…", "Sending…"}, Copy{"Near terminó sin una respuesta de voz.", "Near finished without a spoken reply."}, Copy{"Mensaje", "Message"}, Copy{"Dictar", "Voice message"}, Copy{"Dictate", "Voice message"}, Copy{"Mensaje de voz", "Voice message"}, Copy{"Buscar en la conversación", "Search conversation"}, Copy{"Buscar", "Search"}, Copy{"Recientes", "Recent"}, Copy{"Resultados", "Results"}, Copy{"Sin resultados", "No results"}, Copy{"Aún no hay mensajes", "No messages yet"}, Copy{"Conversación", "Conversation"}, Copy{"Escribir mensaje", "Write message"}, Copy{"Modelo", "Model"}, Copy{"Detener", "Stop"}, Copy{"Tú", "You"}, Copy{"Detener grabación", "Stop recording"}, Copy{"Reproducir grabación", "Play recording"}, Copy{"Enviar mensaje de voz", "Send voice message"}, Copy{"Silenciado", "Muted"}, Copy{"Llamada terminada", "Call ended"}, Copy{"Llamando a Near…", "Calling Near…"}, Copy{"Near necesita tu micrófono para hablar contigo.", "Near needs your microphone to talk with you."}, Copy{"Acepta el permiso del navegador para continuar.", "Allow microphone access on your iPhone to continue."}, Copy{"El micrófono está bloqueado. Actívalo en los ajustes del navegador.", "Microphone access is blocked. Enable it in iPhone Settings."}]
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
def locale_name(+name: String, +lang: K.Lang) -> String:
  Bool.pick(String, String.starts_with(name, "button, disabled · "), "button, disabled · " ++ copy_text(drop_u(name, 19), lang),
  Bool.pick(String, String.starts_with(name, "button · "), "button · " ++ copy_text(drop_u(name, 9), lang),
  Bool.pick(String, String.starts_with(name, "textbox · "), "textbox · " ++ copy_text(drop_u(name, 10), lang),
  Bool.pick(String, String.starts_with(name, "heading · "), "heading · " ++ copy_text(drop_u(name, 10), lang),
  Bool.pick(String, String.starts_with(name, "dialog · "), "dialog · " ++ copy_text(drop_u(name, 9), lang),
  Bool.pick(String, String.starts_with(name, "group · "), "group · " ++ copy_text(drop_u(name, 8), lang),
  Bool.pick(String, String.starts_with(name, "status · "), "status · " ++ copy_text(drop_u(name, 9), lang), name)))))))
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
        case P.Text{+text, text_type}: P.Shape{P.Text{Bool.pick(String, copy, copy_text(text, lang), text), text_type}, fill, stroke, effects}
        case _: P.Shape{geometry, fill, stroke, reference_effects(effects)}
def localized_go(t: P.UI, +lang: K.Lang, +copy: Bool) -> P.UI:
  match t:
    case P.Last{}: P.Last{}
    case P.Leaf{+name, shape, w, h, align, next}: P.Leaf{locale_name(name, lang), localize_shape(shape, lang, copy), w, h, align, localized_go(next, lang, copy)}
    case P.Node{+name, lay, w, h, align, +first, next}:
      +own_copy = Bool.pick(Bool, String.starts_with(name, "button · ") || String.starts_with(name, "button, disabled · "), True{}, Bool.pick(Bool, String.starts_with(name, "listitem · ") || String.eq(name, "Snippet"), False{}, Bool.pick(Bool, String.starts_with(name, "textbox · "), empty_value(first), copy)))
      P.Node{locale_name(name, lang), lay, w, h, align, localized_go(first, lang, own_copy), localized_go(next, lang, copy)}
def localized(t: P.UI, lang: K.Lang) -> P.UI: localized_go(t, lang, True{})
def view(t: P.UI) -> K.UI: K.UI.Drawn{r => localized(t, K.lang_of(r))}
