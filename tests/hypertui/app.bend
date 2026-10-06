import Base
import ../../bend2/std/F/browser/scene.bend as Scene
import ../../bend2/std/F/ui/kit.bend as K
import ../../bend2/std/F/hypertui/ui.bend as H
import ../../bend2/std/F/ui/primitives.bend as P
import ../../bend2/std/F/ai/wire_json.bend as J

type State is Data:
  State{count: U32}
type Transition is Data:
  Transition{state: State, redirect: String}
def s() -> State: State{0}
def schema() -> J.Json:
  J.Object{[J.Field{"type", J.Text{"object"}}, J.Field{"properties", J.Object{[J.Field{"amount", J.Object{[J.Field{"type", J.Text{"integer"}}, J.Field{"minimum", J.Number{"1"}}, J.Field{"maximum", J.Number{"5"}}]}}]}}, J.Field{"required", J.Array{[J.Text{"amount"}]}}, J.Field{"additionalProperties", J.Boolean{False{}}}]}
def f(state: State) -> K.UI:
  match state:
    case State{+count}:
      K.screen([K.app_title(K.Text{"Shared F screen", "Pantalla F"}), K.caption(K.Text{"Before image", "Antes"}), H.image("Visual challenge", "challenge.png", 512, 320), K.caption(K.Text{"After image", "Después"}), K.caption(K.Text{U32.show(count), U32.show(count)}), H.query(K.Text{"Code", "Código"}, "hypertui://demo/code"), H.mutation("increment", K.Text{"Increment", "Incrementar"}, schema(), True{})])
def hypertui_page(state: State, +uri: String) -> P.UI:
  H.draw(Bool.pick(K.UI, String.eq(uri, "hypertui://demo/code"), K.screen([H.code("bend", "def answer() -> U32: 42"), H.query(K.Text{"Home", "Inicio"}, "hypertui://demo/")]), f(state)))
def amount(value: Maybe<&2, J.Json>) -> U32:
  match value:
    case Some{J.Number{s}}: Maybe.default(&2, U32, U32.read(s), 0)
    case _: 0
def hypertui_action(state: State, page: String, name: String, args: J.Json) -> Transition:
  match state:
    case State{count}: Transition{State{U32.add(count, amount(J.get(args, "amount")))}, "hypertui://demo/"}

def human_html(state: State) -> String:
  Scene.html(H.draw(f(state)))
