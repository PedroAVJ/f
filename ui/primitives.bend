import Base
import ./symbols.bend as S
import ./nearling.bend as N
import ./tokens.bend as T

# Near UI primitives. There are exactly two:
#   Shape  draws something. It is a dependent type: its `geometry` case decides
#          the extra fields (Text, Path, Rounded); fill, stroke and effects
#          are shared and defined once on Shape.
#   Layout arranges children along one axis: Horizontal, Vertical or Depth.
# Depth is paint order in 2D (later children paint over earlier ones), not 3D.
# Vocabulary: primitive (Shape, Layout) -> case (e.g. Text, Horizontal) ->
# instance (a concrete value, e.g. the send icon = a Shape with Path geometry).
# A bitmap is not a primitive or a geometry: it is an Image fill.
# Tokens are not a layer: they are the allowed values of fields (text types
# for Text, colour roles for every colour field). The allowed roles depend on
# the field: the fill of a Text is a TextRole, the fill of a Rounded or Path a
# SurfaceRole, a stroke a LineRole (Shape's fill type depends on its geometry
# case). Grey-on-grey text or a bubble filled with a text role cannot be
# written. States are rules applied to a role (Rest, Pressed, Disabled). The
# concrete colour comes from tokens.bend for the Scheme case; no colour value
# lives here.
# All geometry (sizes, gaps, alignment, positions, layers) is computed here;
# the browser only paints the resulting boxes.

# Shape
# -----

# A text type: one allowed value of Text.text_type.
type TextType is Data:
  TextType{name: String, size: U32, weight: U32}
# Corner radius of a Rounded geometry: a length from 0 (square corners)
# upwards, or Full (half the shorter side: a pill, a circle when square).
type Radius is Data:
  Corner{length: U32}
  Full{}
type Geometry is Data:
  # `type` is a Bend keyword, so the type field is named `text_type`.
  Text{string: String, text_type: TextType}
  # A fixed drawing: one of the approved symbols from symbols.bend.
  Path{drawing: S.Drawing}
  # A rectangle with rounded corners. Its size is its own data, written by
  # whoever builds the instance; it never reads the layout.
  Rounded{width: U32, height: U32, radius: Radius}
# The fill of a Text: a text role in a state.
type TextFill is Data:
  TextFill.Solid{color: T.TextRole, state: T.State}
# The fill of a Rounded or Path.
type Fill is Data:
  # Nothing inside the geometry: only the stroke draws (line-art symbols).
  Fill.None{}
  Solid{color: T.SurfaceRole, state: T.State}
  # `from` is held until `hold` percent, then eases to `to`, top to bottom.
  Gradient{from: T.Stop, to: T.Stop, hold: U32}
  # The bitmap is the atlas frame sampled at `time` (ms), which changes with
  # time, or a photo.
  Image{bitmap: Bitmap, time: U32}
# A bitmap: a caller-supplied sprite atlas frame, or a photo (an asset shown
# cover-cropped to the shape's box).
type Bitmap is Data:
  Bitmap.Atlas{frame: N.Frame}
  Bitmap.Photo{asset: String, width: U32, height: U32}
# Widths are strings because the approved symbols use fractional widths.
type Stroke is Data:
  NoStroke{}
  Stroke{color: T.LineRole, state: T.State, width: String}
type Effect is Data:
  Blur{radius: U32}
  # The colour is the one fixed Shadow token.
  Shadow{y: U32, blur: U32}
  # Liquid Glass: the backdrop blurred (radius, px) and saturated (%),
  # refracted at the rim (strength, px, where the renderer can), a specular
  # highlight along the top edge (% white) and the shape's Solid fill as the
  # tint (% opacity), with an edge tint (a line role) as the rim light.
  # `over` is what it sits on (tokens.Backdrop), which decides the roles
  # allowed on it. The values come from the tokens (glass(), below).
  Glass{blur: U32, saturation: U32, refraction: U32, highlight: U32, tint: U32, edge: T.LineRole, over: T.Backdrop}
# Which fills a geometry case allows.
def FillOf(geometry: Geometry) -> Data:
  match geometry:
    case Text{string, text_type}: TextFill
    case Path{drawing}: Fill
    case Rounded{width, height, radius}: Fill
type Shape is Data:
  Shape{geometry: Geometry, fill: FillOf(geometry), stroke: Stroke, effects: List<&2, Effect>}

# Layout
# ------

type Axis is Data:
  Horizontal{}
  Vertical{}
  Depth{}
type Layout is Data:
  Layout{axis: Axis, gap: U32, pad: U32}
type Align is Data:
  Leading{}
  Middle{}
  Trailing{}

# A specimen tree of Shape and Layout instances in first-child / next-sibling
# form, so one structural recursion walks both children and siblings.
# Width or height 0 means "hug children".
type UI is Data:
  Last{}
  Leaf{name: String, shape: Shape, width: U32, height: U32, align: Align, next: UI}
  Node{name: String, layout: Layout, width: U32, height: U32, align: Align, first: UI, next: UI}

type Size is Data:
  Size{width: U32, height: U32, count: U32}

# Output geometry. Draw boxes are painted in list order (that order is Depth).
# Outline and Spacing boxes are the layout overlay, from the same placement.
type Mark is Data:
  Draw{shape: Shape}
  Outline{axis: Axis}
  Spacing{axis: Axis}
type Box is Data:
  Box{name: String, mark: Mark, x: U32, y: U32, width: U32, height: U32, level: U32, layer: U32}
# One sheet of the exploded Depth view: centre point, size of the layer and
# the percent scale of the tilted sheet.
type Layer is Data:
  Layer{index: U32, name: String, cx: U32, cy: U32, width: U32, height: U32, scale: U32}
type Explode is Data:
  Flat{}
  Exploded{cx: U32, cy: U32, dy: U32, scale: U32}

# A live stage on the canvas. Motion: stage nodes "Stage:<key>:live|reduced"
# (or ":<percent>" / ":r<percent>" for static samples) and a "Controls:<key>"
# node; the browser drives the clock and asks Bend for the frame at `now`.
# Resize: a "Resize:<key>" node whose box width the user drags between min
# and max; the browser asks Bend for the component in that box.
type Player is Data:
  Player{key: String, label: String, kind: String, duration: U32, loop: Bool, min: U32, max: U32, start: U32, width: U32, height: U32}
# `section` is the canvas section (case group) the frame belongs to. `slice`
# is an optional second note under the caption (a component's state slice).
# `panels`: when not empty, the frame shows one panel per entry, side by side
# (each panel_width + 20 to the right of the previous), each painted with its
# own boxes in its own Scheme; Shape frames show Dark and Light. When empty,
# one panel shows `boxes` in the toolbar's scheme. `focus` lists the
# focusable boxes in focus order, as indices into the non-Spacing boxes.
type Panel is Data:
  Panel{scheme: T.Scheme, boxes: List<&2, Box>}
type Specimen is Data:
  Specimen{id: String, section: String, label: String, kicker: String, title: String, caption: String, slice: String, sizes: String, x: U32, y: U32, width: U32, height: U32, wide: U32, panel_x: U32, panel_y: U32, panel_width: U32, panel_height: U32, panels: List<&2, Panel>, boxes: List<&2, Box>, layers: List<&2, Layer>, focus: List<&2, U32>, players: List<&2, Player>}

