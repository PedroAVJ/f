import Base

# Colour tokens. Light and Dark are symmetric Scheme cases; neither is
# derived from the other and no value is hand-picked for either. Every colour
# role is scheme-independent: {hue, chroma, level}, where level is its
# distance from the background. One function produces both schemes:
#   value(role, scheme) = oklch(lightness(level, scheme), chroma, hue)
# with lightness measured from the dark end for Dark and from the light end
# for Light, mirrored. Exempt: Image fills (the pet bitmap) and the Shadow
# token. This is the only file that holds colour values.
#
# Roles depend on the field they fill (see primitives.bend): text takes a
# TextRole, surfaces (Rounded/Path fills, gradient stops) a SurfaceRole,
# strokes (including the approved symbols) a LineRole. A text role on a
# bubble, or a surface role on text, does not type-check.
#
# States are rules, not roles: Pressed darkens a role by one fixed step of
# lightness; Disabled is the role at 50% opacity.
#
# Background is the scheme's extreme: pure black in Dark, pure white in
# Light (its level is minus the dark end, so lightness clamps to 0 or 1);
# every other role keeps its level.

type Scheme is Data:
  Scheme.Dark{}
  Scheme.Light{}
type State is Data:
  State.Rest{}
  State.Pressed{}
  State.Disabled{}
type TextRole is Data:
  TextRole.Ink{}
  TextRole.Muted{}
  TextRole.CodeKeyword{}
  TextRole.CodeType{}
  TextRole.CodeName{}
  TextRole.CodeLiteral{}
type SurfaceRole is Data:
  SurfaceRole.Background{}
  SurfaceRole.Surface{}
  SurfaceRole.Raised{}
  SurfaceRole.Accent{}
  SurfaceRole.Danger{}
  SurfaceRole.Field{}
  SurfaceRole.Action{}
  SurfaceRole.Mine{}
  SurfaceRole.Glass{}
type LineRole is Data:
  LineRole.Ink{}
  LineRole.Muted{}
  LineRole.Line{}
  LineRole.Accent{}
  LineRole.Edge{}
# A gradient stop: a surface role, or Clear (the background, transparent).
type Stop is Data:
  Stop.Of{role: SurfaceRole}
  Stop.Clear{}

# The scheme-independent definition of a role.
type Tone is Data:
  Tone{hue: F32, chroma: F32, level: F32}

# Minus the dark end (0.16813, below): Dark clamps to black, Light to white.
def background() -> Tone: Tone{211.135, 0.0, F32.sub(0.0, 0.16813)}
# Ink: chosen so Dark Ink resolves exactly to the approved symbols' colour.
def ink() -> Tone: Tone{247.839, 0.00171, 0.80766}
def muted() -> Tone: Tone{248.072, 0.01826, 0.581}
def text_tone(r: TextRole) -> Tone:
  match r:
    case TextRole.Ink{}: ink()
    case TextRole.Muted{}: muted()
    case TextRole.CodeKeyword{}: Tone{350.0, 0.09, 0.64}
    case TextRole.CodeType{}: Tone{200.0, 0.07, 0.64}
    case TextRole.CodeName{}: Tone{250.0, 0.09, 0.64}
    case TextRole.CodeLiteral{}: Tone{145.0, 0.08, 0.64}
def surface_tone(r: SurfaceRole) -> Tone:
  match r:
    case SurfaceRole.Background{}: background()
    case SurfaceRole.Surface{}: Tone{223.81, 0.0, 0.08}
    case SurfaceRole.Raised{}: Tone{250.651, 0.0331, 0.139}
    case SurfaceRole.Accent{}: Tone{252.042, 0.09, 0.28}
    case SurfaceRole.Danger{}: Tone{21.957, 0.11, 0.28}
    case SurfaceRole.Field{}: Tone{223.81, 0.0, 0.165}
    case SurfaceRole.Action{}: Tone{252.042, 0.07, 0.47}
    # My bubbles: the reference's lighter blue, as light as Ink text on it
    # still passes AA (the reference's own #6e8eb5 gives 3.1:1).
    case SurfaceRole.Mine{}: Tone{252.042, 0.07, 0.38}
    # The tint of Liquid Glass, painted at glass().tint percent over the
    # blurred backdrop (see the Glass law below).
    case SurfaceRole.Glass{}: Tone{223.81, 0.0, 0.06}
