import ./kit as K

# An input is a function of its own state: the parent gives the placeholder, the runtime the state.
def shown(+placeholder: K.Text, s: K.InputState) -> K.UI:
  match s:
    case K.InputState{text, focus}:
      K.UI.Drawn{r => K.field_tree(K.field(K.plain(K.Lines.Single{}, K.text_in(K.lang_of(r), placeholder), [], K.FieldState{text, focus}), K.column()))}

def input_of(+placeholder: K.Text) -> K.InputState -> K.UI:
  s => shown(placeholder, s)

def input(+placeholder: K.Text) -> K.UI:
  K.UI.Owned{placeholder, input_of(placeholder)}