# Authoring helpers
# -----------------

def link(t: UI, rest: UI) -> UI:
  match t:
    case Last{}: rest
    case Leaf{name, shape, width, height, align, next}: Leaf{name, shape, width, height, align, rest}
    case Node{name, layout, width, height, align, first, next}: Node{name, layout, width, height, align, first, rest}
def append_trees(xs: List<&2, UI>, ys: List<&2, UI>) -> List<&2, UI>:
  match xs:
    case Nil{}: ys
    case Con{x, rest}: Con{x, append_trees(rest, ys)}
def chain(xs: List<&2, UI>) -> UI:
  match xs:
    case Nil{}: Last{}
    case Con{head, tail}: link(head, chain(tail))
def leaf(name: String, shape: Shape, width: U32, height: U32, align: Align) -> UI:
  Leaf{name, shape, width, height, align, Last{}}
def layout(name: String, axis: Axis, gap: U32, pad: U32, width: U32, height: U32, align: Align, children: List<&2, UI>) -> UI:
  Node{name, Layout{axis, gap, pad}, width, height, align, chain(children), Last{}}

# Measurement
# -----------

def combine(axis: Axis, +spacing: U32, +aw: U32, +ah: U32, +bw: U32, +bh: U32, count: U32) -> Size:
  match axis:
    case Horizontal{}: Size{U32.add(aw, U32.add(spacing, bw)), U32.max(ah, bh), count}
    case Vertical{}: Size{U32.max(aw, bw), U32.add(ah, U32.add(spacing, bh)), count}
    case Depth{}: Size{U32.max(aw, bw), U32.max(ah, bh), count}
def join(axis: Axis, +gap: U32, a: Size, b: Size) -> Size:
  match a b:
    case Size{aw, ah, ac} Size{bw, bh, +bc}:
      combine(axis, Bool.pick(U32, U32.is_zero(bc), 0, gap), aw, ah, bw, bh, U32.add(ac, bc))
def own(+width: U32, +height: U32, +pad: U32, inner: Size) -> Size:
  match inner:
    case Size{iw, ih, count}:
      Size{Bool.pick(U32, U32.is_zero(width), U32.add(iw, U32.add(pad, pad)), width), Bool.pick(U32, U32.is_zero(height), U32.add(ih, U32.add(pad, pad)), height), 1}
# Size of a sibling chain laid along `axis` with `gap` between items.
def measure(t: UI, +axis: Axis, +gap: U32) -> Size:
  match t:
    case Last{}: Size{0, 0, 0}
    case Leaf{name, shape, width, height, align, next}:
      join(axis, gap, Size{width, height, 1}, measure(next, axis, gap))
    case Node{name, Layout{inner, +inner_gap, pad}, width, height, align, first, next}:
      join(axis, gap, own(width, height, pad, measure(first, inner, inner_gap)), measure(next, axis, gap))
def width_of(s: Size) -> U32:
  match s:
    case Size{width, height, count}: width
def height_of(s: Size) -> U32:
  match s:
    case Size{width, height, count}: height
def count_of(s: Size) -> U32:
  match s:
    case Size{width, height, count}: count
def size(t: UI) -> Size:
  measure(link(t, Last{}), Depth{}, 0)

# Placement
# ---------

def is_last(t: UI) -> Bool:
  match t:
    case Last{}: True{}
    case _: False{}
def free(align: Align, +room: U32) -> U32:
  match align:
    case Leading{}: 0
    case Middle{}: U32.div(room, 2)
    case Trailing{}: room
def offset(align: Align, +room: U32, +size: U32) -> U32:
  Bool.pick(U32, U32.is_lt(room, size), 0, free(align, U32.sub(room, size)))
def cross_x(axis: Axis, align: Align, +x: U32, +room: U32, +width: U32) -> U32:
  match axis:
    case Horizontal{}: x
    case _: U32.add(x, offset(align, room, width))
def cross_y(axis: Axis, align: Align, +y: U32, +room: U32, +height: U32) -> U32:
  match axis:
    case Vertical{}: y
    case _: U32.add(y, offset(align, room, height))
def advance_x(axis: Axis, +x: U32, +width: U32, +gap: U32) -> U32:
  match axis:
    case Horizontal{}: U32.add(x, U32.add(width, gap))
    case _: x
def advance_y(axis: Axis, +y: U32, +height: U32, +gap: U32) -> U32:
  match axis:
    case Vertical{}: U32.add(y, U32.add(height, gap))
    case _: y
def layer_of(+level: U32, +index: U32, +layer: U32) -> U32:
  Bool.pick(U32, U32.is_eq(level, 1), index, layer)
def gap_box(axis: Axis, +gap: U32, +x: U32, +y: U32, +width: U32, +height: U32, +room_w: U32, +room_h: U32, +level: U32, +layer: U32) -> List<&2, Box>:
  match axis:
    case Horizontal{}: [Box{"Gap", Spacing{Horizontal{}}, U32.add(x, width), y, gap, room_h, level, layer}]
    case Vertical{}: [Box{"Gap", Spacing{Vertical{}}, x, U32.add(y, height), room_w, gap, level, layer}]
    case Depth{}: []
def spacing(axis: Axis, more: Bool, +gap: U32, +x: U32, +y: U32, +width: U32, +height: U32, +room_w: U32, +room_h: U32, +level: U32, +layer: U32) -> List<&2, Box>:
  Bool.pick(List<&2, Box>, Bool.and(more, Bool.not(U32.is_zero(gap))), gap_box(axis, gap, x, y, width, height, room_w, room_h, level, layer), [])
def concat(xs: List<&2, Box>, ys: List<&2, Box>) -> List<&2, Box>:
  match xs:
    case Nil{}: ys
    case Con{head, tail}: Con{head, concat(tail, ys)}

# Places a sibling chain whose parent content box starts at (x, y) and is
# room_w x room_h. The cursor moves along `axis`; Depth keeps it in place.
def place(t: UI, +axis: Axis, +gap: U32, +x: U32, +y: U32, +room_w: U32, +room_h: U32, +level: U32, +layer: U32, +index: U32) -> List<&2, Box>:
  match t:
    case Last{}: []
    case Leaf{name, shape, +width, +height, +align, +next}:
      Con{Box{name, Draw{shape}, cross_x(axis, align, x, room_w, width), cross_y(axis, align, y, room_h, height), width, height, level, layer_of(level, index, layer)},
        concat(spacing(axis, Bool.not(is_last(next)), gap, x, y, width, height, room_w, room_h, level, layer),
          place(next, axis, gap, advance_x(axis, x, width, gap), advance_y(axis, y, height, gap), room_w, room_h, level, layer, U32.add(index, 1)))}
    case Node{name, Layout{+inner, +inner_gap, +pad}, +width, +height, +align, +first, +next}:
      +s = own(width, height, pad, measure(first, inner, inner_gap))
      +w = width_of(s)
      +h = height_of(s)
      +px = cross_x(axis, align, x, room_w, w)
      +py = cross_y(axis, align, y, room_h, h)
      +own_layer = layer_of(level, index, layer)
      Con{Box{name, Outline{inner}, px, py, w, h, level, own_layer},
        concat(place(first, inner, inner_gap, U32.add(px, pad), U32.add(py, pad), U32.sub(w, U32.add(pad, pad)), U32.sub(h, U32.add(pad, pad)), U32.add(level, 1), own_layer, 0),
          concat(spacing(axis, Bool.not(is_last(next)), gap, x, y, w, h, room_w, room_h, level, layer),
            place(next, axis, gap, advance_x(axis, x, w, gap), advance_y(axis, y, h, gap), room_w, room_h, level, layer, U32.add(index, 1))))}

