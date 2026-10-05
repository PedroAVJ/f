import UI
import ../../f/bend2/std/F/browser/input.bend as Native
import ../../f/bend2/std/F/browser/host.bend as Host
import ../../f/bend2/std/F/browser/scene.bend as Scene
import ../../f/bend2/std/F/ui/kit.bend as K
import ../../f/bend2/std/F/ui/primitives.bend as P
import ../../f/bend2/std/F/ui/tokens.bend as T
import ../../f/bend2/std/F/ai/wire_json.bend as J
import ../mobile.bend as App

def snapshot(status: String) -> String:
  "{\"threads\":[{\"id\":\"thread-1\",\"title\":\"Recuperada\",\"status\":\"" ++ status ++ "\",\"messages\":[{\"role\":\"user\",\"text\":\"Mensaje anterior\"},{\"role\":\"assistant\",\"text\":\"Respuesta real del Mac mini\"}]}],\"selectedThreadId\":\"thread-1\"}"
def reply(status: String) -> Host.Reply: Host.Reply{1, snapshot(status)}
def receipt_reply(id: String) -> Host.Reply:
  Host.Reply{1, "{\"threads\":[{\"id\":\"thread-1\",\"title\":\"Recuperada\",\"status\":\"idle\",\"messages\":[]}],\"selectedThreadId\":\"thread-1\",\"acceptedRequestIds\":[" ++ J.quote(id) ++ "]}"}
def count(xs: List<&2, App.Message>) -> U32:
  match xs:
    case []: 0
    case x <> rest: U32.add(1, count(rest))
def last_text(xs: List<&2, App.Message>) -> String:
  match xs:
    case []: ""
    case App.Message{id, role, text, audio, duration, picture} <> []: text
    case x <> rest: last_text(rest)
def tree(s: App.State) -> P.UI: K.draw(App.f(s), K.Rendering{K.Lang.Es{}, []})
def inside(xs: List<&2, P.Box>, +w: U32, +h: U32) -> Bool:
  match xs:
    case []: True{}
    case P.Box{name, mark, x, y, bw, bh, level, layer} <> rest:
      U32.is_le(U32.add(x, bw), w) && U32.is_le(U32.add(y, bh), h) && inside(rest, w, h)
def fits(+s: App.State, +w: U32, +h: U32) -> Bool:
  U32.is_eq(K.width(tree(s)), w) && U32.is_eq(K.height(tree(s)), h) && inside(K.placed(tree(s)), w, h)
def composer_centered(s: App.State, +w: U32) -> Bool:
  +area = K.find_area(K.placed(tree(s)), "group · Escribir mensaje")
  +center = U32.add(U32.mul(K.area_x(area), 2), K.area_w(area))
  U32.is_gt(K.area_w(area), 0) && U32.is_le(center, w) && U32.is_le(w, U32.add(center, 1))
def repeat(n: Nat) -> String:
  match n:
    case 0n: "TAIL_SENTINEL"
    case 1n+k: "El historial completo debe conservar este texto. " ++ repeat(k)
def receipt_snapshot(thread: App.Thread, id: String) -> App.Snapshot:
  App.Snapshot{[thread], "thread-1", [id], "codex"}
def audio_pending() -> J.Json:
  J.Object{[J.Field{"kind", J.Text{"audio"}}, J.Field{"id", J.Text{"old-boot-audio-clip"}}, J.Field{"thread", J.Text{"thread-1"}}, J.Field{"clipId", J.Text{"clip"}}, J.Field{"durationMs", J.Number{"1200"}}, J.Field{"transcript", J.Text{"Actual voice content"}}]}
def pending_voice_clip(value: App.Voice) -> String:
  match value:
    case App.Voice{phase, clip, duration, transcript}: clip
