import Base
import ../ui/kit.bend as K
import ../ui/primitives.bend as P
import ../ai/wire_json.bend as J

# Metadata wraps, but does not replace, the tree painted by human targets.
def annotated(meta: J.Json, child: K.UI) -> K.UI:
  K.UI.Drawn{r => P.layout("hypertui:" ++ J.stringify(meta), P.Vertical{}, 0, 0, 0, 0, P.Leading{}, [K.draw(child, r)])}

def query(+label: K.Text, uri: String) -> K.UI:
  K.UI.Drawn{+r => K.draw(annotated(J.Object{[J.Field{"kind", J.Text{"query"}}, J.Field{"label", J.Text{K.text_in(K.lang_of(r), label)}}, J.Field{"uri", J.Text{uri}}]}, K.action(label)), r)}

def mutation(name: String, +label: K.Text, schema: J.Json, +enabled: Bool) -> K.UI:
  K.UI.Drawn{+r => K.draw(annotated(J.Object{[J.Field{"kind", J.Text{"action"}}, J.Field{"name", J.Text{name}}, J.Field{"label", J.Text{K.text_in(K.lang_of(r), label)}}, J.Field{"inputSchema", schema}, J.Field{"enabled", J.Boolean{enabled}}]}, K.action_as(K.ButtonKind.Primary{}, label, enabled)), r)}

def code(language: String, +source: String) -> K.UI:
  annotated(J.Object{[J.Field{"kind", J.Text{"code"}}, J.Field{"language", J.Text{language}}, J.Field{"source", J.Text{source}}]}, K.caption(K.Text{source, source}))

def image(+label: String, asset: String, +width: U32, +height: U32) -> K.UI:
  K.tree(P.leaf(K.named(K.A11yRole.Img{}, label), P.Shape{P.Rounded{width, height, P.Corner{0}}, P.Image{P.Bitmap.Photo{asset, width, height}, 0}, P.NoStroke{}, []}, width, height, P.Leading{}))

type Link is Data:
  Link{label: K.Text, uri: String}
def links(xs: List<&2, Link>) -> List<K.UI>:
  match xs:
    case []: []
    case Link{label, uri} <> rest: query(label, uri) <> links(rest)

# The app supplies the selected frame/page and its navigation URIs.
def video(title: K.Text, metadata: K.Text, frame: String, width: U32, height: U32, navigation: List<&2, Link>) -> K.UI:
  K.screen(K.app_title(title) <> image("Current frame", frame, width, height) <> K.caption(metadata) <> links(navigation))
def audio(title: K.Text, transcript: K.Text, waveform: String, width: U32, height: U32, navigation: List<&2, Link>) -> K.UI:
  K.screen(K.app_title(title) <> K.caption(transcript) <> image("Waveform", waveform, width, height) <> links(navigation))
def pdf(title: K.Text, page: String, width: U32, height: U32, navigation: List<&2, Link>) -> K.UI:
  K.screen(K.app_title(title) <> image("PDF page", page, width, height) <> links(navigation))

def draw(ui: K.UI) -> P.UI:
  K.draw(ui, K.Rendering{K.Lang.En{}, []})
