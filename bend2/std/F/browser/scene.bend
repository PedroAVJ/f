import Base
import ../ui/primitives.bend as P
import ../ui/tokens.bend as T
import ../ui/symbols.bend as S
import ../ui/nearling.bend as N
import ../ai/wire_json.bend as J

# Private projection of positioned F values. Layout, token resolution, state
# and sprite sampling stay in Bend/Wasm; the host paints these transient values.
def char(c: U32) -> String:
  match c:
    case 38: "&amp;"
    case 60: "&lt;"
    case 62: "&gt;"
    case 34: "&quot;"
    case 39: "&#39;"
    case _: SCon{Chr{c}, SNil{}}
def escape(s: String) -> String:
  match s:
    case SNil{}: ""
    case SCon{Chr{c}, tail}: char(c) ++ escape(tail)
def join_checked(empty_a: Bool, empty_b: Bool, a: String, b: String) -> String:
  match empty_a empty_b:
    case True{} _: b
    case _ True{}: a
    case _ _: a ++ "," ++ b
def join(+a: String, +b: String) -> String:
  join_checked(String.is_empty(a), String.is_empty(b), a, b)
def radius(r: P.Radius, +width: U32, +height: U32) -> String:
  match r:
    case P.Corner{n}: U32.show(n)
    case P.Full{}:
      +side = U32.min(width,height)
      U32.show(U32.div(side,2)) ++ Bool.pick(String,U32.is_zero(U32.mod(side,2)),"",".5")
def fill_in(f: P.Fill, +scheme: T.Scheme) -> String:
  match f:
    case P.Fill.None{}: "transparent"
    case P.Solid{role, state}: T.surface(role, state, scheme)
    case _: "transparent"
def fill(f: P.Fill) -> String: fill_in(f,T.Scheme.Light{})
def bitmap_html(b: P.Bitmap) -> String:
  match b:
    case P.Bitmap.Photo{asset, width, height}:
      "<img alt=\"\" draggable=\"false\" src=\"" ++ escape(asset) ++ "\" width=\"" ++ U32.show(width) ++ "\" height=\"" ++ U32.show(height) ++ "\" style=\"display:block;width:100%;height:100%;object-fit:cover\">"
    case P.Bitmap.Atlas{N.Frame{id, asset, animation, time, reduced, row, column, x, y, width, height, sheet_width, sheet_height}}:
      "<svg width=\"100%\" height=\"100%\" viewBox=\"" ++ U32.show(x) ++ " " ++ U32.show(y) ++ " " ++ U32.show(width) ++ " " ++ U32.show(height) ++ "\" preserveAspectRatio=\"none\" aria-hidden=\"true\"><image href=\"" ++ escape(asset) ++ "\" width=\"" ++ U32.show(sheet_width) ++ "\" height=\"" ++ U32.show(sheet_height) ++ "\"/></svg>"
def fill_css_in(f: P.Fill, +scheme: T.Scheme) -> String:
  match f:
    case P.Fill.None{}: ""
    case P.Solid{role, state}: "--bend-fill:" ++ T.surface(role, state, scheme) ++ ";background:var(--bend-fill);"
    case P.Gradient{from, to, hold}:
      "background:linear-gradient(" ++ T.stop(from, scheme) ++ " " ++ U32.show(hold) ++ "% ," ++ T.stop(to, scheme) ++ ");"
    case _: ""
def fill_css(f: P.Fill) -> String: fill_css_in(f,T.Scheme.Light{})
def fill_html(f: P.Fill) -> String:
  match f:
    case P.Image{bitmap, time}: bitmap_html(bitmap)
    case _: ""
# CSS lengths cross only as non-negative decimal numbers. Invalid widths are
# harmless in generated markup and rejected by the host before insertion.
def width_digits(s: String, digit: Bool) -> Bool:
  match s:
    case SNil{}: digit
    case SCon{Chr{+c},tail}: Bool.and(Bool.and(U32.is_ge(c,48),U32.is_le(c,57)),width_digits(tail,True{}))