# Exploded Depth view: one sheet per child of the root Depth layout, top layer
# highest. Sheets share the root's size; centres step down by `dy` per layer.
def sheets(t: UI, +index: U32, +count: U32, +cx: U32, +cy: U32, +dy: U32, +width: U32, +height: U32, +scale: U32) -> List<&2, Layer>:
  match t:
    case Last{}: []
    case Leaf{name, shape, w, h, align, next}:
      Con{Layer{index, name, cx, U32.add(cy, U32.mul(U32.sub(U32.sub(count, 1), index), dy)), width, height, scale}, sheets(next, U32.add(index, 1), count, cx, cy, dy, width, height, scale)}
    case Node{name, lay, w, h, align, first, next}:
      Con{Layer{index, name, cx, U32.add(cy, U32.mul(U32.sub(U32.sub(count, 1), index), dy)), width, height, scale}, sheets(next, U32.add(index, 1), count, cx, cy, dy, width, height, scale)}
def layers(root: UI, explode: Explode) -> List<&2, Layer>:
  match root explode:
    case Node{name, lay, +width, +height, align, +first, next} Exploded{cx, cy, dy, scale}:
      sheets(first, 0, count_of(measure(first, Depth{}, 0)), cx, cy, dy, width, height, scale)
    case _ _: []

# Focus order
# -----------

# Interactive regions take focus in reading order, derived from Layout:
# Vertical top to bottom, Horizontal leading to trailing, Depth top layer
# first (the last child paints on top, so it is read first). A node may
# declare an override; the only one is the kit Header, which reads its Depth
# layers leading to trailing (left, center, right). Indices are pre-order
# positions of nodes and leaves: the order `place` emits non-Spacing boxes.
# Interactive: nodes named with the button or textbox role ("button · Enviar";
# a disabled button is "button, disabled · ..." and takes no focus), and the
# shape arrangements of the Primitives page ("Search button", "Field text").
def interactive(+name: String) -> Bool:
  Bool.or(Bool.or(String.starts_with(name, "button · "), String.starts_with(name, "textbox · ")), Bool.or(String.ends_with(name, " button"), String.eq(name, "Field text")))
def declares_order(+name: String) -> Bool:
  Bool.or(String.eq(name, "Header"), String.starts_with(name, "banner · "))
def chain_count(t: UI) -> U32:
  match t:
    case Last{}: 0
    case Leaf{name, shape, width, height, align, next}: U32.add(1, chain_count(next))
    case Node{name, layout, width, height, align, first, next}: U32.add(1, U32.add(chain_count(first), chain_count(next)))
def append_indices(xs: List<&2, U32>, ys: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}: ys
    case Con{x, rest}: Con{x, append_indices(rest, ys)}
def is_depth(axis: Axis) -> Bool:
  match axis:
    case Depth{}: True{}
    case _: False{}
def order_chain(t: UI, +start: U32, +reverse: Bool, +overrides: Bool) -> List<&2, U32>:
  match t:
    case Last{}: []
    case Leaf{+name, shape, width, height, align, next}:
      +own = Bool.pick(List<&2, U32>, interactive(name), [start], [])
      +rest = order_chain(next, U32.add(start, 1), reverse, overrides)
      Bool.pick(List<&2, U32>, reverse, append_indices(rest, own), append_indices(own, rest))
    case Node{+name, Layout{axis, gap, pad}, width, height, align, +first, next}:
      +own = Bool.pick(List<&2, U32>, interactive(name), [start], order_chain(first, U32.add(start, 1), Bool.and(is_depth(axis), Bool.not(Bool.and(overrides, declares_order(name)))), overrides))
      +rest = order_chain(next, U32.add(start, U32.add(1, chain_count(first))), reverse, overrides)
      Bool.pick(List<&2, U32>, reverse, append_indices(rest, own), append_indices(own, rest))
def focus_order(t: UI) -> List<&2, U32>: order_chain(t, 0, False{}, True{})
def reading_order(t: UI) -> List<&2, U32>: order_chain(t, 0, False{}, False{})

# Frame chrome: kicker, title and caption on white, then the Near panel.
def boxes_of(root: UI, +width: U32, +height: U32) -> List<&2, Box>:
  place(root, Depth{}, 0, 20, 104, U32.sub(width, 40), U32.sub(height, 124), 0, 0, 0)
def specimen(id: String, section: String, label: String, kicker: String, title: String, caption: String, x: U32, y: U32, +width: U32, +height: U32, wide: U32, +root: UI, explode: Explode) -> Specimen:
  Specimen{id, section, label, kicker, title, caption, "", "", x, y, width, height, wide, 20, 104, U32.sub(width, 40), U32.sub(height, 124), [],
    boxes_of(root, width, height), layers(root, explode), focus_order(root), []}
# A Shape frame: the same boxes in a Dark panel and a Light panel.
def shape_specimen(id: String, section: String, label: String, kicker: String, title: String, caption: String, x: U32, y: U32, +width: U32, +height: U32, +root: UI) -> Specimen:
  +frame_width = U32.sub(U32.mul(width, 2), 20)
  +boxes = boxes_of(root, width, height)
  Specimen{id, section, label, kicker, title, caption, "", "", x, y, frame_width, height, frame_width, 20, 104, U32.sub(width, 40), U32.sub(height, 124),
    [Panel{T.Scheme.Dark{}, boxes}, Panel{T.Scheme.Light{}, boxes}], boxes, [], focus_order(root), []}
# A Shape frame whose content depends on the scheme (the contrast grid).
def scheme_specimen(id: String, section: String, label: String, kicker: String, title: String, caption: String, x: U32, y: U32, +width: U32, +height: U32, +dark: UI, light: UI) -> Specimen:
  +frame_width = U32.sub(U32.mul(width, 2), 20)
  +boxes = boxes_of(dark, width, height)
  Specimen{id, section, label, kicker, title, caption, "", "", x, y, frame_width, height, frame_width, 20, 104, U32.sub(width, 40), U32.sub(height, 124),
    [Panel{T.Scheme.Dark{}, boxes}, Panel{T.Scheme.Light{}, boxes_of(light, width, height)}], boxes, [], focus_order(dark), []}

# Cases: approved and used
# ------------------------

# Primitive cases used by the reusable specimen catalogue.
def state_name(s: T.State) -> String:
  match s:
    case T.State.Rest{}: "state:Rest"
    case T.State.Pressed{}: "state:Pressed"
    case T.State.Disabled{}: "state:Disabled"
def stop_cases(s: T.Stop) -> List<&2, String>:
  match s:
    case T.Stop.Of{r}: ["surface role:" ++ T.surface_name(r)]
    case T.Stop.Clear{}: ["stop:Clear"]
def append_names(xs: List<&2, String>, ys: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}: ys
    case Con{x, rest}: Con{x, append_names(rest, ys)}
