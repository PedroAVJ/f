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
def fill(f: P.Fill) -> String:
  match f:
    case P.Fill.None{}: "transparent"
    case P.Solid{role, state}: T.surface(role, state, T.Scheme.Light{})
    case _: "transparent"
def bitmap_html(b: P.Bitmap) -> String:
  match b:
    case P.Bitmap.Photo{asset, width, height}:
      "<img alt=\"\" draggable=\"false\" src=\"" ++ escape(asset) ++ "\" width=\"" ++ U32.show(width) ++ "\" height=\"" ++ U32.show(height) ++ "\" style=\"display:block;width:100%;height:100%;object-fit:cover\">"
    case P.Bitmap.Atlas{N.Frame{id, asset, animation, time, reduced, row, column, x, y, width, height, sheet_width, sheet_height}}:
      "<svg width=\"100%\" height=\"100%\" viewBox=\"" ++ U32.show(x) ++ " " ++ U32.show(y) ++ " " ++ U32.show(width) ++ " " ++ U32.show(height) ++ "\" preserveAspectRatio=\"none\" aria-hidden=\"true\"><image href=\"" ++ escape(asset) ++ "\" width=\"" ++ U32.show(sheet_width) ++ "\" height=\"" ++ U32.show(sheet_height) ++ "\"/></svg>"
def fill_css(f: P.Fill) -> String:
  match f:
    case P.Fill.None{}: ""
    case P.Solid{role, state}: "--bend-fill:" ++ T.surface(role, state, T.Scheme.Light{}) ++ ";background:var(--bend-fill);"
    case P.Gradient{from, to, hold}:
      "background:linear-gradient(" ++ T.stop(from, T.Scheme.Light{}) ++ " " ++ U32.show(hold) ++ "% ," ++ T.stop(to, T.Scheme.Light{}) ++ ");"
    case _: ""
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
def stroke_css(s: P.Stroke) -> String:
  match s:
    case P.NoStroke{}: ""
    case P.Stroke{role, state, +width}:
      "inset 0 0 0 " ++ css_width(width) ++ "px " ++ T.line(role, state, T.Scheme.Light{})
def effect_css(e: P.Effect) -> String:
  match e:
    case P.Blur{+r}: "backdrop-filter:blur(" ++ U32.show(r) ++ "px);-webkit-backdrop-filter:blur(" ++ U32.show(r) ++ "px);"
    case P.Glass{blur, saturation, refraction, highlight, tint, edge, over}:
      "background-color:color-mix(in srgb,var(--bend-fill,transparent) " ++ U32.show(tint) ++ "%,transparent);background-image:linear-gradient(180deg,rgba(255,255,255," ++ F32.show(F32.div(U32.to_f32(highlight),100.0)) ++ ") 0%,rgba(255,255,255,0) 50%);backdrop-filter:blur(" ++ U32.show(blur) ++ "px) saturate(" ++ U32.show(saturation) ++ "%);"
    case _: ""
def shadow_css(e: P.Effect) -> String:
  match e:
    case P.Shadow{y, blur}: "0 " ++ U32.show(y) ++ "px " ++ U32.show(blur) ++ "px " ++ T.shadow()
    case P.Glass{blur, saturation, refraction, highlight, tint, edge, over}:
      "inset 0 0 0 0.5px " ++ T.line(edge,T.State.Rest{},T.Scheme.Light{})
    case _: ""
def effects_css(xs: List<&2, P.Effect>) -> String:
  match xs:
    case Nil{}: ""
    case Con{x, tail}: effect_css(x) ++ effects_css(tail)
def shadows(xs: List<&2, P.Effect>) -> String:
  match xs:
    case Nil{}: ""
    case Con{x, tail}: join(shadow_css(x), shadows(tail))
def style(+stroke: P.Stroke, +effects: List<&2, P.Effect>) -> String:
  effects_css(effects) ++ "box-shadow:" ++ join(stroke_css(stroke),shadows(effects)) ++ ";"