def width_exponent(s: String) -> Bool:
  match s:
    case SCon{Chr{43},tail}: width_digits(tail,False{})
    case SCon{Chr{45},tail}: width_digits(tail,False{})
    case _: width_digits(s,False{})
def width_valid(s: String, +dot: Bool, +digit: Bool) -> Bool:
  match s:
    case SNil{}: digit
    case SCon{Chr{46},tail}: Bool.and(Bool.not(dot),width_valid(tail,True{},digit))
    case SCon{Chr{69},tail}: Bool.and(digit,width_exponent(tail))
    case SCon{Chr{101},tail}: Bool.and(digit,width_exponent(tail))
    case SCon{Chr{+c},tail}: Bool.and(Bool.and(U32.is_ge(c,48),U32.is_le(c,57)),width_valid(tail,dot,True{}))
def width_start(s: String) -> Bool:
  match s:
    case SCon{Chr{43},tail}: width_valid(tail,False{},False{})
    case _: width_valid(s,False{},False{})
def css_width(+width: String) -> String:
  Bool.pick(String,width_start(width),width,"0")
def stroke_attr(s: P.Stroke) -> String:
  match s:
    case P.NoStroke{}: ""
    case P.Stroke{role,state,width}: "data-bend-stroke-width=\"" ++ escape(width) ++ "\" "
def stroke_css_in(s: P.Stroke, +scheme: T.Scheme) -> String:
  match s:
    case P.NoStroke{}: ""
    case P.Stroke{role, state, +width}:
      "inset 0 0 0 " ++ css_width(width) ++ "px " ++ T.line(role, state, scheme)
def stroke_css(s: P.Stroke) -> String: stroke_css_in(s,T.Scheme.Light{})
def effect_css(e: P.Effect) -> String:
  match e:
    case P.Blur{+r}: "backdrop-filter:blur(" ++ U32.show(r) ++ "px);-webkit-backdrop-filter:blur(" ++ U32.show(r) ++ "px);"
    case P.Glass{blur, saturation, refraction, highlight, tint, edge, over}:
      "background-color:color-mix(in srgb,var(--bend-fill,transparent) " ++ U32.show(tint) ++ "%,transparent);background-image:linear-gradient(180deg,rgba(255,255,255," ++ F32.show(F32.div(U32.to_f32(highlight),100.0)) ++ ") 0%,rgba(255,255,255,0) 50%);backdrop-filter:blur(" ++ U32.show(blur) ++ "px) saturate(" ++ U32.show(saturation) ++ "%);"
    case _: ""
def shadow_css_in(e: P.Effect, +scheme: T.Scheme) -> String:
  match e:
    case P.Shadow{y, blur}: "0 " ++ U32.show(y) ++ "px " ++ U32.show(blur) ++ "px " ++ T.shadow()
    case P.Glass{blur, saturation, refraction, highlight, tint, edge, over}:
      "inset 0 0 0 0.5px " ++ T.line(edge,T.State.Rest{},scheme)
    case _: ""
def shadow_css(e: P.Effect) -> String: shadow_css_in(e,T.Scheme.Light{})
def effects_css(xs: List<&2, P.Effect>) -> String:
  match xs:
    case Nil{}: ""
    case Con{x, tail}: effect_css(x) ++ effects_css(tail)
def shadows_in(xs: List<&2, P.Effect>, +scheme: T.Scheme) -> String:
  match xs:
    case Nil{}: ""
    case Con{x, tail}: join(shadow_css_in(x,scheme), shadows_in(tail,scheme))
def shadows(xs: List<&2, P.Effect>) -> String: shadows_in(xs,T.Scheme.Light{})
def style_in(+stroke: P.Stroke, +effects: List<&2, P.Effect>, +scheme: T.Scheme) -> String:
  effects_css(effects) ++ "box-shadow:" ++ join(stroke_css_in(stroke,scheme),shadows_in(effects,scheme)) ++ ";"