def fill_cases(f: Fill) -> List<&2, String>:
  match f:
    case Fill.None{}: ["fill:None"]
    case Solid{c, st}: ["fill:Solid", "surface role:" ++ T.surface_name(c), state_name(st)]
    case Gradient{a, b, hold}: Con{"fill:Gradient", append_names(stop_cases(a), stop_cases(b))}
    case Image{Bitmap.Atlas{frame}, time}: ["fill:Image", "bitmap:Atlas"]
    case Image{Bitmap.Photo{asset, w, h}, time}: ["fill:Image", "bitmap:Photo"]
def stroke_cases(s: Stroke) -> List<&2, String>:
  match s:
    case NoStroke{}: ["stroke:NoStroke"]
    case Stroke{c, st, w}: ["stroke:Stroke", "line role:" ++ T.line_name(c), state_name(st)]
def effect_cases(es: List<&2, Effect>) -> List<&2, String>:
  match es:
    case Nil{}: []
    case Con{Blur{r}, rest}: Con{"effect:Blur", effect_cases(rest)}
    case Con{Shadow{y, b}, rest}: Con{"effect:Shadow", effect_cases(rest)}
    case Con{Glass{b, sat, refr, spec, tint, edge, over}, rest}: Con{"effect:Glass", Con{"line role:" ++ T.line_name(edge), effect_cases(rest)}}
def radius_name(r: Radius) -> String:
  match r:
    case Corner{l}: "radius:Corner"
    case Full{}: "radius:Full"
def shape_cases(s: Shape) -> List<&2, String>:
  match s:
    case Shape{Text{string, text_type}, TextFill.Solid{c, st}, stroke, effects}:
      append_names(["geometry:Text", "fill:Solid", "text role:" ++ T.text_name(c), state_name(st)], append_names(stroke_cases(stroke), effect_cases(effects)))
    case Shape{Path{drawing}, fill, stroke, effects}:
      Con{"geometry:Path", append_names(fill_cases(fill), append_names(stroke_cases(stroke), effect_cases(effects)))}
    case Shape{Rounded{w, h, radius}, fill, stroke, effects}:
      Con{"geometry:Rounded", Con{radius_name(radius), append_names(fill_cases(fill), append_names(stroke_cases(stroke), effect_cases(effects)))}}
def axis_name(a: Axis) -> String:
  match a:
    case Horizontal{}: "axis:Horizontal"
    case Vertical{}: "axis:Vertical"
    case Depth{}: "axis:Depth"
def has_name(xs: List<&2, String>, +n: String) -> Bool:
  match xs:
    case Nil{}: False{}
    case Con{x, rest}: Bool.or(String.eq(x, n), has_name(rest, n))
# One recursion per name: each step keeps or extends the seen list (both
# candidates are plain values), so it never branches into two recursions.
def keep(+seen: List<&2, String>, +x: String) -> List<&2, String>:
  Bool.pick(List<&2, String>, has_name(seen, x), seen, Con{x, seen})
# Collected with an accumulator that stays duplicate-free (a loop, so frames
# with thousands of boxes are fine).
def keep_all(xs: List<&2, String>, +seen: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}: seen
    case Con{x, rest}: keep_all(rest, keep(seen, x))
def box_cases_into(boxes: List<&2, Box>, +seen: List<&2, String>) -> List<&2, String>:
  match boxes:
    case Nil{}: seen
    case Con{Box{name, Draw{shape}, x, y, w, h, level, layer}, rest}: box_cases_into(rest, keep_all(shape_cases(shape), seen))
    case Con{Box{name, Outline{axis}, x, y, w, h, level, layer}, rest}: box_cases_into(rest, keep(seen, axis_name(axis)))
    case Con{Box{name, Spacing{axis}, x, y, w, h, level, layer}, rest}: box_cases_into(rest, keep(seen, axis_name(axis)))
def box_cases(boxes: List<&2, Box>) -> List<&2, String>: box_cases_into(boxes, [])
def unique_go(xs: List<&2, String>, +seen: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}: seen
    case Con{x, rest}: unique_go(rest, keep(seen, x))
def reverse_names(xs: List<&2, String>, acc: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}: acc
    case Con{x, rest}: reverse_names(rest, Con{x, acc})
def unique(xs: List<&2, String>, seen: List<&2, String>) -> List<&2, String>:
  reverse_names(unique_go(xs, seen), [])
def panel_cases_into(ps: List<&2, Panel>, +seen: List<&2, String>) -> List<&2, String>:
  match ps:
    case Nil{}: seen
    case Con{Panel{scheme, boxes}, rest}: panel_cases_into(rest, box_cases_into(boxes, seen))
def specimen_cases_into(s: Specimen, +seen: List<&2, String>) -> List<&2, String>:
  match s:
    case Specimen{id, section, label, kicker, title, caption, slice, sizes, x, y, width, height, wide, px, py, pw, ph, panels, boxes, layers, focus, players}:
      panel_cases_into(panels, box_cases_into(boxes, seen))
def specimens_cases_into(ss: List<&2, Specimen>, +seen: List<&2, String>) -> List<&2, String>:
  match ss:
    case Nil{}: seen
    case Con{x, rest}: specimens_cases_into(rest, specimen_cases_into(x, seen))
def specimens_cases(ss: List<&2, Specimen>) -> List<&2, String>: specimens_cases_into(ss, [])
def used(ss: List<&2, Specimen>) -> List<&2, String>:
  reverse_names(specimens_cases(ss), [])

# Every case the types define (matches and laws run over all of them).
def universe() -> List<&2, String>:
  ["geometry:Text", "geometry:Path", "geometry:Rounded", "radius:Corner", "radius:Full",
   "fill:None", "fill:Solid", "fill:Gradient", "fill:Image", "bitmap:Atlas", "bitmap:Photo",
   "text role:Ink", "text role:Muted",
   "surface role:Background", "surface role:Surface", "surface role:Raised", "surface role:Accent", "surface role:Danger", "surface role:Field", "surface role:Action", "surface role:Mine", "surface role:Glass",
   "line role:Ink", "line role:Muted", "line role:Line", "line role:Accent", "line role:Edge",
   "stop:Clear", "state:Rest", "state:Pressed", "state:Disabled",
   "stroke:NoStroke", "stroke:Stroke", "effect:Blur", "effect:Shadow", "effect:Glass",
   "axis:Horizontal", "axis:Vertical", "axis:Depth"]
# Additional reusable cases represented separately in the catalogue.
def queued() -> List<&2, String>: ["effect:Shadow", "bitmap:Photo", "surface role:Field", "line role:Edge", "surface role:Action", "surface role:Mine", "surface role:Glass", "effect:Glass"]
# Baseline cases represented by the primitive specimens.
def approved() -> List<&2, String>:
  ["geometry:Text", "geometry:Path", "geometry:Rounded", "radius:Corner", "radius:Full",
   "fill:None", "fill:Solid", "fill:Gradient", "fill:Image", "bitmap:Atlas",
   "text role:Ink", "text role:Muted",
   "surface role:Background", "surface role:Surface", "surface role:Raised", "surface role:Accent", "surface role:Danger",
   "line role:Ink", "line role:Muted", "line role:Line", "line role:Accent",
   "stop:Clear", "state:Rest", "state:Pressed", "state:Disabled",
   "stroke:NoStroke", "stroke:Stroke", "effect:Blur",
   "axis:Horizontal", "axis:Vertical", "axis:Depth"]