def symbol_shapes(xs: List<&2, S.Shape>) -> String:
  match xs:
    case Nil{}: ""
    case Con{S.Path{data}, tail}: "<path d=\"" ++ escape(data) ++ "\"/>" ++ symbol_shapes(tail)
    case Con{S.Circle{x, y, r}, tail}: "<circle cx=\"" ++ escape(x) ++ "\" cy=\"" ++ escape(y) ++ "\" r=\"" ++ escape(r) ++ "\"/>" ++ symbol_shapes(tail)
def svg_stroke(s: P.Stroke) -> String:
  match s:
    case P.NoStroke{}: "stroke=\"none\""
    case P.Stroke{role, state, +width}: "data-bend-stroke-width=\"" ++ escape(width) ++ "\" stroke=\"" ++ T.line(role,state,T.Scheme.Light{}) ++ "\" stroke-width=\"" ++ css_width(width) ++ "\""
def svg_bitmap(b: P.Bitmap) -> String:
  match b:
    case P.Bitmap.Photo{asset,+width,+height}:
      "viewBox=\"0 0 " ++ U32.show(width) ++ " " ++ U32.show(height) ++ "\" preserveAspectRatio=\"xMidYMid slice\"><image href=\"" ++ escape(asset) ++ "\" width=\"" ++ U32.show(width) ++ "\" height=\"" ++ U32.show(height) ++ "\"/>"
    case P.Bitmap.Atlas{N.Frame{id,asset,animation,time,reduced,row,column,x,y,width,height,sheet_width,sheet_height}}:
      "viewBox=\"" ++ U32.show(x) ++ " " ++ U32.show(y) ++ " " ++ U32.show(width) ++ " " ++ U32.show(height) ++ "\" preserveAspectRatio=\"none\"><image href=\"" ++ escape(asset) ++ "\" width=\"" ++ U32.show(sheet_width) ++ "\" height=\"" ++ U32.show(sheet_height) ++ "\"/>"
def svg_defs(f: P.Fill, id: U32) -> String:
  match f:
    case P.Gradient{+from,to,hold}:
      "<defs><linearGradient id=\"bend-fill-" ++ U32.show(id) ++ "\" x2=\"0\" y2=\"1\"><stop offset=\"0\" stop-color=\"" ++ T.stop(from,T.Scheme.Light{}) ++ "\"/><stop offset=\"" ++ U32.show(hold) ++ "%\" stop-color=\"" ++ T.stop(from,T.Scheme.Light{}) ++ "\"/><stop offset=\"1\" stop-color=\"" ++ T.stop(to,T.Scheme.Light{}) ++ "\"/></linearGradient></defs>"
    case P.Image{bitmap,time}:
      "<defs><pattern id=\"bend-fill-" ++ U32.show(id) ++ "\" width=\"1\" height=\"1\" " ++ svg_bitmap(bitmap) ++ "</pattern></defs>"
    case _: ""
def svg_fill(f: P.Fill, id: U32) -> String:
  match f:
    case P.Gradient{from,to,hold}: "url(#bend-fill-" ++ U32.show(id) ++ ")"
    case P.Image{bitmap,time}: "url(#bend-fill-" ++ U32.show(id) ++ ")"
    case _: fill(f)
def path_html(d: S.Drawing, +f: P.Fill, stroke: P.Stroke, +id: U32) -> String:
  match d:
    case S.Drawing{name, x, y, width, shapes}:
      "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" width=\"100%\" height=\"100%\" fill=\"" ++ svg_fill(f,id) ++ "\" " ++ svg_stroke(stroke) ++ " stroke-linecap=\"round\" stroke-linejoin=\"round\" role=\"img\" aria-label=\"" ++ escape(name) ++ "\">" ++ svg_defs(f,id) ++ symbol_shapes(shapes) ++ "</svg>"