def style(+stroke: P.Stroke, +effects: List<&2, P.Effect>) -> String: style_in(stroke,effects,T.Scheme.Light{})
def symbol_shapes(xs: List<&2, S.Shape>) -> String:
  match xs:
    case Nil{}: ""
    case Con{S.Path{data}, tail}: "<path d=\"" ++ escape(data) ++ "\"/>" ++ symbol_shapes(tail)
    case Con{S.Circle{x, y, r}, tail}: "<circle cx=\"" ++ escape(x) ++ "\" cy=\"" ++ escape(y) ++ "\" r=\"" ++ escape(r) ++ "\"/>" ++ symbol_shapes(tail)
def svg_stroke_in(s: P.Stroke, +scheme: T.Scheme) -> String:
  match s:
    case P.NoStroke{}: "stroke=\"none\""
    case P.Stroke{role, state, +width}: "data-bend-stroke-width=\"" ++ escape(width) ++ "\" stroke=\"" ++ T.line(role,state,scheme) ++ "\" stroke-width=\"" ++ css_width(width) ++ "\""
def svg_stroke(s: P.Stroke) -> String: svg_stroke_in(s,T.Scheme.Light{})
def svg_bitmap(b: P.Bitmap) -> String:
  match b:
    case P.Bitmap.Photo{asset,+width,+height}:
      "viewBox=\"0 0 " ++ U32.show(width) ++ " " ++ U32.show(height) ++ "\" preserveAspectRatio=\"xMidYMid slice\"><image href=\"" ++ escape(asset) ++ "\" width=\"" ++ U32.show(width) ++ "\" height=\"" ++ U32.show(height) ++ "\"/>"
    case P.Bitmap.Atlas{N.Frame{id,asset,animation,time,reduced,row,column,x,y,width,height,sheet_width,sheet_height}}:
      "viewBox=\"" ++ U32.show(x) ++ " " ++ U32.show(y) ++ " " ++ U32.show(width) ++ " " ++ U32.show(height) ++ "\" preserveAspectRatio=\"none\"><image href=\"" ++ escape(asset) ++ "\" width=\"" ++ U32.show(sheet_width) ++ "\" height=\"" ++ U32.show(sheet_height) ++ "\"/>"
def svg_defs_in(f: P.Fill, id: U32, +scheme: T.Scheme) -> String:
  match f:
    case P.Gradient{+from,to,hold}:
      "<defs><linearGradient id=\"bend-fill-" ++ U32.show(id) ++ "\" x2=\"0\" y2=\"1\"><stop offset=\"0\" stop-color=\"" ++ T.stop(from,scheme) ++ "\"/><stop offset=\"" ++ U32.show(hold) ++ "%\" stop-color=\"" ++ T.stop(from,scheme) ++ "\"/><stop offset=\"1\" stop-color=\"" ++ T.stop(to,scheme) ++ "\"/></linearGradient></defs>"
    case P.Image{bitmap,time}:
      "<defs><pattern id=\"bend-fill-" ++ U32.show(id) ++ "\" width=\"1\" height=\"1\" " ++ svg_bitmap(bitmap) ++ "</pattern></defs>"
    case _: ""
def svg_defs(f: P.Fill, id: U32) -> String: svg_defs_in(f,id,T.Scheme.Light{})
def svg_fill_in(f: P.Fill, id: U32, +scheme: T.Scheme) -> String:
  match f:
    case P.Gradient{from,to,hold}: "url(#bend-fill-" ++ U32.show(id) ++ ")"
    case P.Image{bitmap,time}: "url(#bend-fill-" ++ U32.show(id) ++ ")"
    case _: fill_in(f,scheme)
def svg_fill(f: P.Fill, id: U32) -> String: svg_fill_in(f,id,T.Scheme.Light{})
def path_html_in(d: S.Drawing, +f: P.Fill, stroke: P.Stroke, +id: U32, +scheme: T.Scheme) -> String:
  match d:
    case S.Drawing{name, x, y, width, shapes}:
      "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" width=\"100%\" height=\"100%\" fill=\"" ++ svg_fill_in(f,id,scheme) ++ "\" " ++ svg_stroke_in(stroke,scheme) ++ " stroke-linecap=\"round\" stroke-linejoin=\"round\" role=\"img\" aria-label=\"" ++ escape(name) ++ "\">" ++ svg_defs_in(f,id,scheme) ++ symbol_shapes(shapes) ++ "</svg>"