# Allowed field values (colour roles from tokens.bend, text types)
# ---------------------------------------------------------------

def ink() -> T.TextRole: T.TextRole.Ink{}
def muted() -> T.TextRole: T.TextRole.Muted{}
def rest() -> T.State: T.State.Rest{}
def solid(color: T.SurfaceRole) -> Fill: Solid{color, T.State.Rest{}}
def body() -> TextType: TextType{"Body", 16, 400}
def name_type() -> TextType: TextType{"Name", 18, 650}
def caption_type() -> TextType: TextType{"Caption", 11, 500}
def hairline(color: T.LineRole) -> Stroke: Stroke{color, T.State.Rest{}, "1"}
# The Glass effect from the material token, over a backdrop; its rim is the
# decorative Edge.
def glass_of(m: T.Material, over: T.Backdrop) -> Effect:
  match m:
    case T.Material{blur, sat, refr, spec, tint}: Glass{blur, sat, refr, spec, tint, T.LineRole.Edge{}, over}
def glass(over: T.Backdrop) -> Effect: glass_of(T.glass(), over)

# Shape instances
# ---------------

# Text is glyph geometry with a Solid fill.
def text(+name: String, string: String, text_type: TextType, color: T.TextRole, width: U32, height: U32, align: Align) -> UI:
  leaf(name, Shape{Text{string, text_type}, TextFill.Solid{color, T.State.Rest{}}, NoStroke{}, []}, width, height, align)
# The approved symbols are open paths: no fill, drawn by the stroke, whose
# colour is the Ink role.
def outline(drawing: S.Drawing) -> Stroke:
  match drawing:
    case S.Drawing{name, x, y, width, shapes}: Stroke{T.LineRole.Ink{}, T.State.Rest{}, width}
def symbol(name: String, +glyph: S.Symbol, +side: U32) -> UI:
  leaf(name, Shape{Path{S.drawing(glyph)}, Fill.None{}, outline(S.drawing(glyph)), []}, side, side, Middle{})
# A Rounded instance. The specimen knows the size, so it writes it into the
# geometry and gives the layout the same box.
def rounded(name: String, fill: Fill, +width: U32, +height: U32, radius: Radius, stroke: Stroke, align: Align) -> UI:
  leaf(name, Shape{Rounded{width, height, radius}, fill, stroke, []}, width, height, align)
def circle(name: String, fill: Fill, stroke: Stroke, +side: U32, align: Align) -> UI:
  rounded(name, fill, side, side, Full{}, stroke, align)
# Sprite placeholder. Supply a caller-owned atlas frame to paint artwork.
def pet(name: String, animation: N.Animation, +width: U32, +height: U32) -> UI:
  leaf(name, Shape{Rounded{width, height, Corner{0}}, Image{Bitmap.Atlas{N.sample(animation, 0, False{})}, 0}, NoStroke{}, []}, width, height, Middle{})
# The header fade: square corners with a Gradient fill and a Blur effect.
def fade(+width: U32, +height: U32) -> UI:
  leaf("Fade + blur", Shape{Rounded{width, height, Corner{0}}, Gradient{T.Stop.Of{T.SurfaceRole.Background{}}, T.Stop.Clear{}, 50}, NoStroke{}, [Blur{10}]}, width, height, Leading{})
def dot() -> UI:
  # A dot: a circle drawn by a stroke half its size wide (a Muted line role).
  circle("Dot", Fill.None{}, Stroke{T.LineRole.Muted{}, T.State.Rest{}, "4"}, 8, Middle{})
def dots() -> UI:
  layout("Dots", Horizontal{}, 5, 0, 0, 0, Middle{}, [dot(), dot(), dot()])
# Approximate width of a short caption (11px): six pixels a character.
def caption_width(+s: String) -> U32: U32.add(U32.mul(6, U32.from_nat(String.length(s))), 2)
# A swatch: one surface role in a state, and its name.
def swatch(+label: String, +color: T.SurfaceRole, +state: T.State) -> UI:
  layout(label, Vertical{}, 6, 0, 0, 0, Middle{}, [
    rounded("Solid " ++ label, Solid{color, state}, 60, 44, Corner{10}, hairline(T.LineRole.Line{}), Middle{}),
    text("Value", label, caption_type(), muted(), caption_width(label), 14, Middle{})])

# Shared instances used by the Layout specimens. These are arrangements of
# Shapes for the specimens, not components.
def button(+name: String, fill: T.SurfaceRole, stroke: T.LineRole, glyph: S.Symbol, +side: U32, glyph_side: U32, align: Align) -> UI:
  layout(name ++ " button", Depth{}, 0, 0, side, side, align, [circle("Circle", solid(fill), hairline(stroke), side, Middle{}), symbol(name, glyph, glyph_side)])
def badge() -> UI:
  rounded("Badge", solid(T.SurfaceRole.Raised{}), 72, 32, Full{}, NoStroke{}, Middle{})
def search_button() -> UI:
  button("Search", T.SurfaceRole.Surface{}, T.LineRole.Muted{}, S.Search{}, 44, 24, Leading{})
def call_button() -> UI:
  button("Call", T.SurfaceRole.Raised{}, T.LineRole.Accent{}, S.Telephone{}, 44, 24, Leading{})
def identity() -> UI:
  layout("Near identity", Vertical{}, 0, 0, 0, 0, Middle{}, [
    pet("Near", N.Idle{}, 56, 61),
    layout("Name badge", Depth{}, 0, 0, 72, 32, Middle{}, [badge(), text("Name", "Near", name_type(), ink(), 42, 22, Middle{})])])
def header(+width: U32, +pad: U32) -> UI:
  layout("Header", Horizontal{}, U32.div(U32.sub(U32.sub(width, U32.add(pad, pad)), 160), 2), pad, width, 0, Leading{}, [search_button(), identity(), call_button()])
def bubble(+name: String, value: String, fill: T.SurfaceRole, +width: U32, text_width: U32, align: Align) -> UI:
  layout(name, Depth{}, 0, 0, width, 44, align, [rounded("Bubble", solid(fill), width, 44, Full{}, NoStroke{}, Middle{}), text("Text", value, body(), ink(), text_width, 20, Middle{})])
def near_says(value: String, width: U32, text_width: U32) -> UI:
  bubble("Near bubble", value, T.SurfaceRole.Surface{}, width, text_width, Leading{})
def you_say(value: String, width: U32, text_width: U32) -> UI:
  bubble("Your bubble", value, T.SurfaceRole.Accent{}, width, text_width, Trailing{})
def receipt(value: String) -> UI:
  text("Read receipt", value, caption_type(), muted(), 62, 14, Trailing{})
def typing() -> UI:
  layout("Typing indicator", Depth{}, 0, 0, 64, 36, Leading{}, [rounded("Bubble", solid(T.SurfaceRole.Surface{}), 64, 36, Full{}, NoStroke{}, Middle{}), dots()])