def line_tone(r: LineRole) -> Tone:
  match r:
    case LineRole.Ink{}: ink()
    case LineRole.Muted{}: muted()
    case LineRole.Line{}: Tone{248.596, 0.0282, 0.44}
    case LineRole.Accent{}: Tone{252.042, 0.11, 0.46}
    case LineRole.Edge{}: Tone{223.81, 0.0, 0.207}

# Lightness: the dark end plus the level (Dark), or the light end minus it
# (Light).
def dark_end() -> F32: 0.16813
def light_end() -> F32: 0.985
def lightness(+level: F32, scheme: Scheme) -> F32:
  match scheme:
    case Scheme.Dark{}: F32.clamp(F32.add(dark_end(), level), 0.0, 1.0)
    case Scheme.Light{}: F32.clamp(F32.sub(light_end(), level), 0.0, 1.0)
# The Pressed rule: one fixed step darker, in both schemes.
def pressed_step() -> F32: 0.06
def state_lightness(state: State, +l: F32) -> F32:
  match state:
    case State.Pressed{}: F32.sub(l, pressed_step())
    case _: l

# OKLCH to sRGB
# -------------

type Rgb is Data:
  Rgb{r: U32, g: U32, b: U32}
def cube(+x: F32) -> F32: F32.mul(F32.mul(x, x), x)
def gamma(+x: F32) -> F32:
  Bool.pick(F32, F32.is_le(x, 0.0031308), F32.mul(x, 12.92), F32.sub(F32.mul(1.055, F32.pow(x, 0.41666667)), 0.055))
def channel(+x: F32) -> U32:
  F32.to_u32(F32.round(F32.mul(F32.clamp(gamma(F32.clamp(x, 0.0, 1.0)), 0.0, 1.0), 255.0)))
def oklch(+l: F32, +c: F32, +h: F32) -> Rgb:
  +rad = F32.mul(h, 0.0174532925)
  +a = F32.mul(c, F32.cos(rad))
  +b = F32.mul(c, F32.sin(rad))
  +lp = cube(F32.add(l, F32.add(F32.mul(0.3963377774, a), F32.mul(0.2158037573, b))))
  +mp = cube(F32.sub(F32.sub(l, F32.mul(0.1055613458, a)), F32.mul(0.0638541728, b)))
  +sp = cube(F32.sub(F32.sub(l, F32.mul(0.0894841775, a)), F32.mul(1.291485548, b)))
  Rgb{channel(F32.add(F32.sub(F32.mul(4.0767416621, lp), F32.mul(3.3077115913, mp)), F32.mul(0.2309699292, sp))),
      channel(F32.sub(F32.add(F32.neg(F32.mul(1.2684380046, lp)), F32.mul(2.6097574011, mp)), F32.mul(0.3413193965, sp))),
      channel(F32.add(F32.sub(F32.neg(F32.mul(0.0041960863, lp)), F32.mul(0.7034186147, mp)), F32.mul(1.707614701, sp)))}
def rgb(t: Tone, +scheme: Scheme, +state: State) -> Rgb:
  match t:
    case Tone{hue, chroma, level}: oklch(state_lightness(state, lightness(level, scheme)), chroma, hue)
def digit(+n: U32) -> Char:
  Chr{Bool.pick(U32, U32.is_lt(n, 10), U32.add(48, n), U32.add(87, n))}
def hex2(+n: U32) -> String:
  SCon{digit(U32.div(n, 16)), SCon{digit(U32.mod(n, 16)), SNil{}}}
def hex(c: Rgb) -> String:
  match c:
    case Rgb{r, g, b}: "#" ++ hex2(r) ++ hex2(g) ++ hex2(b)
def rgba(c: Rgb, alpha: String) -> String:
  match c:
    case Rgb{r, g, b}: "rgba(" ++ U32.show(r) ++ "," ++ U32.show(g) ++ "," ++ U32.show(b) ++ "," ++ alpha ++ ")"