def path_html(d: S.Drawing, +f: P.Fill, stroke: P.Stroke, +id: U32) -> String: path_html_in(d,f,stroke,id,T.Scheme.Light{})
def shape_in(s: P.Shape, head: String, id: U32, +scheme: T.Scheme) -> String:
  match s:
    case P.Shape{P.Text{text, P.TextType{name, size, weight}}, P.TextFill.Solid{role, state}, stroke, effects}:
      head ++ "color:" ++ T.text(role,state,scheme) ++ ";white-space:pre;font-family:system-ui;font-size:" ++ U32.show(size) ++ "px;font-weight:" ++ U32.show(weight) ++ ";" ++ style_in(P.NoStroke{},effects,scheme) ++ "\">" ++ escape(text) ++ "</div>"
    case P.Shape{P.Rounded{+width, +height, r}, +f, +stroke, effects}:
      head ++ "width:" ++ U32.show(width) ++ "px;height:" ++ U32.show(height) ++ "px;border-radius:" ++ radius(r,width,height) ++ "px;overflow:hidden;" ++ fill_css_in(f,scheme) ++ style_in(stroke,effects,scheme) ++ "\" " ++ stroke_attr(stroke) ++ ">" ++ fill_html(f) ++ "</div>"
    case P.Shape{P.Path{drawing}, f, +stroke, effects}:
      head ++ style_in(P.NoStroke{},effects,scheme) ++ "\">" ++ path_html_in(drawing,f,stroke,id,scheme) ++ "</div>"
def shape(s: P.Shape, head: String, id: U32) -> String: shape_in(s,head,id,T.Scheme.Light{})
def box_at_in(b: P.Box, id: U32, +scheme: T.Scheme) -> String:
  match b:
    case P.Box{+name, P.Draw{s}, x, y, width, height, level, layer}:
      shape_in(s,"<div style=\"position:absolute;box-sizing:border-box;left:" ++ U32.show(x) ++ "px;top:" ++ U32.show(y) ++ "px;width:" ++ U32.show(width) ++ "px;height:" ++ U32.show(height) ++ "px;",id,scheme)
    case _: ""
def box_at(b: P.Box, id: U32) -> String: box_at_in(b,id,T.Scheme.Light{})
def box_in(b: P.Box, +scheme: T.Scheme) -> String: box_at_in(b,0,scheme)
def box(b: P.Box) -> String: box_in(b,T.Scheme.Light{})
def boxes_at_in(xs: List<&2, P.Box>, +id: U32, +scheme: T.Scheme) -> String:
  match xs:
    case Nil{}: ""
    case Con{x, tail}: box_at_in(x,id,scheme) ++ boxes_at_in(tail,U32.inc(id),scheme)
def boxes_at(xs: List<&2, P.Box>, +id: U32) -> String: boxes_at_in(xs,id,T.Scheme.Light{})
def boxes_in(xs: List<&2, P.Box>, +scheme: T.Scheme) -> String: boxes_at_in(xs,0,scheme)
def boxes(xs: List<&2, P.Box>) -> String: boxes_in(xs,T.Scheme.Light{})
# Layout nodes retain the interactive regions and focus order declared by F.
def disabled(+name: String) -> Bool: String.starts_with(name,"button, disabled · ") || String.starts_with(name,"textbox, disabled · ")
def textbox_name(+name: String) -> Bool: String.starts_with(name,"textbox · ") || String.starts_with(name,"textbox, disabled · ")
def event_part(parts: List<&2, String>) -> String:
  match parts:
    case []: ""
    case action <> rest: action
def region_event(+name: String) -> String:
  Bool.pick(String, String.starts_with(name, "button · ") || textbox_name(name) || disabled(name), event_part(String.split(name, '\t')), name)