def composer(+width: U32) -> UI:
  layout("Composer", Depth{}, 0, 0, width, 52, Middle{}, [
    rounded("Pill", solid(T.SurfaceRole.Surface{}), width, 52, Full{}, hairline(T.LineRole.Line{}), Middle{}),
    layout("Row", Horizontal{}, 10, 0, 0, 0, Middle{}, [
      button("Plus", T.SurfaceRole.Surface{}, T.LineRole.Line{}, S.Plus{}, 40, 22, Middle{}),
      text("Field text", "Escribe a Near", body(), T.TextRole.Muted{}, U32.sub(width, 112), 20, Middle{}),
      button("Send", T.SurfaceRole.Accent{}, T.LineRole.Accent{}, S.Send{}, 40, 22, Middle{})])])

# Shape · geometry cases
# ----------------------

def text_root() -> UI:
  layout("Text instances", Vertical{}, 26, 0, 0, 0, Middle{}, [
    text("Message", "¿Cómo puedo ayudarte?", body(), ink(), 220, 20, Middle{}),
    text("Name", "Near", name_type(), ink(), 42, 22, Middle{}),
    text("Read receipt", "Read 12:52", caption_type(), muted(), 62, 14, Middle{})])
def path_root() -> UI:
  layout("Symbols", Vertical{}, 32, 0, 0, 0, Middle{}, [
    layout("Large", Horizontal{}, 36, 0, 0, 0, Middle{}, [symbol("Search", S.Search{}, 40), symbol("Call", S.Telephone{}, 40), symbol("Send", S.Send{}, 40), symbol("Plus", S.Plus{}, 40)]),
    layout("Actual size", Horizontal{}, 52, 0, 0, 0, Middle{}, [symbol("Search", S.Search{}, 24), symbol("Call", S.Telephone{}, 24), symbol("Send", S.Send{}, 24), symbol("Plus", S.Plus{}, 24)])])
# Rounded: the radius runs from 0 (square) through rounded corners to Full,
# which is a circle on a square and a pill on a wide box; then the Near
# shapes that are Rounded instances.
# A tile of the continuum: the Rounded box and its radius value under it.
def tile(+name: String, +width: U32, radius: Radius, label: String, label_width: U32) -> UI:
  layout(name, Vertical{}, 8, 0, 0, 0, Middle{}, [
    rounded(name, solid(T.SurfaceRole.Raised{}), width, 56, radius, hairline(T.LineRole.Line{}), Middle{}),
    text("Radius", label, caption_type(), muted(), label_width, 14, Middle{})])
def rounded_root() -> UI:
  layout("Rounded instances", Vertical{}, 32, 0, 0, 0, Middle{}, [
    layout("Radius 0 to Full", Horizontal{}, 20, 0, 0, 0, Middle{}, [
      tile("Radius 0", 56, Corner{0}, "0", 7), tile("Radius 6", 56, Corner{6}, "6", 7), tile("Radius 14", 56, Corner{14}, "14", 13), tile("Radius 22", 56, Corner{22}, "22", 13),
      tile("Full · circle", 56, Full{}, "Full", 21), tile("Full · pill", 128, Full{}, "Full", 21)]),
    layout("Near shapes", Horizontal{}, 56, 0, 0, 0, Middle{}, [
      layout("Pills", Vertical{}, 12, 0, 280, 0, Middle{}, [
        rounded("Near bubble", solid(T.SurfaceRole.Surface{}), 232, 44, Full{}, NoStroke{}, Leading{}),
        rounded("Your bubble", solid(T.SurfaceRole.Accent{}), 168, 44, Full{}, NoStroke{}, Trailing{}),
        rounded("Composer pill", solid(T.SurfaceRole.Surface{}), 280, 52, Full{}, hairline(T.LineRole.Line{}), Middle{})]),
      layout("Badge, circles, dots", Vertical{}, 24, 0, 0, 0, Middle{}, [
        rounded("Name badge", solid(T.SurfaceRole.Raised{}), 72, 32, Full{}, NoStroke{}, Middle{}),
        layout("Round buttons", Horizontal{}, 14, 0, 0, 0, Middle{}, [
          circle("Search circle", solid(T.SurfaceRole.Surface{}), hairline(T.LineRole.Muted{}), 44, Middle{}),
          circle("Call circle", solid(T.SurfaceRole.Raised{}), hairline(T.LineRole.Accent{}), 44, Middle{}),
          circle("Plus circle", solid(T.SurfaceRole.Surface{}), hairline(T.LineRole.Line{}), 40, Middle{}),
          circle("Send circle", solid(T.SurfaceRole.Accent{}), hairline(T.LineRole.Accent{}), 40, Middle{})]),
        dots()])])])

# Shape · fill cases
# ------------------

# None: the approved symbols paint nothing inside; only their stroke draws.
def none_root() -> UI:
  layout("Stroke only", Vertical{}, 34, 0, 0, 0, Middle{}, [
    symbol("Search", S.Search{}, 112),
    layout("Every symbol", Horizontal{}, 40, 0, 0, 0, Middle{}, [symbol("Call", S.Telephone{}, 28), symbol("Send", S.Send{}, 28), symbol("Plus", S.Plus{}, 28)])])
# Solid: the surface roles, the state rules (Pressed darkens by one step,
# Disabled is 50% opacity), and the contrast of every pair the types allow
# in this scheme, with AA and AAA marks (AA is a hard law, checked in tests).
def swatches() -> UI:
  layout("Surface roles", Horizontal{}, 12, 0, 0, 0, Middle{}, [swatch("Background", T.SurfaceRole.Background{}, rest()), swatch("Surface", T.SurfaceRole.Surface{}, rest()), swatch("Raised", T.SurfaceRole.Raised{}, rest()), swatch("Accent", T.SurfaceRole.Accent{}, rest()), swatch("Danger", T.SurfaceRole.Danger{}, rest()), swatch("Field", T.SurfaceRole.Field{}, rest()), swatch("Action", T.SurfaceRole.Action{}, rest()), swatch("Mine", T.SurfaceRole.Mine{}, rest())])
def states() -> UI:
  layout("State rules", Horizontal{}, 12, 0, 0, 0, Middle{}, [swatch("Rest", T.SurfaceRole.Accent{}, T.State.Rest{}), swatch("Pressed", T.SurfaceRole.Accent{}, T.State.Pressed{}), swatch("Disabled", T.SurfaceRole.Accent{}, T.State.Disabled{})])
def tenths(+r: U32) -> String: U32.show(U32.div(r, 100)) ++ "." ++ U32.show(U32.div(U32.mod(r, 100), 10))
def grade(+r: U32, +use: T.Use) -> String:
  Bool.pick(String, U32.is_ge(r, 700), "AAA", Bool.pick(String, U32.is_ge(r, T.aa(use)), "AA", "fail"))
# One cell: the surface, a sample of the foreground on it, the ratio and grade.
def cell(+bg: T.SurfaceRole, sample: UI, +r: U32, +use: T.Use) -> UI:
  +label = tenths(r) ++ " " ++ grade(r, use)
  layout("Pair", Depth{}, 0, 0, 72, 50, Middle{}, [
    rounded("Surface", solid(bg), 72, 50, Corner{8}, NoStroke{}, Middle{}),
    layout("Sample", Vertical{}, 3, 0, 0, 0, Middle{}, [sample, text("Ratio", label, caption_type(), ink(), caption_width(label), 14, Middle{})])])