def shape(s: P.Shape, head: String, id: U32) -> String:
  match s:
    case P.Shape{P.Text{text, P.TextType{name, size, weight}}, P.TextFill.Solid{role, state}, stroke, effects}:
      head ++ "color:" ++ T.text(role,state,T.Scheme.Light{}) ++ ";font-family:system-ui;font-size:" ++ U32.show(size) ++ "px;font-weight:" ++ U32.show(weight) ++ ";" ++ style(P.NoStroke{},effects) ++ "\">" ++ escape(text) ++ "</div>"
    case P.Shape{P.Rounded{+width, +height, r}, +f, +stroke, effects}:
      head ++ "width:" ++ U32.show(width) ++ "px;height:" ++ U32.show(height) ++ "px;border-radius:" ++ radius(r,width,height) ++ "px;overflow:hidden;" ++ fill_css(f) ++ style(stroke,effects) ++ "\" " ++ stroke_attr(stroke) ++ ">" ++ fill_html(f) ++ "</div>"
    case P.Shape{P.Path{drawing}, f, +stroke, effects}:
      head ++ style(P.NoStroke{},effects) ++ "\">" ++ path_html(drawing,f,stroke,id) ++ "</div>"
def box_at(b: P.Box, id: U32) -> String:
  match b:
    case P.Box{+name, P.Draw{s}, x, y, width, height, level, layer}:
      shape(s,"<div style=\"position:absolute;box-sizing:border-box;left:" ++ U32.show(x) ++ "px;top:" ++ U32.show(y) ++ "px;width:" ++ U32.show(width) ++ "px;height:" ++ U32.show(height) ++ "px;",id)
    case _: ""
def box(b: P.Box) -> String: box_at(b,0)
def boxes_at(xs: List<&2, P.Box>, +id: U32) -> String:
  match xs:
    case Nil{}: ""
    case Con{x, tail}: box_at(x,id) ++ boxes_at(tail,U32.inc(id))
def boxes(xs: List<&2, P.Box>) -> String: boxes_at(xs,0)
# Layout nodes retain the interactive regions and focus order declared by F.
def disabled(+name: String) -> Bool: String.starts_with(name,"button, disabled · ")
def region_label(+name: String) -> String:
  Bool.pick(String,String.starts_with(name,"button · "),String.drop(name,9n),Bool.pick(String,disabled(name),String.drop(name,19n),Bool.pick(String,String.starts_with(name,"textbox · "),String.drop(name,10n),name)))
def region_role(+name: String) -> String:
  Bool.pick(String,String.starts_with(name,"textbox · "),"textbox",Bool.pick(String,String.eq(name,"Field text"),"textbox","button"))
# A textbox is an input over its drawn text, which shows through: the input holds the whole value (the
# "value · " leaf F places first inside it) and sends each edit as a field event named after the box.
def textbox_html(+name: String, +value: String, +x: U32, +y: U32, +width: U32, +height: U32, +id: U32) -> String:
  "<input data-bend-field=\"" ++ escape(name) ++ "\" value=\"" ++ escape(value) ++ "\" aria-label=\"" ++ escape(region_label(name)) ++ "\" autocomplete=\"off\" spellcheck=\"false\" style=\"position:absolute;box-sizing:border-box;margin:0;border:0;outline:none;padding:0 16px;background:transparent;color:transparent;caret-color:#101112;font-family:system-ui;font-size:17px;left:" ++ U32.show(x) ++ "px;top:" ++ U32.show(y) ++ "px;width:" ++ U32.show(width) ++ "px;height:" ++ U32.show(height) ++ "px;z-index:" ++ U32.show(id) ++ "\">"
def value_of(+name: String) -> String:
  Bool.pick(String,String.starts_with(name,"value · "),String.drop(name,8n),"")