def region_label(+name: String) -> String:
  Bool.pick(String, (String.starts_with(name, "button · ") || textbox_name(name) || disabled(name)) && String.contains(name, "\t"),
    String.join(List.drop(&2, String, String.split(name, '\t'), 1n), "\t"),
    Bool.pick(String,String.starts_with(name,"button · "),String.drop(name,9n),Bool.pick(String,String.starts_with(name,"button, disabled · "),String.drop(name,19n),Bool.pick(String,String.starts_with(name,"textbox, disabled · "),String.drop(name,20n),Bool.pick(String,textbox_name(name),String.drop(name,10n),name)))))
def region_role(+name: String) -> String:
  Bool.pick(String,textbox_name(name),"textbox",Bool.pick(String,String.eq(name,"Field text"),"textbox","button"))
# A textbox is an input over its drawn text, which shows through: the input holds the whole value (the
# "value · " leaf F places first inside it) and sends each edit as a field event named after the box.
def textbox_html_in(+name: String, +value: String, +x: U32, +y: U32, +width: U32, +height: U32, +id: U32, +scheme: T.Scheme) -> String:
  "<input data-bend-field=\"" ++ escape(region_event(name)) ++ "\" value=\"" ++ escape(value) ++ "\" aria-label=\"" ++ escape(region_label(name)) ++ "\"" ++ Bool.pick(String, disabled(name), " disabled", "") ++ " autocomplete=\"off\" spellcheck=\"false\" style=\"position:absolute;box-sizing:border-box;margin:0;border:0;outline:none;padding:0 16px;background:transparent;color:transparent;caret-color:" ++ T.text(T.TextRole.Ink{},T.State.Rest{},scheme) ++ ";font-family:system-ui;font-size:17px;left:" ++ U32.show(x) ++ "px;top:" ++ U32.show(y) ++ "px;width:" ++ U32.show(width) ++ "px;height:" ++ U32.show(height) ++ "px;z-index:" ++ U32.show(id) ++ "\">"
def textbox_html(+name: String, +value: String, +x: U32, +y: U32, +width: U32, +height: U32, +id: U32) -> String: textbox_html_in(name,value,x,y,width,height,id,T.Scheme.Light{})
def value_of(+name: String) -> String:
  Bool.pick(String,String.starts_with(name,"value · "),String.drop(name,8n),"")
def region_html_in(b: P.Box, +id: U32, +value: String, +scheme: T.Scheme) -> String:
  match b:
    case P.Box{+name,mark,+x,+y,+width,+height,level,layer}:
      Bool.pick(String,textbox_name(name),textbox_html_in(name,value,x,y,width,height,id,scheme),
      "<button type=\"button\" data-bend-event=\"" ++ escape(region_event(name)) ++ "\" aria-label=\"" ++ escape(region_label(name)) ++ "\" role=\"" ++ region_role(name) ++ "\" " ++ Bool.pick(String,String.eq(region_role(name),"textbox"),"aria-readonly=\"true\" ","") ++ Bool.pick(String,disabled(name),"disabled ","") ++ "style=\"position:absolute;border:0;padding:0;background:transparent;left:" ++ U32.show(x) ++ "px;top:" ++ U32.show(y) ++ "px;width:" ++ U32.show(width) ++ "px;height:" ++ U32.show(height) ++ "px;z-index:" ++ U32.show(id) ++ "\"></button>")
def region_html(b: P.Box, +id: U32, +value: String) -> String: region_html_in(b,id,value,T.Scheme.Light{})
def region_at_in(xs: List<&2,P.Box>, +index: U32, id: U32, +value: String, +scheme: T.Scheme) -> String:
  match xs index:
    case Nil{} _: ""
    case Con{P.Box{name,P.Spacing{axis},x,y,w,h,level,layer},tail} _: region_at_in(tail,index,id,value,scheme)
    case Con{box,tail} 0: region_html_in(box,id,value,scheme)
    case Con{box,tail} _: region_at_in(tail,U32.sub(index,1),id,value,scheme)