# The Disabled rule: the role at 50% opacity (the reference's dimmed look).
def css(t: Tone, +scheme: Scheme, +state: State) -> String:
  match state:
    case State.Disabled{}: rgba(rgb(t, scheme, State.Rest{}), "0.5")
    case _: hex(rgb(t, scheme, state))

# Values
# ------

def text(r: TextRole, +state: State, +scheme: Scheme) -> String: css(text_tone(r), scheme, state)
def surface(r: SurfaceRole, +state: State, +scheme: Scheme) -> String: css(surface_tone(r), scheme, state)
def line(r: LineRole, +state: State, +scheme: Scheme) -> String: css(line_tone(r), scheme, state)
def stop(s: Stop, +scheme: Scheme) -> String:
  match s:
    case Stop.Of{r}: surface(r, State.Rest{}, scheme)
    case Stop.Clear{}: rgba(rgb(background(), scheme, State.Rest{}), "0")
# Exempt from the rule: one fixed Shadow token for both schemes.
def shadow() -> String: "rgba(0,0,0,0.35)"
# Exceptions: per-role values the rule may not produce, allowed only where
# the contrast law forces them. None are needed: Dark Ink resolves exactly to
# the approved symbol colour and every allowed pair passes AA.
type Exception is Data:
  Exception{role: String, scheme: Scheme, reason: String}
def exceptions() -> List<&2, Exception>: []

# Contrast law (WCAG 2.x)
# -----------------------

def linear(+c: U32) -> F32:
  +x = F32.div(U32.to_f32(c), 255.0)
  Bool.pick(F32, F32.is_le(x, 0.04045), F32.div(x, 12.92), F32.pow(F32.div(F32.add(x, 0.055), 1.055), 2.4))
def luminance(c: Rgb) -> F32:
  match c:
    case Rgb{r, g, b}: F32.add(F32.add(F32.mul(0.2126, linear(r)), F32.mul(0.7152, linear(g))), F32.mul(0.0722, linear(b)))
# Contrast ratio x100, rounded down (so 4.5:1 is 450).
def ratio(a: Rgb, b: Rgb) -> U32:
  +la = F32.add(luminance(a), 0.05)
  +lb = F32.add(luminance(b), 0.05)
  F32.to_u32(F32.floor(F32.mul(100.0, F32.div(F32.max(la, lb), F32.min(la, lb)))))
type Use is Data:
  Use.Text{}
  Use.Graphic{}
# AA: 4.5:1 for text, 3:1 for icons, strokes and large text. AAA (7:1) is
# reported for information.
def aa(use: Use) -> U32:
  match use:
    case Use.Text{}: 450
    case Use.Graphic{}: 300
type Contrast is Data:
  Contrast{fg: String, bg: String, scheme: Scheme, state: State, use: Use, ratio: U32, aa: Bool, aaa: Bool}
def text_name(r: TextRole) -> String:
  match r:
    case TextRole.Ink{}: "Ink"
    case TextRole.Muted{}: "Muted"
    case TextRole.CodeKeyword{}: "Code keyword"
    case TextRole.CodeType{}: "Code type"
    case TextRole.CodeName{}: "Code name"
    case TextRole.CodeLiteral{}: "Code literal"
def surface_name(r: SurfaceRole) -> String:
  match r:
    case SurfaceRole.Background{}: "Background"
    case SurfaceRole.Surface{}: "Surface"
    case SurfaceRole.Raised{}: "Raised"
    case SurfaceRole.Accent{}: "Accent"
    case SurfaceRole.Danger{}: "Danger"
    case SurfaceRole.Field{}: "Field"
    case SurfaceRole.Action{}: "Action"
    case SurfaceRole.Mine{}: "Mine"
    case SurfaceRole.Glass{}: "Glass"
def line_name(r: LineRole) -> String:
  match r:
    case LineRole.Ink{}: "Ink"
    case LineRole.Muted{}: "Muted"
    case LineRole.Line{}: "Line"
    case LineRole.Accent{}: "Accent"
    case LineRole.Edge{}: "Edge"