def line_sample(+role: T.LineRole) -> UI: circle("Ring", Fill.None{}, Stroke{role, T.State.Rest{}, "2"}, 14, Middle{})
def text_sample(+role: T.TextRole) -> UI: text("Aa", "Aa", TextType{"Sample", 13, 600}, role, 18, 16, Middle{})
def decorative_cell(+bg: T.SurfaceRole, +r: U32) -> UI:
  +label = tenths(r)
  layout("Decorative pair", Depth{}, 0, 0, 72, 50, Middle{}, [
    rounded("Surface", solid(bg), 72, 50, Corner{8}, NoStroke{}, Middle{}),
    layout("Sample", Vertical{}, 0, 0, 0, 0, Middle{}, [text("Ratio note", label, caption_type(), ink(), caption_width(label), 14, Middle{}), text("Decorative", "decorative", caption_type(), ink(), caption_width("decorative"), 14, Middle{})])])
def no_pair() -> UI:
  layout("Not allowed", Depth{}, 0, 0, 72, 50, Middle{}, [text("Not allowed", "not allowed", caption_type(), muted(), 66, 14, Middle{})])
def has_bg(bgs: List<&2, T.SurfaceRole>, +bg: T.SurfaceRole) -> Bool:
  match bgs:
    case Nil{}: False{}
    case Con{b, rest}: Bool.or(String.eq(T.surface_name(b), T.surface_name(bg)), has_bg(rest, bg))
def text_cells(+role: T.TextRole, bgs: List<&2, T.SurfaceRole>, +scheme: T.Scheme) -> List<&2, UI>:
  match bgs:
    case Nil{}: []
    case Con{+bg, rest}: Con{Bool.pick(UI, has_bg(T.text_on(role), bg), cell(bg, text_sample(role), T.ratio(T.rgb(T.text_tone(role), scheme, T.State.Rest{}), T.rgb(T.surface_tone(bg), scheme, T.State.Rest{})), T.Use.Text{}), no_pair()), text_cells(role, rest, scheme)}
def line_cells(+role: T.LineRole, bgs: List<&2, T.SurfaceRole>, +scheme: T.Scheme) -> List<&2, UI>:
  match bgs:
    case Nil{}: []
    case Con{+bg, rest}: Con{Bool.pick(UI, has_bg(T.line_on(role), bg), cell(bg, line_sample(role), T.ratio(T.rgb(T.line_tone(role), scheme, T.State.Rest{}), T.rgb(T.surface_tone(bg), scheme, T.State.Rest{})), T.Use.Graphic{}), no_pair()), line_cells(role, rest, scheme)}
def grid_row(+label: String, cells: List<&2, UI>) -> UI:
  layout(label, Horizontal{}, 6, 0, 0, 0, Leading{}, Con{layout("Row label", Horizontal{}, 0, 0, 72, 0, Middle{}, [text("Label", label, caption_type(), muted(), caption_width(label), 14, Leading{})]), cells})
def column_heads() -> List<&2, UI>:
  [layout("Head", Horizontal{}, 0, 0, 72, 0, Middle{}, [text("Head", "Background", caption_type(), muted(), 64, 14, Middle{})]),
   layout("Head", Horizontal{}, 0, 0, 72, 0, Middle{}, [text("Head", "Surface", caption_type(), muted(), 44, 14, Middle{})]),
   layout("Head", Horizontal{}, 0, 0, 72, 0, Middle{}, [text("Head", "Raised", caption_type(), muted(), 38, 14, Middle{})]),
   layout("Head", Horizontal{}, 0, 0, 72, 0, Middle{}, [text("Head", "Accent", caption_type(), muted(), 38, 14, Middle{})]),
   layout("Head", Horizontal{}, 0, 0, 72, 0, Middle{}, [text("Head", "Danger", caption_type(), muted(), 40, 14, Middle{})]),
   layout("Head", Horizontal{}, 0, 0, 72, 0, Middle{}, [text("Head", "Field", caption_type(), muted(), 32, 14, Middle{})]),
   layout("Head", Horizontal{}, 0, 0, 72, 0, Middle{}, [text("Head", "Action", caption_type(), muted(), 38, 14, Middle{})]),
   layout("Head", Horizontal{}, 0, 0, 72, 0, Middle{}, [text("Head", "Mine", caption_type(), muted(), 30, 14, Middle{})])]
# The decorative Edge: shown on Field (its only use) with its ratio, marked
# decorative (exempt from the 3:1 law, see tokens.decorative()).
def edge_cells(bgs: List<&2, T.SurfaceRole>, +scheme: T.Scheme) -> List<&2, UI>:
  match bgs:
    case Nil{}: []
    case Con{+bg, rest}: Con{Bool.pick(UI, String.eq(T.surface_name(bg), "Field"), decorative_cell(bg, T.ratio(T.rgb(T.line_tone(T.LineRole.Edge{}), scheme, T.State.Rest{}), T.rgb(T.surface_tone(bg), scheme, T.State.Rest{}))), no_pair()), edge_cells(rest, scheme)}
def contrast_grid(+scheme: T.Scheme) -> UI:
  layout("Contrast", Vertical{}, 6, 0, 0, 0, Middle{}, [
    grid_row("", column_heads()),
    grid_row("Text Ink", text_cells(T.TextRole.Ink{}, T.surfaces(), scheme)),
    grid_row("Text Muted", text_cells(T.TextRole.Muted{}, T.surfaces(), scheme)),
    grid_row("Line Ink", line_cells(T.LineRole.Ink{}, T.surfaces(), scheme)),
    grid_row("Line Muted", line_cells(T.LineRole.Muted{}, T.surfaces(), scheme)),
    grid_row("Line Line", line_cells(T.LineRole.Line{}, T.surfaces(), scheme)),
    grid_row("Line Accent", line_cells(T.LineRole.Accent{}, T.surfaces(), scheme)),
    grid_row("Line Edge", edge_cells(T.surfaces(), scheme)),
    text("Exceptions", "Exceptions: none. AA is 4.5 for text, 3.0 for lines; AAA is 7.0.", caption_type(), muted(), 380, 14, Middle{}),
    text("Decorative note", "Decorative: Edge, the composer pill's faint border on Field (exempt from 3:1).", caption_type(), muted(), 480, 14, Middle{}),
    text("Icon only note", "Action carries icons only: no text sits on it. Glass pairs: see the Glass frame.", caption_type(), muted(), 460, 14, Middle{})])
def solid_root(+scheme: T.Scheme) -> UI:
  layout("Colour roles", Vertical{}, 18, 0, 0, 0, Middle{}, [swatches(), states(), contrast_grid(scheme)])
# The fade is the same value as in the Depth specimen, painted over Solid
# stripes so the gradient and the blur are visible on the dark panel.
# The fade bleeds 10 past the stripes so no blurred stripe edge shows.
def gradient_root() -> UI:
  layout("Header fade", Depth{}, 0, 0, 300, 188, Middle{}, [
    layout("Solid stripes", Horizontal{}, 0, 0, 0, 0, Middle{}, [
      rounded("Stripe", solid(T.SurfaceRole.Accent{}), 70, 168, Corner{0}, NoStroke{}, Middle{}),
      rounded("Stripe", solid(T.SurfaceRole.Surface{}), 70, 168, Corner{0}, NoStroke{}, Middle{}),
      rounded("Stripe", solid(T.SurfaceRole.Danger{}), 70, 168, Corner{0}, NoStroke{}, Middle{}),
      rounded("Stripe", solid(T.SurfaceRole.Raised{}), 70, 168, Corner{0}, NoStroke{}, Middle{})]),
    fade(300, 188)])