def region_at(xs: List<&2,P.Box>, +index: U32, id: U32, +value: String) -> String: region_at_in(xs,index,id,value,T.Scheme.Light{})
# The name of the box at a pre-order index ("" past the end).
def name_at(xs: List<&2,P.Box>, +index: U32) -> String:
  match xs index:
    case Nil{} _: ""
    case Con{P.Box{name,P.Spacing{axis},x,y,w,h,level,layer},tail} _: name_at(tail,index)
    case Con{P.Box{name,mark,x,y,w,h,level,layer},tail} 0: name
    case Con{box,tail} _: name_at(tail,U32.sub(index,1))
def focus_html_in(+boxes: List<&2,P.Box>, order: List<&2,U32>, +scheme: T.Scheme) -> String:
  match order:
    case Nil{}: ""
    case Con{+index,tail}: region_at_in(boxes,index,index,value_of(name_at(boxes,U32.inc(index))),scheme) ++ focus_html_in(boxes,tail,scheme)
def focus_html(+boxes: List<&2,P.Box>, order: List<&2,U32>) -> String: focus_html_in(boxes,order,T.Scheme.Light{})
def disabled_box_in(b: P.Box, id: U32, +scheme: T.Scheme) -> String:
  match b:
    case P.Box{+name,mark,x,y,w,h,level,layer}:
      Bool.pick(String,disabled(name),region_html_in(b,id,"",scheme),"")
def disabled_box(b: P.Box, id: U32) -> String: disabled_box_in(b,id,T.Scheme.Light{})
def disabled_html_in(xs: List<&2,P.Box>, +index: U32, +scheme: T.Scheme) -> String:
  match xs:
    case Nil{}: ""
    case Con{P.Box{name,P.Spacing{axis},x,y,w,h,level,layer},tail}: disabled_html_in(tail,index,scheme)
    case Con{+box,tail}: disabled_box_in(box,index,scheme) ++ disabled_html_in(tail,U32.inc(index),scheme)
def disabled_html(xs: List<&2,P.Box>, +index: U32) -> String: disabled_html_in(xs,index,T.Scheme.Light{})
def html_frame(size: P.Size, children: String) -> String:
  match size:
    case P.Size{width,height,count}:
      "<div style=\"position:relative;width:" ++ U32.show(width) ++ "px;height:" ++ U32.show(height) ++ "px\">" ++ children ++ "</div>"
def html_boxes_in(size: P.Size, +placed: List<&2,P.Box>, order: List<&2,U32>, +scheme: T.Scheme) -> String:
  html_frame(size,boxes_in(placed,scheme) ++ focus_html_in(placed,order,scheme) ++ disabled_html_in(placed,0,scheme))
def html_boxes(size: P.Size, +placed: List<&2,P.Box>, order: List<&2,U32>) -> String: html_boxes_in(size,placed,order,T.Scheme.Light{})
def placed(size: P.Size, tree: P.UI) -> List<&2,P.Box>:
  match size:
    case P.Size{+width,+height,count}: P.place(tree,P.Depth{},0,0,0,width,height,0,0,0)
def html_in(+tree: P.UI, +scheme: T.Scheme) -> String:
  html_boxes_in(P.size(tree),placed(P.size(tree),tree),P.focus_order(tree),scheme)
def html(+tree: P.UI) -> String: html_in(tree,T.Scheme.Light{})

# A closed paint packet: the JS shell only applies browser drawing operations.
def symbol_commands(xs: List<&2, S.Shape>) -> String:
  match xs:
    case Nil{}: ""
    case Con{S.Path{data}, tail}: join("[\"path\"," ++ J.quote(data) ++ "]",symbol_commands(tail))
    case Con{S.Circle{x,y,r}, tail}: join("[\"circle\"," ++ J.quote(x) ++ "," ++ J.quote(y) ++ "," ++ J.quote(r) ++ "]",symbol_commands(tail))
def symbol_json(xs: List<&2, S.Shape>) -> String:
  "[" ++ symbol_commands(xs) ++ "]"
def drawing_json(d: S.Drawing) -> String:
  match d:
    case S.Drawing{name, x, y, width, shapes}: "[\"path\"," ++ symbol_json(shapes) ++ "]"