def main() -> IO(Unit):
  +loaded = App.apply_reply(App.s(), reply("idle"), False{})
  +ready = App.session_prefix(loaded, "browser-unique-id")
  +typed = App.update(ready, Native.Typed{"Mensaje", "  Hola, ¿qué tal?  "})
  +request = App.request_for(typed)
  +prepared = App.prepare(typed, request)
  +failed = App.apply_reply(prepared, Host.Reply{2, "Sin conexión"}, True{})
  +accepted = App.apply_reply(prepared, reply("working"), True{})
  +working = App.update(accepted, Native.Typed{"Mensaje", "Siguiente mensaje"})
  +refreshed = App.apply_reply(failed, reply("idle"), False{})
  +invalid = App.apply_reply(typed, Host.Reply{1, "{\"threads\":[{\"id\":\"thread-1\",\"status\":\"idle\",\"messages\":[{\"role\":\"system\",\"text\":\"No es un mensaje de la conversación\"}]}],\"selectedThreadId\":\"thread-1\"}"}, True{})
  +menu = App.update(typed, Native.Clicked{"Menú"})
  +selected = App.apply_reply(menu, Host.Reply{1, "{\"threads\":[{\"id\":\"thread-2\",\"title\":\"Otra conversación\",\"status\":\"idle\",\"messages\":[{\"role\":\"assistant\",\"text\":\"Otro historial\"}]}],\"selectedThreadId\":\"thread-2\"}"}, False{})
  +history = App.State.with_panel(App.State.with_session(typed, App.Snapshot{[App.Thread{"thread-1", "Larga", "idle", [App.Message{"long", K.Role.Near{}, repeat(80n), "", 0, K.Picture{"", 0, 0, ""}}], "", "", False{}, True{}, "long", repeat(80n)}], "thread-1", [], "codex"}), App.Search{})
  +reload = App.session_prefix(App.apply_reply(App.s(), reply("idle"), False{}), "new-browser-id")
  +cached = App.update(reload, Native.Typed{"Mensaje", "  Hola, ¿qué tal?  "})
  +restored = App.restore_pending(cached, request)
  +receipted = receipt_snapshot(App.current(ready), App.Request.id(request))
  +ack = App.apply_reply(restored, receipt_reply(App.Request.id(request)), False{})
  +later_edit = App.restore_pending(App.update(reload, Native.Typed{"Mensaje", "Edited after the uncertain send"}), request)
  +edited_ack = App.apply_reply(later_edit, receipt_reply(App.Request.id(request)), False{})
  +early_ack = App.restore_pending(App.update(App.adopted(reload, receipted), Native.Typed{"Mensaje", "  Hola, ¿qué tal?  "}), request)
  +older = App.apply_reply(App.State.with_panel(typed, App.Search{}), Host.Reply{1, "{\"threads\":[{\"id\":\"thread-1\",\"title\":\"Recuperada\",\"status\":\"idle\",\"messages\":[{\"role\":\"assistant\",\"text\":\"Older page\"}],\"historyBefore\":\"4\",\"historyHasMore\":true,\"historyIsLatest\":false}],\"selectedThreadId\":\"thread-1\",\"acceptedRequestIds\":[]}"}, False{})
  +html = Scene.html_in(tree(typed), T.Scheme.Dark{})
  +menu_html = Scene.html_in(tree(menu), T.Scheme.Dark{})
  +working_html = Scene.html_in(tree(working), T.Scheme.Dark{})
  +voice = App.with_voice(ready, App.Voice{"recording", "clip", 10, ""})
  +elapsed = App.voice_elapsed(voice, App.voice(voice), 2500)
  +physical_one = App.new_physical(voice, "call")
  +physical_two = App.new_physical(physical_one, "call")
  +audio_restored = App.pending_audio(reload, audio_pending())
  +audio_receipted = App.pending_audio(App.apply_reply(reload, receipt_reply("old-boot-audio-clip"), False{}), audio_pending())
  +audio_cached = App.with_audio_id(audio_restored, "old-boot-audio-clip")
  +text_pending = App.prepare(ready, request)
  +photo_ready = App.with_photo(ready, App.Photo{"selected", "photo-uuid", "file:///tmp/synthetic.jpg", 320, 480, ""})
  +photo_caption = App.update(photo_ready, Native.Typed{"Mensaje", "Original caption"})
  +photo_pending = App.State.with_pending(App.with_photo(photo_caption, App.Photo{"selected", "photo-uuid", "file:///tmp/synthetic.jpg", 320, 480, "image-receipt"}), Some{App.Request{"image-receipt", "thread-1", "Original caption", "image"}})
  +photo_edited = App.update(photo_pending, Native.Typed{"Mensaje", "Newer draft"})
  +photo_retry = App.photo_request(photo_edited, "photo-uuid", "different-receipt", App.State.pending(photo_edited))
  +photo_ack = App.apply_reply(photo_pending, receipt_reply("image-receipt"), False{})
  +photo_edited_ack = App.apply_reply(photo_edited, receipt_reply("image-receipt"), False{})
  +call_pending = App.State.with_pending(typed, Some{App.Request{"call-receipt", "thread-1", String.trim(App.State.draft(typed)), "call"}})
  +call_ack = App.apply_reply(call_pending, receipt_reply("call-receipt"), False{})
  +jump = App.State.with_panel(ready, App.Jumped{0, True{}})
  +photo_html = Scene.html_in(tree(photo_ready), T.Scheme.Dark{})
  +photo_message : App.Message = App.Message{"photo-id", K.Role.Mine{}, "Exact photo caption", "", 0, K.Picture{"/api/image/photo-hash", 320, 480, "Foto"}}
  +photo_tree = K.item_tree(App.message_item(photo_message, 390, [App.ImageFile{"/api/image/photo-hash", "file:///tmp/synthetic.jpg"}]))
  do IO<Unit>:
    IO.print(Bool.show(App.can_send(photo_ready)))
    IO.print(Bool.show(String.contains(photo_html, "button · Enviar")))
    IO.print(Bool.show(fits(App.resized(photo_ready, 320, 568), 320, 568)))
    IO.print(Bool.show(fits(App.resized(photo_ready, 844, 390), 844, 390)))
    IO.print(Bool.show(String.eq(App.Request.text(photo_retry), "Original caption")))
    IO.print(Bool.show(String.eq(App.Request.id(photo_retry), "image-receipt")))
    IO.print(Bool.show(Bool.not(App.has_photo(photo_ack))))
    IO.print(Bool.show(String.is_empty(App.State.draft(photo_ack))))
    IO.print(Bool.show(String.eq(App.State.draft(photo_edited_ack), "Newer draft")))
    IO.print(Bool.show(String.eq(App.State.draft(call_ack), App.State.draft(typed))))
    IO.print(Bool.show(U32.is_gt(K.area_w(K.find_area(K.placed(tree(jump)), "Highlight ring")), 0)))
    IO.print(Bool.show(String.contains(Scene.html_in(tree(failed), T.Scheme.Dark{}), "button · Reintentar carga")))
    IO.print(Bool.show(String.contains(Scene.html_in(photo_tree, T.Scheme.Dark{}), "Exact photo caption")))
    IO.print(Bool.show(String.eq(App.voice_phase(elapsed), "recording")))
    IO.print(Bool.show(U32.is_eq(App.voice_duration(elapsed), 2500)))
    IO.print(Bool.show(String.eq(pending_voice_clip(App.voice(elapsed)), "clip")))
    IO.print(Bool.show(Bool.not(String.eq(App.physical(physical_one), App.physical(physical_two)))))
    IO.print(Bool.show(String.eq(App.State.prefix(physical_one), App.State.prefix(physical_two))))
    IO.print(Bool.show(String.is_empty(App.State.draft(audio_restored))))
    IO.print(Bool.show(String.eq(App.voice_phase(audio_restored), "recorded")))
    IO.print(Bool.show(String.eq(App.audio_id(audio_restored), "old-boot-audio-clip")))
    IO.print(Bool.show(String.eq(App.audio_request_id(audio_cached, "clip", App.State.pending(audio_cached)), "old-boot-audio-clip")))
    IO.print(Bool.show(Bool.not(String.eq(App.audio_request_id(text_pending, "newclip", App.State.pending(text_pending)), App.Request.id(request)))))
    IO.print(Bool.show(Bool.not(App.has_pending(App.State.pending(audio_receipted)))))
    IO.print(Bool.show(App.is_closed(App.State.panel(audio_receipted))))
    IO.print(Bool.show(String.eq(App.voice_phase(App.voice_retry_state(ready, App.Voice{"uploading", "clip", 1200, ""})), "recorded")))
    IO.print(Bool.show(Bool.not(App.can_send(loaded))))
    IO.print(Bool.show(App.can_send(typed)))
    IO.print(Bool.show(String.eq(App.Request.text(request), "Hola, ¿qué tal?")))
    IO.print(Bool.show(String.eq(App.State.draft(failed), App.State.draft(typed))))
    IO.print(Bool.show(String.eq(App.Request.id(App.request_for(failed)), App.Request.id(request))))
    IO.print(Bool.show(Bool.not(String.eq(App.Request.id(App.request_for(App.update(failed, Native.Typed{"Mensaje", "Otro texto"}))), App.Request.id(request)))))
    IO.print(Bool.show(String.is_empty(App.State.draft(accepted))))
    IO.print(Bool.show(Bool.not(App.can_send(working))))
    IO.print(Bool.show(String.contains(working_html, "disabled")))
    IO.print(Bool.show(String.eq(App.State.draft(refreshed), App.State.draft(typed))))
    IO.print(Bool.show(App.State.online(refreshed)))
    IO.print(Bool.show(String.eq(last_text(App.Thread.messages(App.current(refreshed))), "Respuesta real del Mac mini")))
    IO.print(Bool.show(U32.is_eq(count(App.Thread.messages(App.current(invalid))), 2)))
    IO.print(Bool.show(String.eq(App.State.draft(invalid), App.State.draft(typed))))
    IO.print(Bool.show(String.eq(App.State.draft(App.update(menu, Native.Typed{"Mensaje", "Hidden input"})), App.State.draft(typed))))
    IO.print(Bool.show(Bool.not(String.contains(menu_html, "data-bend-field=\"textbox · Mensaje\""))))
    IO.print(Bool.show(Bool.not(String.contains(menu_html, "button · thread:")) && Bool.not(String.contains(menu_html, "Nueva conversación")) && String.contains(menu_html, "Buscar") && Bool.not(String.contains(menu_html, "Modelo"))))
    IO.print(Bool.show(String.eq(App.State.draft(selected), App.State.draft(typed))))
    IO.print(Bool.show(String.eq(last_text(App.Thread.messages(App.current(selected))), "Otro historial")))
    IO.print(Bool.show(String.contains(Scene.html_in(tree(history), T.Scheme.Dark{}), "Buscar en la conversación")))
    IO.print(Bool.show(String.contains(html, "Hola, ¿qué tal?")))
    IO.print(Bool.show(fits(App.resized(typed, 320, 568), 320, 568)))
    IO.print(Bool.show(fits(App.resized(typed, 390, 844), 390, 844)))
    IO.print(Bool.show(fits(App.resized(typed, 844, 390), 844, 390)))
    IO.print(Bool.show(fits(App.resized(typed, 390, 500), 390, 500)))
    IO.print(Bool.show(composer_centered(App.resized(typed, 844, 390), 844)))
    IO.print(Bool.show(String.eq(App.Request.id(App.request_for(restored)), App.Request.id(request))))
    IO.print(Bool.show(String.is_empty(App.State.draft(ack))))
    IO.print(Bool.show(String.eq(App.State.draft(edited_ack), "Edited after the uncertain send")))
    IO.print(Bool.show(String.is_empty(App.State.draft(early_ack))))
    IO.print(Bool.show(String.eq(App.State.draft(older), App.State.draft(typed))))
    IO.print(Bool.show(fits(App.resized(older, 320, 568), 320, 568)))
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