# Glass is not among the opaque surfaces: it is a tint over a backdrop, so
# its pairs are checked composited (glass_pairs below).
def surfaces() -> List<&2, SurfaceRole>:
  [SurfaceRole.Background{}, SurfaceRole.Surface{}, SurfaceRole.Raised{}, SurfaceRole.Accent{}, SurfaceRole.Danger{}, SurfaceRole.Field{}, SurfaceRole.Action{}, SurfaceRole.Mine{}]
# Surfaces text may sit on: every surface but Action, which only carries an
# icon (the composer's Send) and so needs graphic contrast (3:1), not text.
def text_surfaces() -> List<&2, SurfaceRole>:
  [SurfaceRole.Background{}, SurfaceRole.Surface{}, SurfaceRole.Raised{}, SurfaceRole.Accent{}, SurfaceRole.Danger{}, SurfaceRole.Field{}, SurfaceRole.Mine{}]
def neutral() -> List<&2, SurfaceRole>:
  [SurfaceRole.Background{}, SurfaceRole.Surface{}, SurfaceRole.Raised{}, SurfaceRole.Field{}]
def text_roles() -> List<&2, TextRole>: [TextRole.Ink{}, TextRole.Muted{}, TextRole.CodeKeyword{}, TextRole.CodeType{}, TextRole.CodeName{}, TextRole.CodeLiteral{}]
# Lines that carry meaning (icons, strokes, focus) and so take the 3:1 law.
# Edge is not among them: see decorative().
def line_roles() -> List<&2, LineRole>: [LineRole.Ink{}, LineRole.Muted{}, LineRole.Line{}, LineRole.Accent{}]
# Decorative lines, handled explicitly: exempt from the 3:1 law because they
# carry no information (WCAG 1.4.11 asks contrast of the parts needed to
# identify a component, not of every edge).
type Decorative is Data:
  Decorative{role: String, use: String, reason: String}
def decorative() -> List<&2, Decorative>:
  [Decorative{"Edge", "the composer pill's border (on Field)", "a faint surface edge, as in the reference: the pill is identified by its Field fill, its placeholder and its buttons, never by the edge; focus switches the edge to the Accent line (3:1)"}]
# Icon-only surfaces: no text may sit on them (tests check every Action fill
# is a circle holding a glyph).
def icon_only() -> List<&2, SurfaceRole>: [SurfaceRole.Action{}]
def schemes() -> List<&2, Scheme>: [Scheme.Dark{}, Scheme.Light{}]
# Which surfaces each foreground may sit on. Ink sits on every surface; the
# other foregrounds only on the neutral ones (Background, Surface, Raised).
def text_on(r: TextRole) -> List<&2, SurfaceRole>:
  match r:
    case TextRole.Ink{}: text_surfaces()
    case TextRole.Muted{}: neutral()
    case _: neutral()
# Lines on Field: Ink (icons) and Accent (the focus ring); Muted and Line
# are not used there.
def line_on(r: LineRole) -> List<&2, SurfaceRole>:
  match r:
    case LineRole.Ink{}: surfaces()
    case LineRole.Accent{}: neutral()
    case _: [SurfaceRole.Background{}, SurfaceRole.Surface{}, SurfaceRole.Raised{}]
# Surfaces the Pressed rule darkens: the fills of pressable controls.
# Background and Field are never pressed; the icon-only Action (Send) gives
# press feedback by shrinking, not darkening. Pressed pairs are checked only
# on these.
def pressable() -> List<&2, SurfaceRole>: [SurfaceRole.Surface{}, SurfaceRole.Raised{}, SurfaceRole.Accent{}, SurfaceRole.Danger{}]
def is_pressable_go(xs: List<&2, SurfaceRole>, +bg: SurfaceRole) -> Bool:
  match xs:
    case Nil{}: False{}
    case Con{x, rest}: Bool.or(String.eq(surface_name(x), surface_name(bg)), is_pressable_go(rest, bg))
def is_pressed(s: State) -> Bool:
  match s:
    case State.Pressed{}: True{}
    case _: False{}