def bitmap_json(b: P.Bitmap) -> String:
  match b:
    case P.Bitmap.Photo{asset,width,height}: "[\"photo\"," ++ J.quote(asset) ++ "," ++ U32.show(width) ++ "," ++ U32.show(height) ++ "]"
    case P.Bitmap.Atlas{N.Frame{id,asset,animation,time,reduced,row,column,x,y,width,height,sheet_width,sheet_height}}:
      "[\"atlas\"," ++ J.quote(asset) ++ "," ++ U32.show(x) ++ "," ++ U32.show(y) ++ "," ++ U32.show(width) ++ "," ++ U32.show(height) ++ "," ++ U32.show(sheet_width) ++ "," ++ U32.show(sheet_height) ++ "]"
def fill_json_in(f: P.Fill, +scheme: T.Scheme) -> String:
  match f:
    case P.Fill.None{}: "[\"none\"]"
    case P.Solid{role,state}: "[\"solid\"," ++ J.quote(T.surface(role,state,scheme)) ++ "]"
    case P.Gradient{from,to,hold}: "[\"gradient\"," ++ J.quote(T.stop(from,scheme)) ++ "," ++ J.quote(T.stop(to,scheme)) ++ "," ++ U32.show(hold) ++ "]"
    case P.Image{bitmap,time}: bitmap_json(bitmap)
def fill_json(f: P.Fill) -> String: fill_json_in(f,T.Scheme.Light{})
def stroke_json_in(s: P.Stroke, scheme: T.Scheme) -> String:
  match s:
    case P.NoStroke{}: "[\"none\"]"
    case P.Stroke{role,state,width}: "[\"stroke\"," ++ J.quote(T.line(role,state,scheme)) ++ "," ++ J.quote(width) ++ "]"
def stroke_json(s: P.Stroke) -> String: stroke_json_in(s,T.Scheme.Light{})
def effect_json_in(e: P.Effect, scheme: T.Scheme) -> String:
  match e:
    case P.Blur{r}: "[\"blur\"," ++ U32.show(r) ++ "]"
    case P.Shadow{y,blur}: "[\"shadow\"," ++ U32.show(y) ++ "," ++ U32.show(blur) ++ "," ++ J.quote(T.shadow()) ++ "]"
    case P.Glass{blur,saturation,refraction,highlight,tint,edge,over}:
      "[\"glass\"," ++ U32.show(blur) ++ "," ++ U32.show(saturation) ++ "," ++ U32.show(refraction) ++ "," ++ U32.show(highlight) ++ "," ++ U32.show(tint) ++ "," ++ J.quote(T.line(edge,T.State.Rest{},scheme)) ++ "]"
def effect_json(e: P.Effect) -> String: effect_json_in(e,T.Scheme.Light{})
def effect_commands_in(xs: List<&2, P.Effect>, +scheme: T.Scheme) -> String:
  match xs:
    case Nil{}: ""
    case Con{x,tail}: join(effect_json_in(x,scheme),effect_commands_in(tail,scheme))
def effect_commands(xs: List<&2, P.Effect>) -> String: effect_commands_in(xs,T.Scheme.Light{})
def paint_in(s: P.Shape, head: String, +scheme: T.Scheme) -> String:
  match s:
    case P.Shape{P.Text{text,P.TextType{name,size,weight}},P.TextFill.Solid{role,state},stroke,effects}:
      head ++ "[\"text\"," ++ J.quote(text) ++ "," ++ U32.show(size) ++ "," ++ U32.show(weight) ++ "],[\"solid\"," ++ J.quote(T.text(role,state,scheme)) ++ "]," ++ stroke_json_in(stroke,scheme) ++ ",[" ++ effect_commands_in(effects,scheme) ++ "]]"
    case P.Shape{P.Rounded{+w,+h,r},f,stroke,effects}:
      head ++ "[\"rounded\"," ++ U32.show(w) ++ "," ++ U32.show(h) ++ "," ++ radius(r,w,h) ++ "]," ++ fill_json_in(f,scheme) ++ "," ++ stroke_json_in(stroke,scheme) ++ ",[" ++ effect_commands_in(effects,scheme) ++ "]]"
    case P.Shape{P.Path{d},f,stroke,effects}:
      head ++ drawing_json(d) ++ "," ++ fill_json_in(f,scheme) ++ "," ++ stroke_json_in(stroke,scheme) ++ ",[" ++ effect_commands_in(effects,scheme) ++ "]]"