# Shape · effect case Glass
# -------------------------

# Liquid Glass over moving content: a thread passes under a round button, a
# badge and a pill (over Content: only Ink sits on them); the composer pill
# sits over the Background only (over Base: Muted is allowed too).
def at(+name: String, +x: U32, +y: U32, t: UI) -> UI:
  layout(name, Vertical{}, 0, 0, 0, 0, Leading{}, [layout("Offset", Vertical{}, 0, 0, 1, y, Leading{}, []), layout("Row", Horizontal{}, 0, 0, 0, 0, Leading{}, [layout("Offset", Horizontal{}, 0, 0, x, 1, Leading{}, []), t])])
def glass_shape(+name: String, +w: U32, +h: U32, over: T.Backdrop) -> UI:
  leaf(name, Shape{Rounded{w, h, Full{}}, Solid{T.SurfaceRole.Glass{}, T.State.Rest{}}, NoStroke{}, [glass(over)]}, w, h, Middle{})
def on_glass(+name: String, +w: U32, +h: U32, over: T.Backdrop, inner: UI) -> UI:
  layout(name, Depth{}, 0, 0, w, h, Middle{}, [glass_shape("Glass", w, h, over), inner])
def glass_backdrop() -> UI:
  layout("Content", Vertical{}, 10, 12, 300, 220, Leading{}, [
    near_says("The thread scrolls under the glass,", 276, 244),
    you_say("Pause the animation", 176, 144),
    near_says("Stopped", 96, 64),
    you_say("hello", 80, 48)])
def glass_ratio(c: T.Contrast) -> UI:
  match c:
    case T.Contrast{+fg, +bg, scheme, state, +use, +r, ok, best}:
      +label = fg ++ " on " ++ bg ++ ": " ++ tenths(r) ++ " " ++ grade(r, use)
      text("Glass pair", label, caption_type(), ink(), caption_width(label), 14, Leading{})
def glass_ratios(xs: List<&2, T.Contrast>) -> List<&2, UI>:
  match xs:
    case Nil{}: []
    case Con{x, rest}: Con{glass_ratio(x), glass_ratios(rest)}
def glass_root(+scheme: T.Scheme) -> UI:
  layout("Liquid Glass", Vertical{}, 14, 0, 0, 0, Middle{}, [
    layout("Scene", Depth{}, 0, 0, 300, 300, Leading{}, [
      glass_backdrop(),
      at("Button", 12, 14, on_glass("Glass button", 48, 48, T.Backdrop.Content{}, symbol("Call", S.Telephone{}, 24))),
      at("Badge", 114, 70, on_glass("Glass badge", 72, 32, T.Backdrop.Content{}, text("Name", "Near", name_type(), ink(), 42, 22, Middle{}))),
      at("Base", 0, 236, rounded("Background", solid(T.SurfaceRole.Background{}), 300, 64, Corner{0}, NoStroke{}, Leading{})),
      at("Pill", 12, 246, on_glass("Glass pill", 276, 44, T.Backdrop.Base{}, text("Placeholder", "Mensaje", body(), muted(), 240, 20, Middle{})))]),
    layout("Ratios", Vertical{}, 4, 0, 300, 0, Leading{}, glass_ratios(T.glass_on(T.backdrops(), scheme)))])

# Layout · axis cases
# -------------------

# The chat is shared: the Vertical specimen shows it alone, the Depth specimen
# floats the header over it.
def chat() -> UI:
  layout("Chat", Vertical{}, 12, 16, 320, 516, Leading{}, [
    near_says("Hola, soy Near.", 140, 108),
    near_says("¿Cómo puedo ayudarte?", 252, 220),
    you_say("Quiero revisar una idea.", 162, 130),
    receipt("Read 12:52"),
    near_says("Podemos revisarla juntos.", 210, 178),
    you_say("Gracias, Near.", 140, 108),
    receipt("Read 12:54"),
    near_says("¿Continuamos?", 132, 100),
    typing()])
def horizontal_root() -> UI:
  composer(300)
def vertical_root() -> UI:
  chat()
def depth_root() -> UI:
  layout("Screen", Depth{}, 0, 0, 320, 516, Leading{}, [chat(), fade(320, 150), header(320, 16)])

# Frames. Shape frames show their panel in both schemes (Dark, then Light),
# so they are two panels wide; columns step 796 and both Shape rows end on
# the same edge. Layout frames show one panel in the toolbar's scheme.
def specimens() -> List<&2, Specimen>:
  [shape_specimen("text", "geometry", "Text", "Geometry cases", "Shape · geometry case Text", "Text{string, type}: glyphs whose fill is a text role. A message, the name Near and a read receipt.", 0, 0, 340, 440, text_root()),
   shape_specimen("path", "geometry", "Path", "Geometry cases", "Shape · geometry case Path", "Path{drawing}: a fixed drawing. The four approved symbols, large and at actual size.", 740, 0, 340, 440, path_root()),
   shape_specimen("rounded", "geometry", "Rounded", "Geometry cases", "Shape · geometry case Rounded", "Rounded{width, height, radius}: radius from 0 through rounded corners to Full, a circle on a square and a pill on a wide box. Bubbles, composer, badge, round buttons and typing dots are Rounded.", 1480, 0, 1120, 440, rounded_root()),
   shape_specimen("none", "fill", "None", "Fill cases", "Shape · fill case None", "None{}: nothing is painted inside; only the stroke draws. Every approved symbol.", 0, 616, 340, 380, none_root()),
   scheme_specimen("solid", "fill", "Solid", "Fill cases", "Shape · fill case Solid", "Solid{color, state}: a surface role and a state rule. Below, every allowed foreground on every surface, with its contrast. Field, Action, Mine and Edge are queued for sign-off.", 740, 616, 740, 760, solid_root(T.Scheme.Dark{}), solid_root(T.Scheme.Light{})),
   shape_specimen("gradient", "fill", "Gradient", "Fill cases", "Shape · fill case Gradient", "Gradient: the header fade, Background held to 50% then Clear, plus a Blur effect, over Solid stripes.", 0, 1076, 340, 380, gradient_root()),
   scheme_specimen("glass", "effect", "Glass", "Effect cases", "Shape · effect case Glass", "Token-driven glass. Ink over Content; Ink/Muted over Base. Queued.", 3040, 616, 340, 580, glass_root(T.Scheme.Dark{}), glass_root(T.Scheme.Light{})),
   specimen("horizontal", "layout", "Horizontal", "Layout cases", "Layout · case Horizontal", "The composer row: plus, field and send, side by side.", 0, 1696, 360, 264, 360, horizontal_root(), Flat{}),
   specimen("vertical", "layout", "Vertical", "Layout cases", "Layout · case Vertical", "The thread: bubbles and read receipts stacked top to bottom.", 456, 1696, 360, 640, 360, vertical_root(), Flat{}),
   specimen("depth", "layout", "Depth", "Layout cases", "Layout · case Depth", "2D paint order: the header over the thread. Bottom to top: chat, fade + blur, header.", 912, 1696, 360, 640, 880, depth_root(), Exploded{650, 196, 156, 62})]