def under(+state: State, bgs: List<&2, SurfaceRole>) -> List<&2, SurfaceRole>:
  match bgs:
    case Nil{}: []
    case Con{+bg, rest}:
      +tail = under(state, rest)
      Bool.pick(List<&2, SurfaceRole>, Bool.or(Bool.not(is_pressed(state)), is_pressable_go(pressable(), bg)), Con{bg, tail}, tail)
def pair(+fg: String, +fg_rgb: Rgb, +bg: SurfaceRole, +scheme: Scheme, +state: State, +use: Use) -> Contrast:
  +bg_name = surface_name(bg)
  +r = ratio(fg_rgb, rgb(surface_tone(bg), scheme, state))
  Contrast{fg, bg_name, scheme, state, use, r, U32.is_ge(r, aa(use)), U32.is_ge(r, 700)}
def pairs_on(+fg: String, +fg_rgb: Rgb, bgs: List<&2, SurfaceRole>, +scheme: Scheme, +state: State, +use: Use) -> List<&2, Contrast>:
  match bgs:
    case Nil{}: []
    case Con{bg, rest}: Con{pair(fg, fg_rgb, bg, scheme, state, use), pairs_on(fg, fg_rgb, rest, scheme, state, use)}
def append_pairs(xs: List<&2, Contrast>, ys: List<&2, Contrast>) -> List<&2, Contrast>:
  match xs:
    case Nil{}: ys
    case Con{x, rest}: Con{x, append_pairs(rest, ys)}
def text_pairs(rs: List<&2, TextRole>, +scheme: Scheme, +state: State) -> List<&2, Contrast>:
  match rs:
    case Nil{}: []
    case Con{+r, rest}: append_pairs(pairs_on("Text " ++ text_name(r), rgb(text_tone(r), scheme, State.Rest{}), under(state, text_on(r)), scheme, state, Use.Text{}), text_pairs(rest, scheme, state))
def line_pairs(rs: List<&2, LineRole>, +scheme: Scheme, +state: State) -> List<&2, Contrast>:
  match rs:
    case Nil{}: []
    case Con{+r, rest}: append_pairs(pairs_on("Line " ++ line_name(r), rgb(line_tone(r), scheme, state), under(state, line_on(r)), scheme, state, Use.Graphic{}), line_pairs(rest, scheme, state))
# Every allowed pair, in a scheme, at rest and pressed (Disabled is exempt
# from contrast requirements). Pressed darkens a control's fill and stroke
# together; its text keeps the Rest value.
def scheme_pairs(+scheme: Scheme) -> List<&2, Contrast>:
  append_pairs(append_pairs(text_pairs(text_roles(), scheme, State.Rest{}), line_pairs(line_roles(), scheme, State.Rest{})),
    append_pairs(text_pairs(text_roles(), scheme, State.Pressed{}), line_pairs(line_roles(), scheme, State.Pressed{})))

# Liquid Glass
# ------------

# The material: blur radius (px), saturation (%), refraction strength (px of
# displacement where the renderer supports it), specular highlight (% white
# at the top edge) and tint (% opacity of the Glass role). One value for
# both schemes; the Glass effect (primitives.bend) carries it.
type Material is Data:
  Material{blur: U32, saturation: U32, refraction: U32, highlight: U32, tint: U32}
def glass() -> Material: Material{14, 180, 18, 12, 78}
# What a glass sits over: Base (only the Background: nothing scrolls under
# it, e.g. the composer row) or Content (the thread scrolls or opens under
# it: the header, the badge, the attach panel).
type Backdrop is Data:
  Backdrop.Base{}
  Backdrop.Content{}
def backdrop_name(b: Backdrop) -> String:
  match b:
    case Backdrop.Base{}: "Base"
    case Backdrop.Content{}: "Content"
def opposite(s: Scheme) -> Scheme:
  match s:
    case Scheme.Dark{}: Scheme.Light{}
    case Scheme.Light{}: Scheme.Dark{}