def paint(s: P.Shape, head: String) -> String: paint_in(s,head,T.Scheme.Light{})
def command_in(b: P.Box, scheme: T.Scheme) -> String:
  match b:
    case P.Box{name,P.Draw{s},x,y,width,height,level,layer}:
      paint_in(s,"[\"shape\"," ++ J.quote(name) ++ "," ++ U32.show(x) ++ "," ++ U32.show(y) ++ "," ++ U32.show(width) ++ "," ++ U32.show(height) ++ ",",scheme)
    case _: ""
def command(b: P.Box) -> String: command_in(b,T.Scheme.Light{})
def commands_in(xs: List<&2, P.Box>, +scheme: T.Scheme) -> String:
  match xs:
    case Nil{}: ""
    case Con{x,tail}: join(command_in(x,scheme),commands_in(tail,scheme))
def commands(xs: List<&2, P.Box>) -> String: commands_in(xs,T.Scheme.Light{})
def region_json(b: P.Box) -> String:
  match b:
    case P.Box{+name,mark,x,y,w,h,level,layer}:
      Bool.pick(String,Bool.or(P.interactive(name),disabled(name)),"[\"region\"," ++ J.quote(name) ++ "," ++ U32.show(x) ++ "," ++ U32.show(y) ++ "," ++ U32.show(w) ++ "," ++ U32.show(h) ++ "," ++ Bool.pick(String,disabled(name),"false","true") ++ "]","")
def region_commands(xs: List<&2,P.Box>) -> String:
  match xs:
    case Nil{}: ""
    case Con{box,tail}: join(region_json(box),region_commands(tail))
def canvas_commands_under(+placed: List<&2,P.Box>, background: String, scheme: T.Scheme) -> String:
  join("[\"clear\"]",join(background,join(commands_in(placed,scheme),region_commands(placed))))
def canvas_commands_in(placed: List<&2,P.Box>, scheme: T.Scheme) -> String:
  canvas_commands_under(placed,"",scheme)
def canvas_commands(placed: List<&2,P.Box>) -> String: canvas_commands_in(placed,T.Scheme.Light{})
# Dark Canvas needs its own opaque background after clear, including empty
# layout space. Light keeps the original transparent packet byte for byte.
def canvas_background(+width: U32, +height: U32, scheme: T.Scheme) -> String:
  match scheme:
    case T.Scheme.Light{}: ""
    case T.Scheme.Dark{}:
      "[\"shape\",\"Canvas background\",0,0," ++ U32.show(width) ++ "," ++ U32.show(height) ++ ",[\"rounded\"," ++ U32.show(width) ++ "," ++ U32.show(height) ++ ",0],[\"solid\"," ++ J.quote(T.surface(T.SurfaceRole.Background{},T.State.Rest{},T.Scheme.Dark{})) ++ "],[\"none\"],[]]"
def canvas_frame_in(size: P.Size, placed: List<&2,P.Box>, +scheme: T.Scheme) -> String:
  match size:
    case P.Size{+width,+height,count}: "[" ++ join("[\"frame\"," ++ U32.show(width) ++ "," ++ U32.show(height) ++ "]",canvas_commands_under(placed,canvas_background(width,height,scheme),scheme)) ++ "]"
def canvas_frame(size: P.Size, placed: List<&2,P.Box>) -> String: canvas_frame_in(size,placed,T.Scheme.Light{})
# Scheme selection is explicit; the existing canvas remains the Light packet.
def canvas_in(+tree: P.UI, scheme: T.Scheme) -> String: canvas_frame_in(P.size(tree),placed(P.size(tree),tree),scheme)
def canvas(tree: P.UI) -> String: canvas_in(tree,T.Scheme.Light{})
