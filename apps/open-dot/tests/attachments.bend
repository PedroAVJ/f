import UI
import ../../../bend2/std/F/browser/input.bend as Native
import ../../../bend2/std/F/browser/host.bend as Host
import ../../../bend2/std/F/browser/scene.bend as Scene
import ../../../bend2/std/F/ui/kit.bend as K
import ../../../bend2/std/F/ui/primitives.bend as P
import ../../../bend2/std/F/ui/tokens.bend as T
import ../../../bend2/std/F/ai/wire_json.bend as J
import ../mobile.bend as App

def tree(state: App.State) -> P.UI: K.draw(App.f(state), K.Rendering{K.Lang.Es{}, []})
def html(state: App.State) -> String: Scene.html_in(tree(state), T.Scheme.Dark{})
def four_pieces(+state: App.State, +w: U32, +h: U32) -> Bool:
  +boxes = K.placed(tree(App.resized(state, w, h)))
  +plus = K.find_area(boxes, "button · Adjuntar")
  +field = K.find_area(boxes, "textbox · Mensaje")
  +camera = K.find_area(boxes, "button · Cámara")
  +send = K.find_area(boxes, "button · Enviar")
  U32.is_eq(K.area_w(plus), 44) && U32.is_eq(K.area_w(camera), 44) && U32.is_eq(K.area_w(send), 44) &&
  U32.is_eq(K.area_x(field), U32.add(K.area_x(plus), 52)) &&
  U32.is_eq(K.area_x(camera), U32.add(U32.add(K.area_x(field), K.area_w(field)), 8)) &&
  U32.is_eq(K.area_x(send), U32.add(K.area_x(camera), 52)) &&
  U32.is_le(U32.add(K.area_x(send), K.area_w(send)), w) &&
  U32.is_le(U32.add(K.area_y(field), K.area_h(field)), h)
def selected_file(session: String) -> J.Json:
  J.Object{[J.Field{"phase", J.Text{"selected"}}, J.Field{"session", J.Text{session}}, J.Field{"fileId", J.Text{"selected-file"}}, J.Field{"name", J.Text{"Invoice.pdf"}}, J.Field{"mimeType", J.Text{"application/pdf"}}, J.Field{"size", J.Number{"1024"}}]}
def main() -> IO(Unit):
  +loaded = App.session_prefix(App.apply_reply(App.s(), Host.Reply{1, "{\"provider\":\"claude\",\"threads\":[{\"id\":\"one\",\"status\":\"idle\",\"messages\":[{\"id\":\"first\",\"role\":\"assistant\",\"text\":\"Ready\"}],\"historyHasMore\":true}],\"selectedThreadId\":\"one\"}"}, False{}), "test-session")
  +typed = App.update(loaded, Native.Typed{"Mensaje", "My unchanged caption"})
  +chooser = App.update(typed, Native.Clicked{"Adjuntar"})
  +bakery = App.State.with_session(chooser, App.Snapshot{[], "", [], "bakery"})
  +selected = App.file_event_value(typed, selected_file("test-session"))
  +request = App.document_request(selected, "file-receipt", None{})
  +pending = App.State.with_pending(App.with_document(selected, App.Document{"selected", App.DocumentFile{"selected-file", "", "Invoice.pdf", "application/pdf", 1024}, "file-receipt"}), Some{request})
  +edited = App.State.with_draft(pending, "A newer unsent caption")
  +retry = App.document_request(edited, "different-id", App.State.pending(edited))
  +ack = App.apply_reply(edited, Host.Reply{1, "{\"threads\":[{\"id\":\"one\",\"status\":\"idle\",\"messages\":[]}],\"selectedThreadId\":\"one\",\"acceptedRequestIds\":[\"file-receipt\"]}"}, False{})
  +working = App.apply_reply(typed, Host.Reply{1, "{\"threads\":[{\"id\":\"one\",\"status\":\"working\",\"messages\":[]}],\"selectedThreadId\":\"one\"}"}, False{})
  +file_history = App.apply_reply(typed, Host.Reply{1, "{\"threads\":[{\"id\":\"one\",\"status\":\"idle\",\"messages\":[{\"id\":\"file-message\",\"role\":\"user\",\"text\":\"Read this\",\"file\":{\"id\":\"hash\",\"url\":\"/api/file/hash\",\"name\":\"Invoice.pdf\",\"mimeType\":\"application/pdf\",\"size\":1024}}]}],\"selectedThreadId\":\"one\"}"}, False{})
  +english_file = Scene.html_in(K.draw(App.f(selected), K.Rendering{K.Lang.En{}, []}), T.Scheme.Dark{})
  +shown = html(typed)
  +choices = html(chooser)
  do IO<Unit>:
    IO.print(Bool.show(Bool.not(String.contains(shown, "banner · Near")) && Bool.not(String.contains(shown, "Menú")) && Bool.not(String.contains(shown, "Llamar a Near"))))
    IO.print(Bool.show(U32.is_eq(K.area_y(K.find_area(K.placed(tree(typed)), "Scroll viewport · Conversation")), 16)))
    IO.print(Bool.show(four_pieces(typed, 320, 568)))
    IO.print(Bool.show(four_pieces(typed, 390, 844)))
    IO.print(Bool.show(four_pieces(typed, 844, 390)))
    IO.print(Bool.show(four_pieces(typed, 390, 240)))
    IO.print(Bool.show(String.contains(shown, "button · Enviar") && Bool.not(String.contains(shown, "button · Mensaje de voz"))))
    IO.print(Bool.show(String.contains(html(loaded), "button · Mensaje de voz") && Bool.not(String.contains(html(loaded), "button · Enviar"))))
    IO.print(Bool.show(App.is_attachments(App.State.panel(chooser)) && String.eq(App.State.draft(chooser), "My unchanged caption")))
    IO.print(Bool.show(String.contains(choices, "Fotos") && String.contains(choices, "Archivos") && String.contains(choices, "Cámara") && Bool.not(String.contains(choices, "Buscar"))))
    IO.print(Bool.show(Bool.not(String.contains(html(bakery), "Archivos")) && String.contains(html(bakery), "Fotos")))
    IO.print(Bool.show(String.contains(html(working), "button · Detener") && String.contains(html(working), "button · Enviar") && Bool.not(String.contains(html(working), "button · Cámara"))))
    IO.print(Bool.show(App.document_ready(selected) && App.can_send(selected) && Bool.not(App.can_record(selected)) && Bool.not(App.can_pick(selected))))
    IO.print(Bool.show(String.contains(html(selected), "Invoice.pdf") && String.contains(html(selected), "Quitar archivo")))
    IO.print(Bool.show(String.eq(App.Request.id(retry), "file-receipt") && String.eq(App.Request.text(retry), "My unchanged caption")))
    IO.print(Bool.show(Bool.not(App.has_document(ack)) && Bool.not(App.has_pending(App.State.pending(ack))) && String.eq(App.State.draft(ack), "A newer unsent caption")))
    IO.print(Bool.show(Bool.not(App.has_document(App.file_event_value(typed, selected_file("old-session"))))))
    IO.print(Bool.show(String.contains(html(file_history), "Invoice.pdf") && String.contains(html(file_history), "file:hash") && String.contains(html(file_history), "Read this")))
    IO.print(Bool.show(String.contains(shown, "Mensajes anteriores")))
    IO.print(Bool.show(String.contains(english_file, "Remove file") && Bool.not(String.contains(english_file, "Quitar archivo"))))
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