def region_html(b: P.Box, +id: U32, +value: String) -> String:
  match b:
    case P.Box{+name,mark,+x,+y,+width,+height,level,layer}:
      Bool.pick(String,String.starts_with(name,"textbox · "),textbox_html(name,value,x,y,width,height,id),
      "<button type=\"button\" data-bend-event=\"" ++ escape(name) ++ "\" aria-label=\"" ++ escape(region_label(name)) ++ "\" role=\"" ++ region_role(name) ++ "\" " ++ Bool.pick(String,String.eq(region_role(name),"textbox"),"aria-readonly=\"true\" ","") ++ Bool.pick(String,disabled(name),"disabled ","") ++ "style=\"position:absolute;border:0;padding:0;background:transparent;left:" ++ U32.show(x) ++ "px;top:" ++ U32.show(y) ++ "px;width:" ++ U32.show(width) ++ "px;height:" ++ U32.show(height) ++ "px;z-index:" ++ U32.show(id) ++ "\"></button>")
def region_at(xs: List<&2,P.Box>, +index: U32, id: U32, +value: String) -> String:
  match xs index:
    case Nil{} _: ""
    case Con{P.Box{name,P.Spacing{axis},x,y,w,h,level,layer},tail} _: region_at(tail,index,id,value)
    case Con{box,tail} 0: region_html(box,id,value)
    case Con{box,tail} _: region_at(tail,U32.sub(index,1),id,value)
# The name of the box at a pre-order index ("" past the end).
def name_at(xs: List<&2,P.Box>, +index: U32) -> String:
  match xs index:
    case Nil{} _: ""
    case Con{P.Box{name,P.Spacing{axis},x,y,w,h,level,layer},tail} _: name_at(tail,index)
    case Con{P.Box{name,mark,x,y,w,h,level,layer},tail} 0: name
    case Con{box,tail} _: name_at(tail,U32.sub(index,1))
def focus_html(+boxes: List<&2,P.Box>, order: List<&2,U32>) -> String:
  match order:
    case Nil{}: ""
    case Con{+index,tail}: region_at(boxes,index,index,value_of(name_at(boxes,U32.inc(index)))) ++ focus_html(boxes,tail)
def disabled_box(b: P.Box, id: U32) -> String:
  match b:
    case P.Box{+name,mark,x,y,w,h,level,layer}:
      Bool.pick(String,disabled(name),region_html(b,id,""),"")
def disabled_html(xs: List<&2,P.Box>, +index: U32) -> String:
  match xs:
    case Nil{}: ""
    case Con{P.Box{name,P.Spacing{axis},x,y,w,h,level,layer},tail}: disabled_html(tail,index)
    case Con{+box,tail}: disabled_box(box,index) ++ disabled_html(tail,U32.inc(index))
def html_frame(size: P.Size, children: String) -> String:
  match size:
    case P.Size{width,height,count}:
      "<div style=\"position:relative;width:" ++ U32.show(width) ++ "px;height:" ++ U32.show(height) ++ "px\">" ++ children ++ "</div>"
def html_boxes(size: P.Size, +placed: List<&2,P.Box>, order: List<&2,U32>) -> String:
  html_frame(size,boxes(placed) ++ focus_html(placed,order) ++ disabled_html(placed,0))
def placed(size: P.Size, tree: P.UI) -> List<&2,P.Box>:
  match size:
    case P.Size{+width,+height,count}: P.place(tree,P.Depth{},0,0,0,width,height,0,0,0)
def html(+tree: P.UI) -> String:
  html_boxes(P.size(tree),placed(P.size(tree),tree),P.focus_order(tree))

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
def fill_json(f: P.Fill) -> String:
  match f:
    case P.Fill.None{}: "[\"none\"]"
    case P.Solid{role,state}: "[\"solid\"," ++ J.quote(T.surface(role,state,T.Scheme.Light{})) ++ "]"
    case P.Gradient{from,to,hold}: "[\"gradient\"," ++ J.quote(T.stop(from,T.Scheme.Light{})) ++ "," ++ J.quote(T.stop(to,T.Scheme.Light{})) ++ "," ++ U32.show(hold) ++ "]"
    case P.Image{bitmap,time}: bitmap_json(bitmap)
def stroke_json(s: P.Stroke) -> String:
  match s:
    case P.NoStroke{}: "[\"none\"]"
    case P.Stroke{role,state,width}: "[\"stroke\"," ++ J.quote(T.line(role,state,T.Scheme.Light{})) ++ "," ++ J.quote(width) ++ "]"