# The worst backdrop: over Base, the Background; over Content, the scheme's
# opposite extreme (white in Dark, black in Light), which covers any text,
# surface or photo that can pass under it (the blur only averages them).
def worst(b: Backdrop, +scheme: Scheme) -> Rgb:
  match b:
    case Backdrop.Base{}: rgb(background(), scheme, State.Rest{})
    case Backdrop.Content{}: rgb(background(), opposite(scheme), State.Rest{})
def mix(+a: U32, +b: U32, +pct: U32) -> U32: U32.div(U32.add(U32.mul(a, pct), U32.mul(b, U32.sub(100, pct))), 100)
def mix_rgb(a: Rgb, b: Rgb, +pct: U32) -> Rgb:
  match a:
    case Rgb{+ar, +ag, +ab}:
      match b:
        case Rgb{+br, +bg, +bb}: Rgb{mix(ar, br, pct), mix(ag, bg, pct), mix(ab, bb, pct)}
def material_tint(m: Material) -> U32:
  match m:
    case Material{blur, sat, refr, spec, tint}: tint
def material_highlight(m: Material) -> U32:
  match m:
    case Material{blur, sat, refr, spec, tint}: spec
# What text on the glass sits on, at worst: the tint over the worst
# backdrop (browsers composite in sRGB), then the specular white at its peak.
def glass_rgb(b: Backdrop, +scheme: Scheme) -> Rgb:
  mix_rgb(Rgb{255, 255, 255}, mix_rgb(rgb(surface_tone(SurfaceRole.Glass{}), scheme, State.Rest{}), worst(b, scheme), material_tint(glass())), material_highlight(glass()))
# Which roles may sit on Glass: over Content only Ink (text and icons);
# over Base, Muted too (the composer's placeholder).
def glass_text(b: Backdrop) -> List<&2, TextRole>:
  match b:
    case Backdrop.Base{}: [TextRole.Ink{}, TextRole.Muted{}]
    case Backdrop.Content{}: [TextRole.Ink{}]
def glass_lines(b: Backdrop) -> List<&2, LineRole>:
  match b:
    case Backdrop.Base{}: [LineRole.Ink{}, LineRole.Accent{}]
    case Backdrop.Content{}: [LineRole.Ink{}]
def backdrops() -> List<&2, Backdrop>: [Backdrop.Base{}, Backdrop.Content{}]
def glass_pair(+fg: String, +fg_rgb: Rgb, +b: Backdrop, +scheme: Scheme, +use: Use) -> Contrast:
  +r = ratio(fg_rgb, glass_rgb(b, scheme))
  Contrast{fg, "Glass over " ++ backdrop_name(b), scheme, State.Rest{}, use, r, U32.is_ge(r, aa(use)), U32.is_ge(r, 700)}
def glass_text_pairs(rs: List<&2, TextRole>, +b: Backdrop, +scheme: Scheme) -> List<&2, Contrast>:
  match rs:
    case Nil{}: []
    case Con{+r, rest}: Con{glass_pair("Text " ++ text_name(r), rgb(text_tone(r), scheme, State.Rest{}), b, scheme, Use.Text{}), glass_text_pairs(rest, b, scheme)}
def glass_line_pairs(rs: List<&2, LineRole>, +b: Backdrop, +scheme: Scheme) -> List<&2, Contrast>:
  match rs:
    case Nil{}: []
    case Con{+r, rest}: Con{glass_pair("Line " ++ line_name(r), rgb(line_tone(r), scheme, State.Rest{}), b, scheme, Use.Graphic{}), glass_line_pairs(rest, b, scheme)}
def glass_on(bs: List<&2, Backdrop>, +scheme: Scheme) -> List<&2, Contrast>:
  match bs:
    case Nil{}: []
    case Con{+b, rest}: append_pairs(append_pairs(glass_text_pairs(glass_text(b), b, scheme), glass_line_pairs(glass_lines(b), b, scheme)), glass_on(rest, scheme))
def glass_pairs() -> List<&2, Contrast>:
  append_pairs(glass_on(backdrops(), Scheme.Dark{}), glass_on(backdrops(), Scheme.Light{}))
def pairs() -> List<&2, Contrast>:
  append_pairs(append_pairs(scheme_pairs(Scheme.Dark{}), scheme_pairs(Scheme.Light{})), glass_pairs())
