import Base
import ../ui/kit.bend as K
import ../ui/primitives.bend as P
import ../browser/scene.bend as Scene
import ./ui.bend as H
import ./tree.bend as R
import ../ai/wire_json.bend as J

def get(value: J.Json, name: String) -> String: J.text(J.get(value, name))
def get_json(value: J.Json, name: String) -> J.Json: Maybe.default(&2, J.Json, J.get(value, name), J.Null{})
def label(+text: String) -> K.Text: K.Text{text, text}
def block_kind(kind: String, +value: J.Json) -> K.UI:
  match kind:
    case "action": H.mutation(get(value, "name"), label(get(value, "label")), get_json(value, "inputSchema"), True{})
    case "link": H.query(label(get(value, "label")), get(value, "uri"))
    case "image": H.image(get(value, "label"), get(value, "asset"), 512, 320)
    case "code": H.code(get(value, "language"), get(value, "text"))
    case _: K.caption(label(get(value, "text")))
def block(+value: J.Json) -> K.UI: block_kind(get(value, "kind"), value)
def blocks(xs: List<&2, J.Json>) -> List<K.UI>:
  match xs:
    case []: []
    case value <> rest: block(value) <> blocks(rest)
def body(value: Maybe<&2, J.Json>) -> List<K.UI>:
  match value:
    case Some{J.Array{xs}}: blocks(xs)
    case _: []
def f(+model: J.Json) -> K.UI:
  K.screen(K.app_title(label(get(model, "title"))) <> body(J.get(model, "blocks")))
def tree(model: J.Json) -> R.UI(): H.render_tree(f(model))
def human_html(model: J.Json) -> String: Scene.html(H.draw(f(model)))