def effect_json(e: P.Effect) -> String:
  match e:
    case P.Blur{r}: "[\"blur\"," ++ U32.show(r) ++ "]"
    case P.Shadow{y,blur}: "[\"shadow\"," ++ U32.show(y) ++ "," ++ U32.show(blur) ++ "," ++ J.quote(T.shadow()) ++ "]"
    case P.Glass{blur,saturation,refraction,highlight,tint,edge,over}:
      "[\"glass\"," ++ U32.show(blur) ++ "," ++ U32.show(saturation) ++ "," ++ U32.show(refraction) ++ "," ++ U32.show(highlight) ++ "," ++ U32.show(tint) ++ "," ++ J.quote(T.line(edge,T.State.Rest{},T.Scheme.Light{})) ++ "]"
def effect_commands(xs: List<&2, P.Effect>) -> String:
  match xs:
    case Nil{}: ""
    case Con{x,tail}: join(effect_json(x),effect_commands(tail))
def paint(s: P.Shape, head: String) -> String:
  match s:
    case P.Shape{P.Text{text,P.TextType{name,size,weight}},P.TextFill.Solid{role,state},stroke,effects}:
      head ++ "[\"text\"," ++ J.quote(text) ++ "," ++ U32.show(size) ++ "," ++ U32.show(weight) ++ "],[\"solid\"," ++ J.quote(T.text(role,state,T.Scheme.Light{})) ++ "]," ++ stroke_json(stroke) ++ ",[" ++ effect_commands(effects) ++ "]]"
    case P.Shape{P.Rounded{+w,+h,r},f,stroke,effects}:
      head ++ "[\"rounded\"," ++ U32.show(w) ++ "," ++ U32.show(h) ++ "," ++ radius(r,w,h) ++ "]," ++ fill_json(f) ++ "," ++ stroke_json(stroke) ++ ",[" ++ effect_commands(effects) ++ "]]"
    case P.Shape{P.Path{d},f,stroke,effects}:
      head ++ drawing_json(d) ++ "," ++ fill_json(f) ++ "," ++ stroke_json(stroke) ++ ",[" ++ effect_commands(effects) ++ "]]"
def command(b: P.Box) -> String:
  match b:
    case P.Box{name,P.Draw{s},x,y,width,height,level,layer}:
      paint(s,"[\"shape\"," ++ J.quote(name) ++ "," ++ U32.show(x) ++ "," ++ U32.show(y) ++ "," ++ U32.show(width) ++ "," ++ U32.show(height) ++ ",")
    case _: ""
def commands(xs: List<&2, P.Box>) -> String:
  match xs:
    case Nil{}: ""
    case Con{x,tail}: join(command(x),commands(tail))
def region_json(b: P.Box) -> String:
  match b:
    case P.Box{+name,mark,x,y,w,h,level,layer}:
      Bool.pick(String,Bool.or(P.interactive(name),disabled(name)),"[\"region\"," ++ J.quote(name) ++ "," ++ U32.show(x) ++ "," ++ U32.show(y) ++ "," ++ U32.show(w) ++ "," ++ U32.show(h) ++ "," ++ Bool.pick(String,disabled(name),"false","true") ++ "]","")
def region_commands(xs: List<&2,P.Box>) -> String:
  match xs:
    case Nil{}: ""
    case Con{box,tail}: join(region_json(box),region_commands(tail))
def canvas_commands(+placed: List<&2,P.Box>) -> String:
  join("[\"clear\"]",join(commands(placed),region_commands(placed)))
def canvas_frame(size: P.Size, placed: List<&2,P.Box>) -> String:
  match size:
    case P.Size{width,height,count}: "[" ++ join("[\"frame\"," ++ U32.show(width) ++ "," ++ U32.show(height) ++ "]",canvas_commands(placed)) ++ "]"
def canvas(+tree: P.UI) -> String: canvas_frame(P.size(tree),placed(P.size(tree),tree))
