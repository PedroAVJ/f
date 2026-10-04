import Base
import ./primitives.bend as P
import ./symbols.bend as S
import ./nearling.bend as N
import ./metrics.bend as M
import ./tokens.bend as T

# Near components, built only from the two primitives (Shape, Layout).
# A component is anything composed of primitives and/or other components.
#   - Holes are typed markup: a hole only accepts the type it names (a
#     Button's content is Label | Icon | Row, never a Bubble or a Button).
#     A component with holes is a function of markup; without holes it is a
#     plain value.
#   - Cases are sum-type cases. Some are chosen in markup (M); others are
#     chosen by the screen from its state (S); size cases are chosen by the
#     component from the box its parent gives it (never from the viewport).
#   - State: components never read state. Each component declares the exact
#     slice of state it may receive, and the screen passes only that slice.
#     The slice's type may depend on the component's case (dependent types).
#     Every slice part has a Source (Local | Server) and a Persistence
#     (Persistent by default; Ephemeral only for physical moments: a press,
#     an animation clock, a transition in progress, "Near is typing").
#   - Server values that load are Remote<A>: Loading | Ready | Pending |
#     Failed, and the component draws every case.
#   - Motion is state + time: a transition is Settled | Transitioning{from,
#     to, started_at}; the view at time `now` is computed here. Default is
#     Instant; components animate only for continuity, direct feedback, or
#     when motion is the content. Reduced motion snaps everything except
#     content motion (typing dots, the pet).
#   - Accessibility: every component declares its role; an icon-only Button
#     must carry a spoken label (the type requires it). Roles and labels are
#     written into node names ("button · Enviar"), which the focus order and
#     the layout overlay read. Press regions are at least 44pt.
#   - Text has a declared rule (Wrap, Truncate, NoWrap) and every component
#     a size range per case, derived from its content via metrics.bend.
# Every component returns its own type (a Button, a Field, ...) wrapping the
# Shape/Layout tree it draws, so a hole typed Button only accepts a Button.

# Allowed values: colour roles (tokens.bend) and text types
# ---------------------------------------------------------

def ink() -> T.TextRole: T.TextRole.Ink{}
def muted() -> T.TextRole: T.TextRole.Muted{}
def hint() -> T.TextRole: T.TextRole.Muted{}
def hairline() -> T.LineRole: T.LineRole.Line{}
def rest() -> T.State: T.State.Rest{}
# The content column of the reference iPhone frame: the default box.
def column() -> U32: 320
# Body is 17pt, the iPhone reference's message text.
def body() -> P.TextType: P.TextType{"Body", 17, 400}
def label_type() -> P.TextType: P.TextType{"Label", 15, 600}
def title_type() -> P.TextType: P.TextType{"Title", 17, 600}
def name_type() -> P.TextType: P.TextType{"Name", 18, 600}
def small_type() -> P.TextType: P.TextType{"Small", 13, 500}
def note_type() -> P.TextType: P.TextType{"Note", 13, 400}
# Matrix annotations (case labels) are canvas notes, not part of a component.
def annotation() -> P.TextType: P.TextType{"Annotation", 11, 500}

# State, server values and action messages
# ----------------------------------------

type Source is Data:
  Source.Local{}
  Source.Server{}
type Persistence is Data:
  Persistence.Persistent{}
  Persistence.Ephemeral{}
# One part of a declared slice, as printed under the component's frame.
type Part is Data:
  Part{name: String, shape: String, source: Source, persistence: Persistence, when: String}
type Remote<a, -A: Kind(a)> is Kind(a):
  Loading{}
  Ready{value: A}
  Pending{value: A}
  Failed{last: Maybe<a, A>}
type Mode is Data:
  Mode.Optimistic{}
  Mode.Pessimistic{}
type Message is Data:
  Message.Send{}
  Message.Retry{}
  Message.CreateAccess{}
  Message.Receive{}
  Message.Confirm{}
  Message.Share{}
  Message.Revoke{}
# Pessimistic unless stated: only sending a chat message is optimistic (the
# bubble shows at once and reports its delivery).
def mode(m: Message) -> Mode:
  match m:
    case Message.Send{}: Mode.Optimistic{}
    case _: Mode.Pessimistic{}

# Motion
# ------

# Duration tokens. Instant is the default; Loop is the cycle of content
# motion (typing dots, the pet).
type Duration is Data:
  Duration.Instant{}
  Duration.Fast{}
  Duration.Normal{}
  Duration.Slow{}
  Duration.Loop{}
def duration_ms(d: Duration) -> U32:
  match d:
    case Duration.Instant{}: 0
    case Duration.Fast{}: 160
    case Duration.Normal{}: 320
    case Duration.Slow{}: 560
    case Duration.Loop{}: 1200
def duration_name(d: Duration) -> String:
  match d:
    case Duration.Instant{}: "Instant"
    case Duration.Fast{}: "Fast"
    case Duration.Normal{}: "Normal"
    case Duration.Slow{}: "Slow"
    case Duration.Loop{}: "Loop"
# Why something may animate.
type Reason is Data:
  Reason.Continuity{}
  Reason.Feedback{}
  Reason.Content{}
def reason_name(r: Reason) -> String:
  match r:
    case Reason.Continuity{}: "continuity"
    case Reason.Feedback{}: "direct feedback"
    case Reason.Content{}: "motion is the content"
# The system preference: Reduced snaps every transition except content.
type Motion is Data:
  Motion.Full{}
  Motion.Reduced{}
type Clock is Data:
  Clock{ms: U32}
# Time is state: the current time and the motion preference.
type Moment is Data:
  Moment{now: U32, pref: Motion}
def still() -> Moment: Moment{0, Motion.Full{}}
# A component's motion case (Local, Ephemeral).
type Transit<a, -A: Kind(a)> is Kind(a):
  Settled{}
  Transitioning{from: A, to: A, started_at: U32}
# A declared transition: what triggers it, its duration token and its reason.
type Transition is Data:
  Transition{key: String, component: String, name: String, trigger: String, duration: Duration, reason: Reason}
def snaps(reason: Reason, pref: Motion) -> Bool:
  match reason pref:
    case Reason.Content{} _: False{}
    case _ Motion.Reduced{}: True{}
    case _ Motion.Full{}: False{}
def ratio_of(+elapsed: U32, +ms: U32) -> U32:
  Bool.pick(U32, U32.is_zero(ms), 1000, U32.min(1000, U32.div(U32.mul(U32.min(elapsed, 4000000), 1000), ms)))
# Progress 0..1000 of a transition started at `started_at`, at the moment.
def progress(+started_at: U32, m: Moment, t: Transition) -> U32:
  match m t:
    case Moment{+now, pref} Transition{key, component, name, trigger, duration, reason}:
      Bool.pick(U32, snaps(reason, pref), 1000, ratio_of(Bool.pick(U32, U32.is_lt(now, started_at), 0, U32.sub(now, started_at)), duration_ms(duration)))
# Ease-out cubic, in thousandths.
def eased(+p: U32) -> U32:
  +q = U32.sub(1000, p)
  U32.sub(1000, U32.div(U32.mul(U32.div(U32.mul(q, q), 1000), q), 1000))
def ease_of(+started_at: U32, m: Moment, t: Transition) -> U32: eased(progress(started_at, m, t))
def lerp(+a: U32, +b: U32, +e: U32) -> U32:
  Bool.pick(U32, U32.is_le(a, b), U32.add(a, U32.div(U32.mul(U32.sub(b, a), e), 1000)), U32.sub(a, U32.div(U32.mul(U32.sub(a, b), e), 1000)))
# Content motion loops and never snaps: phase 0..1000 within the cycle.
def phase(m: Moment, +d: Duration) -> U32:
  match m:
    case Moment{now, pref}: U32.div(U32.mul(U32.mod(now, duration_ms(d)), 1000), duration_ms(d))

# The transitions every component declares.
def press_t() -> Transition: Transition{"button-press", "Button", "press", "finger down", Duration.Fast{}, Reason.Feedback{}}
def grow_t() -> Transition: Transition{"field-grow", "Field", "grow a line", "the draft wraps to a new line", Duration.Normal{}, Reason.Continuity{}}
def cap_t() -> Transition: Transition{"field-cap", "Field", "reach the cap", "the draft passes the cap", Duration.Normal{}, Reason.Continuity{}}
def appear_t() -> Transition: Transition{"typing-appear", "TypingIndicator", "appear", "Near starts typing", Duration.Fast{}, Reason.Continuity{}}
def dots_t() -> Transition: Transition{"typing-dots", "TypingIndicator", "dots", "while Near is typing", Duration.Loop{}, Reason.Content{}}
def pet_t() -> Transition: Transition{"near-pet", "NearIdentity", "pet", "the animation clock", Duration.Loop{}, Reason.Content{}}
def item_t() -> Transition: Transition{"thread-item", "Thread", "new item", "a message is added", Duration.Normal{}, Reason.Continuity{}}
def keyboard_t() -> Transition: Transition{"thread-keyboard", "Thread", "keyboard opens", "the field takes focus", Duration.Normal{}, Reason.Continuity{}}
def reply_t() -> Transition: Transition{"thread-reply", "Thread", "Near replies", "Near's reply replaces the typing indicator", Duration.Normal{}, Reason.Continuity{}}
def composer_cap_t() -> Transition: Transition{"composer-cap", "Composer", "reach the cap", "the draft passes the cap", Duration.Normal{}, Reason.Continuity{}}
def send_t() -> Transition: Transition{"conversation-send", "Conversation", "send", "Send is tapped", Duration.Normal{}, Reason.Continuity{}}
def hero_leave_t() -> Transition: Transition{"hero-leave", "WelcomeHero", "leave", "the link is redeemed", Duration.Slow{}, Reason.Continuity{}}
def sheet_t() -> Transition: Transition{"sheet-open", "Sheet", "open", "a message or the editor is opened", Duration.Normal{}, Reason.Continuity{}}
def highlight_t() -> Transition: Transition{"thread-highlight", "Thread", "highlight", "a search result is opened", Duration.Slow{}, Reason.Feedback{}}
def transitions() -> List<&2, Transition>:
  [press_t(), grow_t(), cap_t(), appear_t(), dots_t(), pet_t(), item_t(), keyboard_t(), reply_t(), composer_cap_t(), send_t(), hero_leave_t(), sheet_t(), highlight_t()]
# Changes that stay Instant: status changes, which must not look like motion.
type Snap is Data:
  Snap{component: String, change: String, why: String}
def instants() -> List<&2, Snap>:
  [Snap{"Button", "served content Ready → Failed", "status change"},
   Snap{"Bubble", "delivery Sending → Sent → Failed", "status change"},
   Snap{"Composer", "send Disabled ↔ Enabled", "status change"},
   Snap{"Thread", "messages Ready → Failed", "status change"},
   Snap{"Conversation", "the composer clears on send", "the flight carries the text"},
   Snap{"WelcomeHero", "redeem Loading → Failed", "status change"},
   Snap{"CallControls", "phase Ringing → Connected → Ended", "status change"}]

# Accessibility
# -------------

type A11yRole is Data:
  A11yRole.Button{}
  A11yRole.Textbox{}
  A11yRole.List{}
  A11yRole.Listitem{}
  A11yRole.Status{}
  A11yRole.Img{}
  A11yRole.Group{}
  A11yRole.Banner{}
  A11yRole.Heading{}
  A11yRole.Text{}
  A11yRole.Dialog{}
def role_name(r: A11yRole) -> String:
  match r:
    case A11yRole.Button{}: "button"
    case A11yRole.Textbox{}: "textbox"
    case A11yRole.List{}: "list"
    case A11yRole.Listitem{}: "listitem"
    case A11yRole.Status{}: "status"
    case A11yRole.Img{}: "img"
    case A11yRole.Group{}: "group"
    case A11yRole.Banner{}: "banner"
    case A11yRole.Heading{}: "heading"
    case A11yRole.Text{}: "text"
    case A11yRole.Dialog{}: "dialog"
# A spoken label: a message (translated copy) or a name (a proper noun).
type Spoken is Data:
  Spoken.Message{text: String}
  Spoken.Name{text: String}
def spoken(s: Spoken) -> String:
  match s:
    case Spoken.Message{text}: text
    case Spoken.Name{text}: text
# The node name carrying a role and its label.
def named(r: A11yRole, label: String) -> String: role_name(r) ++ " · " ++ label
type RoleDecl is Data:
  RoleDecl{component: String, role: A11yRole}
def roles() -> List<&2, RoleDecl>:
  [RoleDecl{"Button", A11yRole.Button{}}, RoleDecl{"Field", A11yRole.Textbox{}}, RoleDecl{"Bubble", A11yRole.Listitem{}},
   RoleDecl{"Badge", A11yRole.Text{}}, RoleDecl{"NearIdentity", A11yRole.Img{}}, RoleDecl{"TypingIndicator", A11yRole.Status{}},
   RoleDecl{"Header", A11yRole.Banner{}}, RoleDecl{"Composer", A11yRole.Group{}}, RoleDecl{"Thread", A11yRole.List{}},
   RoleDecl{"Invitación", A11yRole.Group{}},
   RoleDecl{"Compartir", A11yRole.Group{}}, RoleDecl{"Conversation", A11yRole.Group{}},
   RoleDecl{"WelcomeHero", A11yRole.Group{}}, RoleDecl{"Sheet", A11yRole.Dialog{}}, RoleDecl{"CallControls", A11yRole.Group{}}, RoleDecl{"Search", A11yRole.Group{}}]
# The minimum press region.
def press_min() -> U32: 44

# Text rules and size ranges
# --------------------------

type TextRule is Data:
  TextRule.Wrap{}
  TextRule.Truncate{}
  TextRule.NoWrap{}
# A size range; a max of 0 is unbounded (the component fills).
type Range is Data:
  Range{min_width: U32, max_width: U32, min_height: U32, max_height: U32}
type CaseRange is Data:
  CaseRange{name: String, range: Range}
# A derived threshold: the box width at which a component switches case.
type Threshold is Data:
  Threshold{component: String, at: U32, below: String, above: String}
def bound(+n: U32) -> String: Bool.pick(String, U32.is_zero(n), "∞", U32.show(n))
def range_text(c: CaseRange) -> String:
  match c:
    case CaseRange{name, Range{a, +b, +c2, +d}}:
      name ++ " w " ++ U32.show(a) ++ "–" ++ bound(b) ++ Bool.pick(String, Bool.and(U32.is_zero(c2), U32.is_zero(d)), "", Bool.pick(String, U32.is_eq(c2, d), " h " ++ U32.show(c2), " h " ++ U32.show(c2) ++ "–" ++ bound(d)))
def ranges_text(xs: List<&2, CaseRange>) -> String:
  match xs:
    case Nil{}: ""
    case Con{x, Nil{}}: range_text(x)
    case Con{x, rest}: range_text(x) ++ " · " ++ ranges_text(rest)
def threshold_text(t: Threshold) -> String:
  match t:
    case Threshold{component, +at, below, above}: below ++ " below " ++ U32.show(at) ++ ", " ++ above ++ " from " ++ U32.show(at)
# A line of text under a rule: Truncate fits `max`, NoWrap keeps it whole.
def fitted(+s: String, rule: TextRule, +max: U32, +text_type: P.TextType) -> String:
  match rule:
    case TextRule.Truncate{}: M.truncate(s, max, text_type)
    case _: s
def rule_min(+s: String, rule: TextRule, +text_type: P.TextType) -> U32:
  match rule:
    case TextRule.Wrap{}: M.longest_word(s, text_type)
    case TextRule.Truncate{}: Bool.pick(U32, String.is_empty(s), 0, M.width(M.ellipsis(), text_type))
    case TextRule.NoWrap{}: M.width(s, text_type)
# The readable width: about 70 characters of body text.
def readable() -> U32: M.width(M.readable_sample(), body())

# Shape and Layout helpers
# ------------------------

def line_height(text_type: P.TextType) -> U32:
  match text_type:
    case P.TextType{name, size, weight}: U32.add(U32.div(U32.mul(size, 5), 4), 1)
def words_in(name: String, +string: String, +text_type: P.TextType, color: T.TextRole, state: T.State, align: P.Align) -> P.Tree:
  P.leaf(name, P.Shape{P.Text{string, text_type}, P.TextFill.Solid{color, state}, P.NoStroke{}, []}, M.width(string, text_type), line_height(text_type), align)
def words(name: String, +string: String, +text_type: P.TextType, color: T.TextRole, align: P.Align) -> P.Tree:
  words_in(name, string, text_type, color, T.State.Rest{}, align)
def stack_lines(xs: List<&2, String>, +text_type: P.TextType, +color: T.TextRole) -> List<&2, P.Tree>:
  match xs:
    case Nil{}: []
    case Con{x, rest}: Con{words("Line", x, text_type, color, P.Leading{}), stack_lines(rest, text_type, color)}
# Wrap rule: text wrapped at `max` px into stacked lines.
def paragraph(name: String, string: String, +text_type: P.TextType, color: T.TextRole, +max: U32, align: P.Align) -> P.Tree:
  P.layout(name, P.Vertical{}, 0, 0, 0, 0, align, stack_lines(M.lines(string, max, text_type), text_type, color))
def filled(name: String, fill: T.SurfaceRole, +width: U32, +height: U32, radius: P.Radius, stroke: P.Stroke) -> P.Tree:
  P.rounded(name, P.Solid{fill, T.State.Rest{}}, width, height, radius, stroke, P.Middle{})
def edge(color: T.LineRole) -> P.Stroke: P.Stroke{color, T.State.Rest{}, "1"}
# An empty box: takes space, draws nothing.
def spacer(name: String, +width: U32, +height: U32, align: P.Align) -> P.Tree:
  P.layout(name, P.Horizontal{}, 0, 0, width, height, align, [])
# Liquid Glass (queued): a Rounded shape whose fill is the Glass tint, with
# the Glass effect (tokens.glass()) over its backdrop. Over Content only
# Ink may sit on it; over Base (the Background) Muted too.
def glassy(name: String, +w: U32, +h: U32, radius: P.Radius, over: T.Backdrop) -> P.Tree:
  P.leaf(name, P.Shape{P.Rounded{w, h, radius}, P.Solid{T.SurfaceRole.Glass{}, T.State.Rest{}}, P.NoStroke{}, [P.glass(over)]}, w, h, P.Middle{})
# A tree placed at (x, y) inside a Depth parent.
def placed_at(+name: String, +x: U32, +y: U32, t: P.Tree) -> P.Tree:
  P.layout(name, P.Vertical{}, 0, 0, 0, 0, P.Leading{}, [spacer("Offset", 0, y, P.Leading{}), P.layout("Row", P.Horizontal{}, 0, 0, 0, 0, P.Leading{}, [spacer("Offset", x, 0, P.Leading{}), t])])
def glyph_in(+path: S.Drawing, +side: U32, state: T.State) -> P.Tree:
  match path:
    case S.Drawing{name, x, y, width, shapes}:
      P.leaf(name, P.Shape{P.Path{path}, P.Fill.None{}, P.Stroke{T.LineRole.Ink{}, state, width}, []}, side, side, P.Middle{})
def glyph(+path: S.Drawing, +side: U32) -> P.Tree: glyph_in(path, side, T.State.Rest{})
# A glyph with its own stroke width (the drawing's geometry unchanged).
def glyph_stroked(+path: S.Drawing, +side: U32, state: T.State, +stroke: String) -> P.Tree:
  match path:
    case S.Drawing{name, x, y, width, shapes}:
      P.leaf(name, P.Shape{P.Path{path}, P.Fill.None{}, P.Stroke{T.LineRole.Ink{}, state, stroke}, []}, side, side, P.Middle{})
def width(t: P.Tree) -> U32: P.width_of(P.size(t))
def height(t: P.Tree) -> U32: P.height_of(P.size(t))
def aligned(t: P.Tree, align: P.Align) -> P.Tree:
  match t:
    case P.Last{}: P.Last{}
    case P.Leaf{name, shape, w, h, a, next}: P.Leaf{name, shape, w, h, align, next}
    case P.Node{name, lay, w, h, a, first, next}: P.Node{name, lay, w, h, align, first, next}
def align_of(t: P.Tree) -> P.Align:
  match t:
    case P.Leaf{name, shape, w, h, a, next}: a
    case P.Node{name, lay, w, h, a, first, next}: a
    case _: P.Leading{}
def renamed(t: P.Tree, name: String) -> P.Tree:
  match t:
    case P.Last{}: P.Last{}
    case P.Leaf{n, shape, w, h, a, next}: P.Leaf{name, shape, w, h, a, next}
    case P.Node{n, lay, w, h, a, first, next}: P.Node{name, lay, w, h, a, first, next}
# A dot in a line role: a circle drawn by a stroke half its size wide.
def dot(+color: T.LineRole, +side: U32) -> P.Tree:
  P.circle("Dot", P.Fill.None{}, P.Stroke{color, T.State.Rest{}, U32.show(U32.div(side, 2))}, side, P.Middle{})
def danger_dot(+side: U32) -> P.Tree:
  P.circle("Dot", P.Solid{T.SurfaceRole.Danger{}, T.State.Rest{}}, P.NoStroke{}, side, P.Middle{})
def accent_dot() -> P.Tree: dot(T.LineRole.Accent{}, 8)
def muted_dot() -> P.Tree: dot(T.LineRole.Muted{}, 8)
# Not approved: provisional drawings for the spinner and the mic
# (dictation). The four approved symbols stay in symbols.bend, unchanged.
def mic() -> S.Drawing:
  S.Drawing{"Mic", "0", "0", "2.3", [S.Path{"M12 3a3 3 0 0 0-3 3v6a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3z"}, S.Path{"M19 11a7 7 0 0 1-14 0M12 18v3"}]}
def arc() -> S.Drawing:
  S.Drawing{"Spinner", "0", "0", "2.6", [S.Path{"M12 3a9 9 0 0 1 9 9"}]}
def spinner(+side: U32) -> P.Tree:
  P.layout("Spinner", P.Depth{}, 0, 0, side, side, P.Middle{}, [
    P.rounded("Ring", P.Fill.None{}, side, side, P.Full{}, P.Stroke{T.LineRole.Line{}, T.State.Rest{}, "2"}, P.Middle{}),
    glyph(arc(), side)])
def alert() -> P.Tree:
  P.layout("Alert", P.Depth{}, 0, 0, 16, 16, P.Middle{}, [danger_dot(16), words("Mark", "!", P.TextType{"Mark", 11, 600}, ink(), P.Middle{})])
def status_line(mark: P.Tree, +text: String) -> P.Tree:
  P.layout(named(A11yRole.Status{}, text), P.Horizontal{}, 8, 0, 0, 0, P.Leading{}, [mark, words("Status", text, small_type(), ink(), P.Middle{})])
def busy_line(+text: String) -> P.Tree:
  P.layout(named(A11yRole.Status{}, text), P.Horizontal{}, 8, 0, 0, 0, P.Leading{}, [spinner(14), words("Status", text, small_type(), ink(), P.Middle{})])
def retry_line(+text: String, align: P.Align) -> P.Tree:
  P.layout(named(A11yRole.Status{}, text), P.Horizontal{}, 6, 0, 0, 0, align, [alert(), words("Failed", text, small_type(), ink(), P.Middle{}), words("Retry", "Reintentar", small_type(), ink(), P.Middle{})])
def append_trees(xs: List<&2, P.Tree>, ys: List<&2, P.Tree>) -> List<&2, P.Tree>:
  match xs:
    case Nil{}: ys
    case Con{x, rest}: Con{x, append_trees(rest, ys)}

# Button
# ------

# Not approved: provisional drawings (camera, photo, close, back, mute,
# speaker, menu, files), pending sign-off like the mic and the spinner.
def camera() -> S.Drawing:
  S.Drawing{"Camera", "0", "0", "2.3", [S.Path{"M4 8h3l2-3h6l2 3h3v11H4z"}, S.Path{"M12 16.5a3.5 3.5 0 1 0 0-7a3.5 3.5 0 1 0 0 7z"}]}
def photo_drawing() -> S.Drawing:
  S.Drawing{"Photo", "0", "0", "2.3", [S.Path{"M4 5h16v14H4z"}, S.Path{"M4 16l5-5 4 4 3-3 4 4"}, S.Path{"M15.5 10a1.5 1.5 0 1 0 0-3a1.5 1.5 0 1 0 0 3z"}]}
def close_drawing() -> S.Drawing: S.Drawing{"Close", "0", "0", "2.3", [S.Path{"M6 6l12 12M18 6L6 18"}]}
def back_drawing() -> S.Drawing: S.Drawing{"Back", "0", "0", "2.3", [S.Path{"M15 5l-7 7 7 7"}]}
def mute_drawing() -> S.Drawing: S.Drawing{"Mute", "0", "0", "2.3", [S.Path{"M12 3a3 3 0 0 0-3 3v6a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3z"}, S.Path{"M19 11a7 7 0 0 1-14 0M12 18v3"}, S.Path{"M4 4l16 16"}]}
def speaker_drawing() -> S.Drawing: S.Drawing{"Speaker", "0", "0", "2.3", [S.Path{"M4 9h4l5-4v14l-5-4H4z"}, S.Path{"M16 9a4 4 0 0 1 0 6M18.5 6.5a8 8 0 0 1 0 11"}]}
# The header's menu (two lines, as in the reference) and the attach panel's
# files (a paper clip).
def menu_drawing() -> S.Drawing: S.Drawing{"Menu", "0", "0", "2.1", [S.Path{"M3 7.5h18M3 16.5h18"}]}
def files_drawing() -> S.Drawing: S.Drawing{"Files", "0", "0", "2.3", [S.Path{"M16 7v8.5a4 4 0 0 1-8 0V6.5a2.5 2.5 0 0 1 5 0v8.5a1 1 0 0 1-2 0V7.5"}]}
# Hole: the intent (the action the Button performs). Its label and its icon
# are derived from the intent, so a control's label and the message it sends
# cannot disagree (the App maps a tapped Button back to its intent by the
# same label). Form (M): Icon | Text | Both | Within{max} (the text truncated
# to max; the spoken name stays whole). An icon-only Button speaks its
# intent's label; an unlabeled Button cannot be written. Fed by markup
# (Fixed) or by the server (Served: a Remote intent).
type Intent is Data:
  Intent.Send{}
  Intent.Attach{}
  Intent.Dictate{}
  Intent.Camera{}
  Intent.Photo{}
  Intent.Files{}
  Intent.Menu{}
  Intent.Search{}
  Intent.Call{}
  Intent.Close{}
  Intent.Back{}
  Intent.Enter{}
  Intent.Retry{}
  Intent.RetrySend{}
  Intent.Reload{}
  Intent.Confirm{}
  Intent.Cancel{}
  Intent.CreateAccess{}
  Intent.Share{}
  Intent.Revoke{}
  Intent.AllowMic{}
  Intent.NotNow{}
  Intent.Mute{}
  Intent.Unmute{}
  Intent.SpeakerOn{}
  Intent.SpeakerOff{}
  Intent.HangUp{}
  Intent.CopyText{}
  Intent.TakeAnother{}
  Intent.GoToChat{}
  Intent.Open{id: U32, who: String}
# The copy of an intent: its message key in a language (Spanish, the App's
# language, and English). The spoken name and the label are the Spanish
# copy unless a component is given another language.
type Lang is Data:
  Lang.Es{}
  Lang.En{}
def es_en(lang: Lang, +es: String, +en: String) -> String:
  match lang:
    case Lang.Es{}: es
    case Lang.En{}: en
def intent_text(i: Intent, +lang: Lang) -> String:
  match i:
    case Intent.Send{}: es_en(lang, "Enviar", "Send")
    case Intent.Attach{}: es_en(lang, "Adjuntar", "Attach")
    case Intent.Dictate{}: es_en(lang, "Dictar", "Dictate")
    case Intent.Camera{}: es_en(lang, "Cámara", "Camera")
    case Intent.Photo{}: es_en(lang, "Fotos", "Photos")
    case Intent.Files{}: es_en(lang, "Archivos", "Files")
    case Intent.Menu{}: es_en(lang, "Menú", "Menu")
    case Intent.Search{}: es_en(lang, "Buscar", "Search")
    case Intent.Call{}: es_en(lang, "Llamar a Near", "Call Near")
    case Intent.Close{}: es_en(lang, "Cerrar", "Close")
    case Intent.Back{}: es_en(lang, "Volver al chat", "Back to the chat")
    case Intent.Enter{}: es_en(lang, "Entrar a Near", "Enter Near")
    case Intent.Retry{}: es_en(lang, "Reintentar", "Retry")
    case Intent.RetrySend{}: es_en(lang, "Reintentar envío", "Retry sending")
    case Intent.Reload{}: es_en(lang, "Reintentar carga", "Retry loading")
    case Intent.Confirm{}: es_en(lang, "Confirmar", "Confirm")
    case Intent.Cancel{}: es_en(lang, "Cancelar", "Cancel")
    case Intent.CreateAccess{}: es_en(lang, "Crear acceso", "Create access")
    case Intent.Share{}: es_en(lang, "Compartir", "Share")
    case Intent.Revoke{}: es_en(lang, "Revocar", "Revoke")
    case Intent.AllowMic{}: es_en(lang, "Permitir micrófono", "Allow microphone")
    case Intent.NotNow{}: es_en(lang, "Ahora no", "Not now")
    case Intent.Mute{}: es_en(lang, "Silenciar", "Mute")
    case Intent.Unmute{}: es_en(lang, "Activar micrófono", "Unmute")
    case Intent.SpeakerOn{}: es_en(lang, "Altavoz", "Speaker")
    case Intent.SpeakerOff{}: es_en(lang, "Quitar altavoz", "Speaker off")
    case Intent.HangUp{}: es_en(lang, "Colgar", "Hang up")
    case Intent.CopyText{}: es_en(lang, "Copiar texto", "Copy text")
    case Intent.TakeAnother{}: es_en(lang, "Tomar otra foto", "Take another photo")
    case Intent.GoToChat{}: es_en(lang, "Ir al chat", "Go to the chat")
    case Intent.Open{+id, who}: es_en(lang, "Ir al mensaje ", "Go to message ") ++ U32.show(U32.add(id, 1)) ++ ": " ++ who
def intent_label(i: Intent) -> String: intent_text(i, Lang.Es{})
def langs() -> List<&2, Lang>: [Lang.Es{}, Lang.En{}]
def intent_icon(i: Intent) -> Maybe<&2, S.Drawing>:
  match i:
    case Intent.Send{}: Some{S.drawing(S.Send{})}
    case Intent.Attach{}: Some{S.drawing(S.Plus{})}
    case Intent.Dictate{}: Some{mic()}
    case Intent.Camera{}: Some{camera()}
    case Intent.Photo{}: Some{photo_drawing()}
    case Intent.Files{}: Some{files_drawing()}
    case Intent.Menu{}: Some{menu_drawing()}
    case Intent.Search{}: Some{S.drawing(S.Search{})}
    case Intent.Call{}: Some{S.drawing(S.Telephone{})}
    case Intent.Close{}: Some{close_drawing()}
    case Intent.Back{}: Some{back_drawing()}
    case Intent.Mute{}: Some{mute_drawing()}
    case Intent.Unmute{}: Some{mute_drawing()}
    case Intent.SpeakerOn{}: Some{speaker_drawing()}
    case Intent.SpeakerOff{}: Some{speaker_drawing()}
    case Intent.HangUp{}: Some{S.drawing(S.Telephone{})}
    case _: None{}
# Every intent with a fixed label (Open carries its message), for the App's
# inverse mapping and the tests (labels are unique).
def intents() -> List<&2, Intent>:
  [Intent.Send{}, Intent.Attach{}, Intent.Dictate{}, Intent.Camera{}, Intent.Photo{}, Intent.Files{}, Intent.Menu{}, Intent.Search{}, Intent.Call{}, Intent.Close{}, Intent.Back{}, Intent.Enter{},
   Intent.Retry{}, Intent.RetrySend{}, Intent.Reload{}, Intent.Confirm{}, Intent.Cancel{}, Intent.CreateAccess{}, Intent.Share{}, Intent.Revoke{}, Intent.AllowMic{}, Intent.NotNow{},
   Intent.Mute{}, Intent.Unmute{}, Intent.SpeakerOn{}, Intent.SpeakerOff{}, Intent.HangUp{}, Intent.CopyText{}, Intent.TakeAnother{}, Intent.GoToChat{}]
type Form is Data:
  Form.Icon{}
  Form.Text{}
  Form.Both{}
  Form.Within{max: U32}
# Internal: what a Button draws.
type Content is Data:
  Label{text: String}
  Icon{path: S.Drawing, label: Spoken}
  Row{items: List<&2, Content>}
def with_icon(icon: Maybe<&2, S.Drawing>, +label: String, +both: Bool) -> Content:
  match icon:
    case None{}: Label{label}
    case Some{+p}: Bool.pick(Content, both, Row{[Icon{p, Spoken.Message{label}}, Label{label}]}, Icon{p, Spoken.Message{label}})
type Feed is Data:
  Fixed{intent: Intent, form: Form}
  Served{form: Form}
type ButtonKind is Data:
  ButtonKind.Primary{}
  ButtonKind.Quiet{}
  ButtonKind.Danger{}
  ButtonKind.Plain{}
# Slice: pressed (Local, Ephemeral; only when Enabled); served content is
# Remote (Server, Persistent): Loading is the button waiting on the server.
type Press is Data:
  Press.Up{}
  Press.Down{}
type FixedState is Data:
  FixedState.Enabled{pressed: Press}
  FixedState.Disabled{}
type ServedState is Data:
  ServedState.Enabled{pressed: Press, content: Remote<&2, Intent>}
  ServedState.Disabled{content: Remote<&2, Intent>}
def ButtonSlice(feed: Feed) -> Data:
  match feed:
    case Fixed{intent, form}: FixedState
    case Served{form}: ServedState
def button_slice() -> List<&2, Part>:
  [Part{"pressed", "Press Up | Down", Source.Local{}, Persistence.Ephemeral{}, "only when Enabled"},
   Part{"intent", "Remote<Intent>", Source.Server{}, Persistence.Persistent{}, "only when Served"},
   Part{"press motion", "Transit<Press>", Source.Local{}, Persistence.Ephemeral{}, ""}]
type Button is Data:
  Button{tree: P.Tree}
type Shade is Data:
  Shade.Rest{}
  Shade.Down{}
  Shade.Off{}
# Plain draws no container (an icon inside a parent's pill, e.g. the
# composer's +); its press region is still 44pt.
type Tone is Data:
  Tone{fill: T.SurfaceRole, stroke: T.LineRole, ink: T.TextRole, state: T.State, bare: Bool}
def shade_state(shade: Shade) -> T.State:
  match shade:
    case Shade.Rest{}: T.State.Rest{}
    case Shade.Down{}: T.State.Pressed{}
    case Shade.Off{}: T.State.Disabled{}
def tone(kind: ButtonKind, +shade: Shade) -> Tone:
  match kind:
    case ButtonKind.Primary{}: Tone{T.SurfaceRole.Accent{}, T.LineRole.Accent{}, T.TextRole.Ink{}, shade_state(shade), False{}}
    case ButtonKind.Quiet{}: Tone{T.SurfaceRole.Surface{}, T.LineRole.Line{}, T.TextRole.Ink{}, shade_state(shade), False{}}
    case ButtonKind.Danger{}: Tone{T.SurfaceRole.Danger{}, T.LineRole.Line{}, T.TextRole.Ink{}, shade_state(shade), False{}}
    case ButtonKind.Plain{}: Tone{T.SurfaceRole.Surface{}, T.LineRole.Line{}, T.TextRole.Ink{}, shade_state(shade), True{}}
def failed_tone() -> Tone: Tone{T.SurfaceRole.Danger{}, T.LineRole.Line{}, T.TextRole.Ink{}, T.State.Rest{}, False{}}
def ink_state(state: T.State) -> T.State:
  match state:
    case T.State.Disabled{}: T.State.Disabled{}
    case _: T.State.Rest{}
def is_off(state: T.State) -> Bool:
  match state:
    case T.State.Disabled{}: True{}
    case _: False{}
def shade(pressed: Press) -> Shade:
  match pressed:
    case Press.Up{}: Shade.Rest{}
    case Press.Down{}: Shade.Down{}
# The widest label before it truncates: three quarters of the column, less
# the pill's padding.
def label_max() -> U32: U32.sub(U32.div(U32.mul(column(), 3), 4), 36)
def content_trees(xs: List<&2, Content>, +color: T.TextRole, +state: T.State) -> List<&2, P.Tree>:
  match xs:
    case Nil{}: []
    case Con{Label{text}, rest}: Con{words_in("Label", fitted(text, TextRule.Truncate{}, label_max(), label_type()), label_type(), color, ink_state(state), P.Middle{}), content_trees(rest, color, state)}
    case Con{Icon{path, label}, rest}: Con{glyph_in(path, 22, ink_state(state)), content_trees(rest, color, state)}
    case Con{Row{items}, rest}: Con{P.layout("Row", P.Horizontal{}, 8, 0, 0, 0, P.Middle{}, content_trees(items, color, state)), content_trees(rest, color, state)}
def only(xs: List<&2, P.Tree>) -> P.Tree:
  match xs:
    case Nil{}: P.Last{}
    case Con{x, rest}: x
def content_tree(c: Content, color: T.TextRole, state: T.State) -> P.Tree:
  only(content_trees([c], color, state))
# The spoken label: a Row speaks its text labels (its icons are decoration),
# or its icons' labels when it has no text.
def texts(xs: List<&2, Content>) -> String:
  match xs:
    case Nil{}: ""
    case Con{Label{text}, rest}: text ++ texts(rest)
    case Con{Icon{path, label}, rest}: texts(rest)
    case Con{Row{items}, rest}: texts(items) ++ texts(rest)
def icon_labels(xs: List<&2, Content>) -> String:
  match xs:
    case Nil{}: ""
    case Con{Label{text}, rest}: icon_labels(rest)
    case Con{Icon{path, label}, rest}: spoken(label) ++ icon_labels(rest)
    case Con{Row{items}, rest}: icon_labels(items) ++ icon_labels(rest)
def either(+a: String, b: String) -> String: Bool.pick(String, String.is_empty(a), b, a)
def label_of(+c: Content) -> String: either(texts([c]), icon_labels([c]))
def is_icon(c: Content) -> Bool:
  match c:
    case Icon{path, label}: True{}
    case _: False{}
def button_name(+state: T.State, +label: String) -> String:
  Bool.pick(String, is_off(state), "button, disabled · " ++ label, named(A11yRole.Button{}, label))
def container(fill: T.SurfaceRole, stroke: T.LineRole, +state: T.State, +w: U32, +h: U32, +bare: Bool) -> P.Tree:
  Bool.pick(P.Tree, bare, P.rounded("Container", P.Fill.None{}, w, h, P.Full{}, P.NoStroke{}, P.Middle{}), P.rounded("Container", P.Solid{fill, state}, w, h, P.Full{}, P.Stroke{stroke, state, "1"}, P.Middle{}))
def shell(fill: T.SurfaceRole, stroke: T.LineRole, +state: T.State, +w: U32, +inset: U32, label: String, inner: P.Tree, +bare: Bool) -> Button:
  Button{P.layout(button_name(state, label), P.Depth{}, 0, 0, w, 44, P.Middle{}, [container(fill, stroke, state, U32.sub(w, U32.mul(2, inset)), U32.sub(44, U32.mul(2, inset)), bare), inner])}
# Icon content draws a circle (Rounded, Full, square); Label and Row a pill,
# at least 44pt wide.
def sized_inset(t: Tone, +content: Content, +name: String, +extra: P.Tree, +busy: Bool, +inset: U32) -> Button:
  match t:
    case Tone{fill, stroke, +color, +state, +bare}:
      +inner = Bool.pick(P.Tree, busy, P.layout("Busy", P.Horizontal{}, 8, 0, 0, 0, P.Middle{}, [content_tree(content, color, state), extra]), content_tree(content, color, state))
      shell(fill, stroke, state, Bool.pick(U32, Bool.and(is_icon(content), Bool.not(busy)), 44, U32.max(44, U32.add(width(inner), 36))), inset, name, inner, bare)
def sized(t: Tone, +content: Content, +name: String, +extra: P.Tree, +busy: Bool) -> Button: sized_inset(t, content, name, extra, busy, 0)
def intent_content_in(+i: Intent, f: Form, +lang: Lang) -> Content:
  match f:
    case Form.Text{}: Label{intent_text(i, lang)}
    case Form.Within{+max}: Label{M.truncate(intent_text(i, lang), max, label_type())}
    case Form.Icon{}: with_icon(intent_icon(i), intent_text(i, lang), False{})
    case Form.Both{}: with_icon(intent_icon(i), intent_text(i, lang), True{})
def intent_content(+i: Intent, f: Form) -> Content: intent_content_in(i, f, Lang.Es{})
def drawn(t: Tone, +i: Intent, f: Form, +extra: P.Tree, +busy: Bool) -> Button: sized(t, intent_content(i, f), intent_label(i), extra, busy)
# Waiting on the server: never takes a tap (disabled), whatever its pose.
def waiting(t: Tone) -> Button:
  match t:
    case Tone{fill, stroke, color, state, +bare}: shell(fill, stroke, T.State.Disabled{}, 96, 0, "Esperando", spinner(20), bare)
def served(t: Tone, content: Remote<&2, Intent>, +f: Form) -> Button:
  match content:
    case Loading{}: waiting(t)
    case Ready{i}: drawn(t, i, f, P.Last{}, False{})
    case Pending{i}: drawn(t, i, f, spinner(16), True{})
    case Failed{Some{i}}: drawn(failed_tone(), i, f, P.Last{}, False{})
    case Failed{None{}}: drawn(failed_tone(), Intent.Retry{}, Form.Text{}, P.Last{}, False{})
def button(+kind: ButtonKind, feed: Feed, slice: ButtonSlice(feed)) -> Button:
  match feed:
    case Fixed{+intent, +form}:
      match slice:
        case FixedState.Enabled{pressed}: drawn(tone(kind, shade(pressed)), intent, form, P.Last{}, False{})
        case FixedState.Disabled{}: drawn(tone(kind, Shade.Off{}), intent, form, P.Last{}, False{})
    case Served{+form}:
      match slice:
        case ServedState.Enabled{pressed, content}: served(tone(kind, shade(pressed)), content, form)
        case ServedState.Disabled{content}: served(tone(kind, Shade.Off{}), content, form)
def press_inset(p: Press) -> U32:
  match p:
    case Press.Up{}: 0
    case Press.Down{}: 2
# Press feedback (Fast): the container shrinks by 2pt each side and the
# Pressed rule applies once the press is half done.
def pressing(+kind: ButtonKind, +intent: Intent, +form: Form, +pressed: Press, motion: Transit<&2, Press>, m: Moment) -> Button:
  match motion:
    case Settled{}: sized_inset(tone(kind, shade(pressed)), intent_content(intent, form), intent_label(intent), P.Last{}, False{}, press_inset(pressed))
    case Transitioning{+from, +to, started_at}:
      +e = ease_of(started_at, m, press_t())
      sized_inset(tone(kind, Bool.pick(Shade, U32.is_ge(e, 500), shade(to), shade(from))), intent_content(intent, form), intent_label(intent), P.Last{}, False{}, lerp(press_inset(from), press_inset(to), e))
def button_tree(b: Button) -> P.Tree:
  match b:
    case Button{tree}: tree
def button_trees(xs: List<&2, Button>) -> List<&2, P.Tree>:
  match xs:
    case Nil{}: []
    case Con{x, rest}: Con{button_tree(x), button_trees(rest)}
# An enabled or a disabled Button for an intent.
def act(+kind: ButtonKind, +intent: Intent, +form: Form) -> Button:
  button(kind, Fixed{intent, form}, FixedState.Enabled{Press.Up{}})
def act_off(+kind: ButtonKind, +intent: Intent, +form: Form) -> Button:
  button(kind, Fixed{intent, form}, FixedState.Disabled{})
# The same in a language: an intent's label in `lang`.
def act_in(+lang: Lang, +kind: ButtonKind, +intent: Intent, +form: Form) -> Button:
  sized(tone(kind, Shade.Rest{}), intent_content_in(intent, form, lang), intent_text(intent, lang), P.Last{}, False{})
def act_off_in(+lang: Lang, +kind: ButtonKind, +intent: Intent, +form: Form) -> Button:
  sized(tone(kind, Shade.Off{}), intent_content_in(intent, form, lang), intent_text(intent, lang), P.Last{}, False{})
# A Button with the app's own text (already in the app's language).
def say(+kind: ButtonKind, +label: String) -> Button:
  sized(tone(kind, Shade.Rest{}), Label{label}, label, P.Last{}, False{})
def say_off(+kind: ButtonKind, +label: String) -> Button:
  sized(tone(kind, Shade.Off{}), Label{label}, label, P.Last{}, False{})
# In a narrower box the label truncates to the box (the name stays whole).
def button_in(+kind: ButtonKind, +intent: Intent, +box: U32) -> Button:
  act(kind, intent, Form.Within{U32.sub(U32.max(box, 44), 36)})
# A round Glass button (the header's menu and call, as in the reference):
# 48pt, the intent's icon in Ink at 28pt, over Content (the thread scrolls
# under the header).
def glass_side() -> U32: 48
def icon_or(m: Maybe<&2, S.Drawing>) -> S.Drawing:
  match m:
    case Some{d}: d
    case None{}: close_drawing()
def glass_button(+intent: Intent) -> Button:
  Button{P.layout(named(A11yRole.Button{}, intent_label(intent)), P.Depth{}, 0, 0, glass_side(), glass_side(), P.Middle{}, [glassy("Container", glass_side(), glass_side(), P.Full{}, T.Backdrop.Content{}), glyph(icon_or(intent_icon(intent)), 28)])}

# Field
# -----

# Holes: placeholder, accessories (icons). Case: Lines (M): Single, or
# Growing up to a cap of lines. Growing has two sub-cases derived from the
# draft: Fits (grows line by line, Normal, continuity) and Capped (the cap is
# reached: it stops growing, scrolls to the end and gains a Shadow over the
# thread). Single truncates. The width is given by the parent.
type Lines is Data:
  Lines.Single{}
  Lines.Growing{cap: U32}
type Growth is Data:
  Growth.Fits{}
  Growth.Capped{}
type Focus is Data:
  Focus.Blurred{}
  Focus.Focused{}
type FieldState is Data:
  FieldState{draft: String, focus: Focus}
def field_slice() -> List<&2, Part>:
  [Part{"draft", "String", Source.Local{}, Persistence.Persistent{}, ""},
   Part{"focus", "Blurred | Focused", Source.Local{}, Persistence.Persistent{}, ""},
   Part{"grow motion", "Transit<lines>", Source.Local{}, Persistence.Ephemeral{}, "only when Growing"}]
# A field without its width: the parent sizes it (the composer fills it).
type FieldMarkup is Data:
  FieldMarkup{lines: Lines, placeholder: String, accessories: List<&2, S.Drawing>, state: FieldState, grow: Transit<&2, U32>, moment: Moment}
def plain(lines: Lines, placeholder: String, accessories: List<&2, S.Drawing>, state: FieldState) -> FieldMarkup:
  FieldMarkup{lines, placeholder, accessories, state, Settled{}, still()}
type Field is Data:
  Field{tree: P.Tree, empty: Bool}
def is_focused(focus: Focus) -> Bool:
  match focus:
    case Focus.Focused{}: True{}
    case Focus.Blurred{}: False{}
def caret() -> P.Tree:
  P.rounded("Caret", P.Fill.None{}, 2, 20, P.Corner{1}, P.Stroke{T.LineRole.Accent{}, T.State.Rest{}, "1"}, P.Middle{})
def field_lines(xs: List<&2, String>, +color: T.TextRole, +focused: Bool) -> List<&2, P.Tree>:
  match xs:
    case Nil{}: Bool.pick(List<&2, P.Tree>, focused, [caret()], [])
    case Con{+x, Nil{}}: [Bool.pick(P.Tree, focused, P.layout("Last line", P.Horizontal{}, 1, 0, 0, 0, P.Leading{}, [words("Line", x, body(), color, P.Middle{}), caret()]), words("Line", x, body(), color, P.Leading{}))]
    case Con{x, rest}: Con{words("Line", x, body(), color, P.Leading{}), field_lines(rest, color, focused)}
def accessory_trees(xs: List<&2, S.Drawing>) -> List<&2, P.Tree>:
  match xs:
    case Nil{}: []
    case Con{x, rest}: Con{aligned(glyph(x, 20), P.Trailing{}), accessory_trees(rest)}
def accessories_width(xs: List<&2, S.Drawing>) -> U32:
  match xs:
    case Nil{}: 0
    case Con{x, rest}: U32.add(30, accessories_width(rest))
def count(xs: List<&2, String>) -> U32:
  match xs:
    case Nil{}: 0
    case Con{x, rest}: U32.add(1, count(rest))
def drop_lines(xs: List<&2, String>, +n: U32) -> List<&2, String>:
  match xs:
    case Nil{}: []
    case Con{+x, +rest}: Bool.pick(List<&2, String>, U32.is_zero(n), Con{x, rest}, drop_lines(rest, U32.sub(n, 1)))
# The last `n` lines: a capped field is scrolled to the end.
def last_lines(+xs: List<&2, String>, +n: U32) -> List<&2, String>:
  drop_lines(xs, U32.sub(count(xs), U32.min(n, count(xs))))
def cap_of(lines: Lines) -> U32:
  match lines:
    case Lines.Single{}: 1
    case Lines.Growing{cap}: cap
def is_single(lines: Lines) -> Bool:
  match lines:
    case Lines.Single{}: True{}
    case _: False{}
def field_height(+n: U32) -> U32: U32.max(44, U32.add(U32.mul(n, line_height(body())), 28))
def text_width(+width: U32, +accessories: List<&2, S.Drawing>) -> U32:
  U32.sub(U32.sub(U32.max(width, U32.add(64, accessories_width(accessories))), 32), accessories_width(accessories))
# All lines of the shown text (draft, or placeholder when empty).
def shown_lines(+lines: Lines, +shown: String, +tw: U32) -> List<&2, String>:
  Bool.pick(List<&2, String>, is_single(lines), [M.truncate(shown, tw, body())], M.lines(shown, tw, body()))
def growth(+lines: Lines, +draft: String, +tw: U32) -> Growth:
  Bool.pick(Growth, Bool.and(Bool.not(is_single(lines)), U32.is_gt(count(M.lines(draft, tw, body())), cap_of(lines))), Growth.Capped{}, Growth.Fits{})
def is_capped(g: Growth) -> Bool:
  match g:
    case Growth.Capped{}: True{}
    case Growth.Fits{}: False{}
def shadow_blur(+lines: Lines, +n: U32) -> U32:
  Bool.pick(U32, Bool.and(Bool.not(is_single(lines)), U32.is_gt(n, cap_of(lines))), 16, 0)
def shadow_of(+blur: U32) -> List<&2, P.Effect>:
  Bool.pick(List<&2, P.Effect>, U32.is_zero(blur), [], [P.Shadow{0, blur}])
def field_motion_h(+lines: Lines, grow: Transit<&2, U32>, m: Moment, +settled: U32) -> U32:
  match grow:
    case Settled{}: settled
    case Transitioning{+from, +to, started_at}: lerp(field_height(U32.min(from, cap_of(lines))), field_height(U32.min(to, cap_of(lines))), ease_of(started_at, m, grow_t()))
def field_motion_blur(+lines: Lines, grow: Transit<&2, U32>, m: Moment, +n: U32) -> U32:
  match grow:
    case Settled{}: shadow_blur(lines, n)
    case Transitioning{+from, +to, started_at}: lerp(shadow_blur(lines, from), shadow_blur(lines, to), ease_of(started_at, m, cap_t()))
def field_box(placeholder: String, +width: U32, +focused: Bool, +empty: Bool, text: P.Tree, +accessories: List<&2, S.Drawing>, +h: U32, +blur: U32) -> Field:
  Field{P.layout(named(A11yRole.Textbox{}, placeholder), P.Depth{}, 0, 0, width, h, P.Leading{}, [
    P.leaf("Container", P.Shape{P.Rounded{width, h, P.Corner{22}}, P.Solid{T.SurfaceRole.Surface{}, T.State.Rest{}}, P.Stroke{Bool.pick(T.LineRole, focused, T.LineRole.Accent{}, hairline()), T.State.Rest{}, Bool.pick(String, focused, "1.5", "1")}, shadow_of(blur)}, width, h, P.Middle{}),
    P.layout("Content", P.Horizontal{}, 10, 0, U32.sub(width, 32), 0, P.Middle{}, Con{text, accessory_trees(accessories)})]), empty}
def field(markup: FieldMarkup, +width: U32) -> Field:
  match markup:
    case FieldMarkup{+lines, +placeholder, +accessories, FieldState{+draft, focus}, +grow, +m}:
      +empty = String.is_empty(draft)
      +focused = is_focused(focus)
      +tw = text_width(width, accessories)
      +all = shown_lines(lines, Bool.pick(String, empty, placeholder, draft), Bool.pick(U32, focused, U32.sub(tw, 3), tw))
      +n = count(all)
      +visible = last_lines(all, cap_of(lines))
      +text = P.layout("Field text", P.Vertical{}, 0, 0, tw, 0, P.Middle{}, field_lines(visible, Bool.pick(T.TextRole, empty, hint(), ink()), focused))
      +settled_h = field_height(count(visible))
      field_box(placeholder, width, focused, empty, text, accessories, field_motion_h(lines, grow, m, settled_h), field_motion_blur(lines, grow, m, n))
def field_tree(f: Field) -> P.Tree:
  match f:
    case Field{tree, empty}: tree
def field_empty(f: Field) -> Bool:
  match f:
    case Field{tree, empty}: empty
# Range: Single truncates (its minimum holds the ellipsis), Growing wraps
# (its minimum holds the longest word of its text); plus padding and
# accessories. The width is unbounded (it fills); the height runs from one
# line to the cap (the Fits → Capped bound).
def text_rule(lines: Lines) -> TextRule:
  match lines:
    case Lines.Single{}: TextRule.Truncate{}
    case Lines.Growing{cap}: TextRule.Wrap{}
def field_min(+lines: Lines, +accessories: List<&2, S.Drawing>, +text: String) -> U32:
  U32.add(U32.add(32, accessories_width(accessories)), U32.max(M.width(M.ellipsis(), body()), rule_min(text, text_rule(lines), body())))
def field_range(+lines: Lines, +accessories: List<&2, S.Drawing>, +text: String) -> Range:
  Range{field_min(lines, accessories, text), 0, 44, field_height(cap_of(lines))}

# Bubble
# ------

# Hole: content: Words{text} (Wrap rule) or Photo{picture} (a Rounded shape
# with an Image fill supplied by the caller). Case: Role (S);
# Presence (S, chosen by the parent): Shown, or Reserved (takes its space,
# draws nothing). Slice depends on the role: my bubble has a delivery status
# (Server, Persistent); Near's bubbles arrive whole. A bubble is at most 75%
# of its box wide.
type Role is Data:
  Role.Mine{}
  Role.Near{}
type Delivery is Data:
  Delivery.Sending{}
  Delivery.Sent{}
  Delivery.Failed{}
type Presence is Data:
  Presence.Shown{}
  Presence.Reserved{}
type Picture is Data:
  Picture{asset: String, width: U32, height: U32, label: String}
type Said is Data:
  Said.Words{text: String}
  Said.Photo{picture: Picture}
def BubbleSlice(role: Role) -> Data:
  match role:
    case Role.Mine{}: Delivery
    case Role.Near{}: Unit
def bubble_slice() -> List<&2, Part>:
  [Part{"delivery", "Sending | Sent | Failed", Source.Server{}, Persistence.Persistent{}, "only when Mine"}]
type Bubble is Data:
  Bubble{tree: P.Tree}
def bubble_max(+box: U32) -> U32: U32.div(U32.mul(box, 3), 4)
def text_max(+box: U32) -> U32: U32.sub(bubble_max(box), 32)
def pill(+align: P.Align, fill: T.SurfaceRole, +text: P.Tree, stroke: P.Stroke) -> P.Tree:
  +w = U32.add(width(text), 32)
  +h = U32.add(height(text), 28)
  P.layout("Bubble", P.Depth{}, 0, 0, w, h, align, [filled("Container", fill, w, h, P.Corner{22}, stroke), text])
def message(text: String, +box: U32) -> P.Tree:
  paragraph("Text", text, body(), ink(), text_max(box), P.Middle{})
# A photo: as wide as 75% of the box allows (at most 220), in its aspect.
def photo_width(+p: Picture, +box: U32) -> U32:
  match p:
    case Picture{asset, w, h, label}: U32.min(220, bubble_max(box))
def photo_height(+p: Picture, +box: U32) -> U32:
  match p:
    case Picture{asset, w, +h, label}: U32.div(U32.mul(photo_width(p, box), h), U32.max(1, w))
def photo_pill(+p: Picture, +align: P.Align, stroke: P.Stroke, +box: U32) -> P.Tree:
  match p:
    case Picture{+asset, +w, +h, +label}:
      +pw = photo_width(Picture{asset, w, h, label}, box)
      +ph = photo_height(Picture{asset, w, h, label}, box)
      P.layout("Photo bubble", P.Depth{}, 0, 0, pw, ph, align, [P.leaf("Photo", P.Shape{P.Rounded{pw, ph, P.Corner{18}}, P.Image{P.Bitmap.Photo{asset, w, h}, 0}, stroke, []}, pw, ph, P.Middle{})])
def said_label(s: Said) -> String:
  match s:
    case Said.Words{text}: text
    case Said.Photo{Picture{asset, w, h, label}}: label
def said_tree(+s: Said, +align: P.Align, fill: T.SurfaceRole, stroke: P.Stroke, +box: U32) -> P.Tree:
  match s:
    case Said.Words{text}: pill(align, fill, message(text, box), stroke)
    case Said.Photo{p}: photo_pill(p, align, stroke, box)
def mine(+said: Said, stroke: P.Stroke, +box: U32) -> P.Tree:
  renamed(said_tree(said, P.Trailing{}, T.SurfaceRole.Mine{}, stroke, box), named(A11yRole.Listitem{}, "Tú: " ++ said_label(said)))
def with_line(+name: String, bubble: P.Tree, line: P.Tree) -> P.Tree:
  P.layout(name, P.Vertical{}, 6, 0, 0, 0, P.Trailing{}, [aligned(bubble, P.Trailing{}), aligned(line, P.Trailing{})])
def shown_bubble(role: Role, slice: BubbleSlice(role), +content: Said, +box: U32) -> P.Tree:
  match role:
    case Role.Mine{}:
      match slice:
        case Delivery.Sending{}: with_line(named(A11yRole.Listitem{}, "Tú: " ++ said_label(content)), mine(content, P.NoStroke{}, box), words("Sending", "Enviando…", small_type(), muted(), P.Trailing{}))
        case Delivery.Sent{}: mine(content, P.NoStroke{}, box)
        case Delivery.Failed{}: with_line(named(A11yRole.Button{}, intent_label(Intent.RetrySend{})), mine(content, edge(hairline()), box), retry_line("No se envió", P.Trailing{}))
    case Role.Near{}: renamed(said_tree(content, P.Leading{}, T.SurfaceRole.Surface{}, P.NoStroke{}, box), named(A11yRole.Listitem{}, "Near: " ++ said_label(content)))
# Reserved: the same box, empty.
def hollow(+t: P.Tree) -> P.Tree:
  spacer("Reserved", width(t), height(t), align_of(t))
def bubble(role: Role, slice: BubbleSlice(role), content: Said, presence: Presence, box: U32) -> Bubble:
  match presence:
    case Presence.Shown{}: Bubble{shown_bubble(role, slice, content, box)}
    case Presence.Reserved{}: Bubble{hollow(shown_bubble(role, slice, content, box))}
def bubble_tree(b: Bubble) -> P.Tree:
  match b:
    case Bubble{tree}: tree
# The pill of a bubble with this text: its size (the flight lands on it).
def pill_width(+text: String, +box: U32) -> U32: U32.add(width(message(text, box)), 32)
def pill_height(+text: String, +box: U32) -> U32: U32.add(height(message(text, box)), 28)
# Range: the longest word plus padding (Wrap rule) up to 75% of the box.
def bubble_range(+text: String, +box: U32) -> Range:
  Range{U32.max(44, U32.add(32, M.longest_word(text, body()))), bubble_max(box), 44, 0}

# Badge
# -----

# Hole: text (Truncate rule, at most 5/8 of the column). No cases, no slice.
# The "Near" label under the pet is Badge("Near"). A Glass pill over Content
# (it overlaps the thread): its text is Ink.
type Badge is Data:
  Badge{tree: P.Tree}
def badge_max() -> U32: U32.div(U32.mul(column(), 5), 8)
def badge(+text: String) -> Badge:
  +shown = M.truncate(text, badge_max(), name_type())
  +w = U32.max(32, U32.add(M.width(shown, name_type()), 30))
  Badge{P.layout(named(A11yRole.Text{}, text), P.Depth{}, 0, 0, w, 32, P.Middle{}, [glassy("Container", w, 32, P.Full{}, T.Backdrop.Content{}), words("Text", shown, name_type(), ink(), P.Middle{})])}
def badge_tree(b: Badge) -> P.Tree:
  match b:
    case Badge{tree}: tree
def badge_range(+text: String) -> Range:
  Range{U32.max(32, U32.add(30, rule_min(text, TextRule.Truncate{}, name_type()))), U32.add(30, U32.min(badge_max(), M.width(text, name_type()))), 32, 32}

# NearIdentity
# ------------

# No holes: the pet and Badge("Near"). Cases: Animation (S), Motion (S). The
# pet is content motion; with Full motion it runs on its clock (Local,
# Ephemeral); Reduced holds the first frame and takes no clock. It also has
# a compact form (the pet alone), which a narrow Header uses.
def IdentitySlice(motion: Motion) -> Data:
  match motion:
    case Motion.Full{}: Clock
    case Motion.Reduced{}: Unit
def identity_slice() -> List<&2, Part>:
  [Part{"clock", "Clock{ms}", Source.Local{}, Persistence.Ephemeral{}, "only when Motion is Full"}]
type NearIdentity is Data:
  NearIdentity{tree: P.Tree, compact: P.Tree}
def pet(+frame: N.Frame) -> P.Tree:
  match frame:
    case N.Frame{pet_id, asset, animation, +time_ms, reduced_motion, row, col, x, y, w, h, sw, sh}:
      P.leaf("Near", P.Shape{P.Rounded{56, 61, P.Corner{0}}, P.Image{P.Bitmap.Atlas{frame}, time_ms}, P.NoStroke{}, []}, 56, 61, P.Middle{})
def identity(+frame: N.Frame) -> NearIdentity:
  NearIdentity{P.layout(named(A11yRole.Img{}, "Near"), P.Vertical{}, 0, 0, 0, 0, P.Middle{}, [pet(frame), badge_tree(badge("Near"))]), renamed(pet(frame), named(A11yRole.Img{}, "Near"))}
def near_identity(animation: N.Animation, motion: Motion, slice: IdentitySlice(motion)) -> NearIdentity:
  match motion:
    case Motion.Full{}:
      match slice:
        case Clock{ms}: identity(N.sample(animation, ms, False{}))
    case Motion.Reduced{}: identity(N.sample(animation, 0, True{}))
def identity_tree(n: NearIdentity) -> P.Tree:
  match n:
    case NearIdentity{tree, compact}: tree
def identity_compact(n: NearIdentity) -> P.Tree:
  match n:
    case NearIdentity{tree, compact}: compact
def identity_range() -> Range: Range{72, 72, 93, 93}

# TypingIndicator
# ---------------

# No holes, no cases. Motion: appear (Fast, continuity) and the dots loop
# (content; never snaps). Whether it shows is the Thread's typing slice.
type Visibility is Data:
  Visibility.Hidden{}
  Visibility.Visible{}
def visible_scale(v: Visibility) -> U32:
  match v:
    case Visibility.Hidden{}: 0
    case Visibility.Visible{}: 1000
type TypingIndicator is Data:
  TypingIndicator{tree: P.Tree}
def scale(+n: U32, +s: U32) -> U32: U32.div(U32.mul(n, s), 1000)
# Dot i rises 0..4pt and falls during the first half of its cycle.
def bounce(+ph: U32) -> U32:
  Bool.pick(U32, U32.is_lt(ph, 250), U32.div(U32.mul(ph, 4), 250), Bool.pick(U32, U32.is_lt(ph, 500), U32.div(U32.mul(U32.sub(500, ph), 4), 250), 0))
def bouncing_dot(+s: U32, +lift: U32) -> P.Tree:
  P.layout("Dot column", P.Vertical{}, 0, 0, U32.max(1, scale(8, s)), U32.max(1, scale(12, s)), P.Middle{}, [spacer("Lift", 1, U32.sub(scale(4, s), scale(lift, s)), P.Middle{}), dot(T.LineRole.Muted{}, scale(8, s))])
def indicator_at(+s: U32, +ph: U32) -> TypingIndicator:
  TypingIndicator{P.layout(named(A11yRole.Status{}, "Near está escribiendo"), P.Depth{}, 0, 0, U32.max(1, scale(64, s)), U32.max(1, scale(36, s)), P.Leading{}, [
    filled("Container", T.SurfaceRole.Surface{}, U32.max(1, scale(64, s)), U32.max(1, scale(36, s)), P.Full{}, P.NoStroke{}),
    P.layout("Dots", P.Horizontal{}, scale(5, s), 0, 0, 0, P.Middle{}, Bool.pick(List<&2, P.Tree>, U32.is_lt(s, 250), [], [bouncing_dot(s, bounce(ph)), bouncing_dot(s, bounce(U32.mod(U32.add(ph, 850), 1000))), bouncing_dot(s, bounce(U32.mod(U32.add(ph, 700), 1000)))]))])}
def typing_indicator(appear: Transit<&2, Visibility>, +m: Moment) -> TypingIndicator:
  match appear:
    case Settled{}: indicator_at(1000, phase(m, Duration.Loop{}))
    case Transitioning{from, to, started_at}: indicator_at(lerp(visible_scale(from), visible_scale(to), ease_of(started_at, m, appear_t())), phase(m, Duration.Loop{}))
def still_indicator() -> TypingIndicator: typing_indicator(Settled{}, still())
def indicator_tree(t: TypingIndicator) -> P.Tree:
  match t:
    case TypingIndicator{tree}: tree

# Header
# ------

# Holes: left, center, right. Size case derived from the box: Full (the
# NearIdentity, centered on the box) or Collapsed (the compact pet) once the
# Full minimum no longer fits. No slice.
type HeaderSize is Data:
  HeaderSize.Full{}
  HeaderSize.Collapsed{}
type Header is Data:
  Header{tree: P.Tree}
def header_min(+side: U32, +center: U32) -> U32: U32.add(U32.mul(2, U32.add(side, 16)), center)
def header_size(+box: U32, +side: U32, +full: U32) -> HeaderSize:
  Bool.pick(HeaderSize, U32.is_ge(box, header_min(side, full)), HeaderSize.Full{}, HeaderSize.Collapsed{})
def header_center(size: HeaderSize, +n: NearIdentity) -> P.Tree:
  match size:
    case HeaderSize.Full{}: identity_tree(n)
    case HeaderSize.Collapsed{}: identity_compact(n)
# The thread scrolls under the header: a backdrop (Gradient from Background
# to Clear, with a Blur) keeps it readable.
def backdrop(+box: U32, +h: U32) -> P.Tree:
  P.leaf("Fade + blur", P.Shape{P.Rounded{box, h, P.Corner{0}}, P.Gradient{T.Stop.Of{T.SurfaceRole.Background{}}, T.Stop.Clear{}, 50}, P.NoStroke{}, [P.Blur{10}]}, box, h, P.Leading{})
# The fade reaches past the header, so the thread fades out before it
# meets the buttons and the badge (as in the reference).
def fade_extra() -> U32: 24
def header(left: Button, +center: NearIdentity, right: Button, +box: U32) -> Header:
  +l = button_tree(left)
  +r = button_tree(right)
  +c = header_center(header_size(box, U32.max(width(l), width(r)), width(identity_tree(center))), center)
  Header{P.layout(named(A11yRole.Banner{}, "Near"), P.Depth{}, 0, 0, box, 0, P.Leading{}, [
    backdrop(box, U32.add(U32.max(height(l), U32.max(height(c), height(r))), fade_extra())),
    aligned(l, P.Leading{}),
    aligned(c, P.Middle{}),
    P.layout("Right", P.Vertical{}, 0, 0, box, 0, P.Leading{}, [aligned(r, P.Trailing{})])])}
def header_tree(h: Header) -> P.Tree:
  match h:
    case Header{tree}: tree
def header_ranges(+side: U32, +n: NearIdentity) -> List<&2, CaseRange>:
  [CaseRange{"Full", Range{header_min(side, width(identity_tree(n))), 0, 93, 93}}, CaseRange{"Collapsed", Range{header_min(side, width(identity_compact(n))), U32.sub(header_min(side, width(identity_tree(n))), 1), 61, 61}}]
def header_threshold(+side: U32, +n: NearIdentity) -> Threshold:
  Threshold{"Header", header_min(side, width(identity_tree(n))), "Collapsed", "Full"}

# Composer
# --------

# One pill: [ + | the text | mic | Send ]. Hole: the Field markup (lines,
# placeholder, draft, focus, grow motion); the pill draws the field's
# container and gives the text the width between its buttons. The + and the
# mic (dictation) are Plain buttons (no container; 44pt press regions). Size
# case (S, from the Conversation): Compact (a phone, the iPhone reference)
# | Regular (the desktop reference). Content case (derived from the draft):
# Empty | Filled. Compact Empty is [ + | placeholder | mic ] with no Send;
# Regular Empty shows Send under the Disabled rule; Filled shows mic and
# Send in both. Compact's pill is Liquid Glass over Base (the composer row
# sits on the Background; nothing scrolls under it); Regular's is Field with
# a faint decorative Edge. Focus switches the edge to the Accent line. Send
# is a filled circle (Action, no ring) with the arrow in Ink, inset from the
# pill's edge by the same padding top, bottom and right. Growing is Fits |
# Capped as in the Field; Capped gives the pill the Shadow. The + opens the
# attach panel (the Conversation's attach menu: Closed | Open). Role:
# group; the text is the textbox.
type AttachMenu is Data:
  AttachMenu.Closed{}
  AttachMenu.Open{}
type ComposerSize is Data:
  ComposerSize.Compact{}
  ComposerSize.Regular{}
# No slice of its own: the size comes from the Conversation, Empty | Filled
# from the draft (the Field markup), the attach menu is the Conversation's.
def composer_slice() -> List<&2, Part>: []
type Composer is Data:
  Composer{tree: P.Tree}
def plus_button() -> Button: act(ButtonKind.Plain{}, Intent.Attach{}, Form.Icon{})
# The mic: a Plain 44pt press region with an 18pt glyph (the reference's
# proportion inside the pill).
def mic_button() -> Button: Button{P.layout(named(A11yRole.Button{}, intent_label(Intent.Dictate{})), P.Depth{}, 0, 0, 44, 44, P.Middle{}, [P.rounded("Container", P.Fill.None{}, 44, 44, P.Full{}, P.NoStroke{}, P.Middle{}), glyph(mic(), 22)])}
# Send: a 44pt press region holding a filled circle inset by send_inset()
# (Action: the icon-only accent; no stroke) and a thin arrow in Ink (11pt,
# stroke 1.55 of 24), both under the state rule.
def send_inset() -> U32: 7
def send_button(+empty: Bool) -> Button:
  +state = Bool.pick(T.State, empty, T.State.Disabled{}, T.State.Rest{})
  +side = U32.sub(44, U32.mul(2, send_inset()))
  Button{P.layout(button_name(state, intent_label(Intent.Send{})), P.Depth{}, 0, 0, 44, 44, P.Middle{}, [P.rounded("Container", P.Solid{T.SurfaceRole.Action{}, state}, side, side, P.Full{}, P.NoStroke{}, P.Middle{}), glyph_stroked(S.drawing(S.Send{}), 11, state, "1.55")])}
def is_compact(s: ComposerSize) -> Bool:
  match s:
    case ComposerSize.Compact{}: True{}
    case ComposerSize.Regular{}: False{}
# Send shows unless the pill is Compact and Empty.
def shows_send(+size: ComposerSize, +empty: Bool) -> Bool: Bool.not(Bool.and(is_compact(size), empty))
def bottom(xs: List<&2, P.Tree>) -> List<&2, P.Tree>:
  match xs:
    case Nil{}: []
    case Con{x, rest}: Con{aligned(x, P.Trailing{}), bottom(rest)}
def trees_width(xs: List<&2, P.Tree>, +gap: U32) -> U32:
  match xs:
    case Nil{}: 0
    case Con{x, rest}: U32.add(U32.add(width(x), gap), trees_width(rest, gap))
# The text's width: the pill less its 44pt buttons and their gaps (three
# with Send, two without).
def pill_text_width(+box: U32) -> U32: U32.sub(U32.max(box, 168), 144)
def text_width_for(+box: U32, +send: Bool) -> U32: Bool.pick(U32, send, pill_text_width(box), U32.sub(U32.max(box, 168), 96))
# The pill's container: Glass over Base (Compact) or Field with the Edge
# (Regular); the Accent line when focused; the Shadow when Capped.
def pill_effects(+size: ComposerSize, +blur: U32) -> List<&2, P.Effect>:
  Bool.pick(List<&2, P.Effect>, is_compact(size), Con{P.glass(T.Backdrop.Base{}), shadow_of(blur)}, shadow_of(blur))
def pill_stroke(+size: ComposerSize, +focused: Bool) -> P.Stroke:
  Bool.pick(P.Stroke, focused, P.Stroke{T.LineRole.Accent{}, T.State.Rest{}, "1.5"}, Bool.pick(P.Stroke, is_compact(size), P.NoStroke{}, P.Stroke{T.LineRole.Edge{}, T.State.Rest{}, "0.5"}))
def pill_container(+size: ComposerSize, +focused: Bool, +box: U32, +h: U32, +blur: U32) -> P.Tree:
  P.leaf("Container", P.Shape{P.Rounded{box, h, P.Corner{22}}, P.Solid{Bool.pick(T.SurfaceRole, is_compact(size), T.SurfaceRole.Glass{}, T.SurfaceRole.Field{}), T.State.Rest{}}, pill_stroke(size, focused), pill_effects(size, blur)}, box, h, P.Middle{})
def send_slot(+send: Bool, +empty: Bool, +align: P.Align) -> List<&2, P.Tree>:
  Bool.pick(List<&2, P.Tree>, send, [aligned(button_tree(send_button(empty)), align)], [])
def composer(markup: FieldMarkup, +size: ComposerSize, +box: U32) -> Composer:
  match markup:
    case FieldMarkup{+lines, +placeholder, accessories, FieldState{+draft, focus}, +grow, +m}:
      +empty = String.is_empty(draft)
      +focused = is_focused(focus)
      +send = shows_send(size, empty)
      +tw = text_width_for(box, send)
      +all = shown_lines(lines, Bool.pick(String, empty, placeholder, draft), Bool.pick(U32, focused, U32.sub(tw, 3), tw))
      +visible = last_lines(all, cap_of(lines))
      +text = P.layout("Field text", P.Vertical{}, 0, 0, tw, 0, P.Middle{}, field_lines(visible, Bool.pick(T.TextRole, empty, hint(), ink()), focused))
      +h = field_motion_h(lines, grow, m, field_height(count(visible)))
      +button_align = Bool.pick(P.Align, U32.is_le(count(visible), 1), P.Middle{}, P.Trailing{})
      +pill = P.layout("Pill", P.Depth{}, 0, 0, box, h, P.Leading{}, [
        pill_container(size, focused, box, h, field_motion_blur(lines, grow, m, count(all))),
        P.layout("Row", P.Horizontal{}, 4, 0, box, h, P.Leading{}, Con{
          aligned(button_tree(plus_button()), button_align),
          Con{P.layout(named(A11yRole.Textbox{}, placeholder), P.Depth{}, 0, 0, tw, h, P.Middle{}, [aligned(text, P.Middle{})]),
          Con{aligned(button_tree(mic_button()), button_align), send_slot(send, empty, button_align)}}})])
      Composer{P.layout(named(A11yRole.Group{}, "Escribir mensaje"), P.Vertical{}, 0, 0, box, 0, P.Leading{}, [pill])}
def composer_tree(c: Composer) -> P.Tree:
  match c:
    case Composer{tree}: tree
# Capped: the draft passes the cap (the App opens the Editor sheet then).
def composer_capped(+draft: String, +box: U32) -> Bool: is_capped(growth(Lines.Growing{4}, draft, pill_text_width(box)))
# Range: the three buttons and the text's minimum; unbounded width.
def composer_range(+lines: Lines, +text: String) -> Range:
  Range{U32.add(144, U32.max(M.width(M.ellipsis(), body()), rule_min(text, text_rule(lines), body()))), 0, 44, field_height(cap_of(lines))}

# The attach panel (opened by the +): a large rounded Glass panel over
# Content, left-aligned over the composer, one row per way to attach:
# Camera, Photos, Files. Each row is a button: its icon in a round dark
# badge (Surface) and its label, the intent's copy in the given language.
def attach_type() -> P.TextType: P.TextType{"Attach", 22, 400}
def attach_w() -> U32: 278
def attach_row(+intent: Intent, +lang: Lang, +w: U32) -> P.Tree:
  +label = intent_text(intent, lang)
  P.layout(named(A11yRole.Button{}, label), P.Depth{}, 0, 0, w, 56, P.Leading{}, [
    P.rounded("Container", P.Fill.None{}, w, 56, P.Corner{20}, P.NoStroke{}, P.Middle{}),
    P.layout("Row", P.Horizontal{}, 18, 0, w, 56, P.Leading{}, [
      P.layout("Badge", P.Depth{}, 0, 0, 48, 48, P.Middle{}, [P.circle("Circle", P.Solid{T.SurfaceRole.Surface{}, T.State.Rest{}}, P.NoStroke{}, 48, P.Middle{}), glyph(icon_or(intent_icon(intent)), 24)]),
      words("Label", label, attach_type(), ink(), P.Middle{})])])
def attach_intents() -> List<&2, Intent>: [Intent.Camera{}, Intent.Photo{}, Intent.Files{}]
def attach_rows(xs: List<&2, Intent>, +lang: Lang, +w: U32) -> List<&2, P.Tree>:
  match xs:
    case Nil{}: []
    case Con{+x, rest}: Con{attach_row(x, lang, w), attach_rows(rest, lang, w)}
def attach_panel(+lang: Lang) -> P.Tree:
  +items = P.layout("Items", P.Vertical{}, 12, 22, attach_w(), 0, P.Leading{}, attach_rows(attach_intents(), lang, U32.sub(attach_w(), 44)))
  P.layout(named(A11yRole.Group{}, intent_text(Intent.Attach{}, lang)), P.Depth{}, 0, 0, attach_w(), height(items), P.Leading{}, [glassy("Panel", attach_w(), height(items), P.Corner{40}, T.Backdrop.Content{}), items])

# Generic invitation and sharing cards
# -------------------------------------------------

def inner_width() -> U32: U32.sub(column(), 40)
def card(+label: String, fill: T.SurfaceRole, stroke: T.LineRole, children: List<&2, P.Tree>) -> P.Tree:
  +inner = P.layout("Content", P.Vertical{}, 14, 0, inner_width(), 0, P.Middle{}, children)
  +h = U32.add(height(inner), 40)
  P.layout(named(A11yRole.Group{}, label), P.Depth{}, 0, 0, column(), h, P.Leading{}, [filled("Card", fill, column(), h, P.Corner{24}, edge(stroke)), inner])
# Card titles wrap.
def title(+text: String) -> P.Tree:
  renamed(paragraph("Title", text, title_type(), ink(), inner_width(), P.Leading{}), named(A11yRole.Heading{}, text))
def actions(buttons: List<&2, Button>) -> P.Tree:
  P.layout("Buttons", P.Horizontal{}, 10, 0, 0, 0, P.Leading{}, button_trees(buttons))
def with_status(xs: List<&2, P.Tree>, status: Maybe<&2, P.Tree>) -> List<&2, P.Tree>:
  match status:
    case None{}: xs
    case Some{line}: append_trees(xs, [line])
def card_range() -> Range: Range{column(), column(), 0, 0}

# Invitación. Holes: title, placeholder, button content (CreateAccess,
# pessimistic). Slice: draft and focus (Local, Persistent); the submit
# request, Remote (Server, Persistent) once sent.
type InviteState is Data:
  InviteState{draft: String, focus: Focus, submit: Maybe<&2, Remote<&2, String>>}
def invite_slice() -> List<&2, Part>:
  [Part{"draft", "String", Source.Local{}, Persistence.Persistent{}, ""},
   Part{"focus", "Blurred | Focused", Source.Local{}, Persistence.Persistent{}, ""},
   Part{"submit", "Remote<name>", Source.Server{}, Persistence.Persistent{}, "once sent"}]
type Invitacion is Data:
  Invitacion{tree: P.Tree}
def in_flight(submit: Maybe<&2, Remote<&2, String>>) -> Bool:
  match submit:
    case Some{Loading{}}: True{}
    case Some{Pending{name}}: True{}
    case _: False{}
def submit_line(submit: Maybe<&2, Remote<&2, String>>) -> Maybe<&2, P.Tree>:
  match submit:
    case None{}: None{}
    case Some{Loading{}}: Some{busy_line("Creando acceso…")}
    case Some{Pending{name}}: Some{busy_line(M.truncate("Creando acceso para " ++ name ++ "…", inner_width(), small_type()))}
    case Some{Ready{name}}: Some{status_line(accent_dot(), M.truncate("Acceso creado para " ++ name, U32.sub(inner_width(), 16), small_type()))}
    case Some{Failed{last}}: Some{retry_line("No se pudo crear el acceso", P.Leading{})}
def invite_button(+intent: Intent, disabled: Bool) -> Button:
  match disabled:
    case True{}: act_off(ButtonKind.Primary{}, intent, Form.Text{})
    case False{}: act(ButtonKind.Primary{}, intent, Form.Text{})
def invitacion(+heading: String, placeholder: String, intent: Intent, slice: InviteState) -> Invitacion:
  match slice:
    case InviteState{+draft, focus, +submit}:
      Invitacion{card("Invitación · " ++ heading, T.SurfaceRole.Background{}, hairline(), with_status([
        title(heading),
        field_tree(field(plain(Lines.Single{}, placeholder, [], FieldState{draft, focus}), inner_width())),
        button_tree(invite_button(intent, Bool.or(String.is_empty(draft), in_flight(submit))))], submit_line(submit)))}

# Compartir. Holes: title, text, Buttons (Share; Revoke is pessimistic).
# Slice: the invitation status, Remote (Server, Persistent).
type Revoke is Data:
  Revoke.Idle{}
  Revoke.InFlight{}
type Invite is Data:
  Invite.Active{revoke: Revoke}
  Invite.Expired{}
  Invite.Revoked{}
def share_slice() -> List<&2, Part>:
  [Part{"invite", "Remote<Active{revoke} | Expired | Revoked>", Source.Server{}, Persistence.Persistent{}, ""}]
type Compartir is Data:
  Compartir{tree: P.Tree}
def invite_line(invite: Invite) -> P.Tree:
  match invite:
    case Invite.Active{Revoke.Idle{}}: status_line(accent_dot(), "Activa")
    case Invite.Active{Revoke.InFlight{}}: busy_line("Revocando…")
    case Invite.Expired{}: status_line(muted_dot(), "Expirada")
    case Invite.Revoked{}: status_line(danger_dot(8), "Revocada")
def share_line(invite: Remote<&2, Invite>) -> P.Tree:
  match invite:
    case Loading{}: busy_line("Cargando estado…")
    case Ready{i}: invite_line(i)
    case Pending{i}: P.layout("Status", P.Vertical{}, 6, 0, 0, 0, P.Leading{}, [invite_line(i), busy_line("Sincronizando…")])
    case Failed{last}: retry_line("No se pudo cargar el estado", P.Leading{})
def compartir(+heading: String, text: String, buttons: List<&2, Button>, invite: Remote<&2, Invite>) -> Compartir:
  Compartir{card("Compartir · " ++ heading, T.SurfaceRole.Raised{}, hairline(), [title(heading), share_line(invite), paragraph("Text", text, note_type(), muted(), inner_width(), P.Leading{}), actions(buttons)])}

# Thread
# ------

# No holes. Slice: messages, Remote (Server, Persistent); scroll offset
# (Local, Persistent); whether Near is typing (Server, Ephemeral); and its
# motion (Local, Ephemeral): Transitioning between two poses (item count,
# keyboard inset, typing). A new item's Reserved slot grows from 0 to its
# full height, pushing older messages up; the keyboard inset grows; Near's
# reply replaces the typing indicator in place. Content is at most the
# readable width; a wider box adds margins.
type Card is Data:
  InvitationCard{card: Invitacion}
  SharingCard{card: Compartir}
type Item is Data:
  Said{bubble: Bubble}
  # The read receipt under my last bubble: "Leído 6:35 p.m." (trailing).
  Receipt{label: String, time: String}
  # A timestamp between messages: "Hoy 4:39 p.m." (centred).
  Stamp{day: String, time: String}
  Waiting{indicator: TypingIndicator}
  Attached{card: Card}
type Typing is Data:
  Typing.Shown{}
  Typing.Hidden{}
type Pose is Data:
  Pose{items: U32, keyboard: U32, typing: Typing}
type ThreadState is Data:
  ThreadState{messages: Remote<&2, List<&2, Item>>, scroll: U32, typing: Typing, keyboard: U32, motion: Transit<&2, Pose>, moment: Moment}
def calm(messages: Remote<&2, List<&2, Item>>, typing: Typing) -> ThreadState:
  ThreadState{messages, 0, typing, 0, Settled{}, still()}
def thread_slice() -> List<&2, Part>:
  [Part{"messages", "Remote<List<Item>>", Source.Server{}, Persistence.Persistent{}, ""},
   Part{"scroll", "U32 offset", Source.Local{}, Persistence.Persistent{}, ""},
   Part{"typing", "Shown | Hidden", Source.Server{}, Persistence.Ephemeral{}, ""},
   Part{"keyboard", "U32 inset", Source.Local{}, Persistence.Ephemeral{}, ""},
   Part{"motion", "Transit<Pose>", Source.Local{}, Persistence.Ephemeral{}, ""}]
type Thread is Data:
  Thread{tree: P.Tree}
# Timestamps and receipts: the day word (or "Leído") bold, the time regular.
def stamp_type() -> P.TextType: P.TextType{"Stamp", 13, 400}
def stamp_bold() -> P.TextType: P.TextType{"Stamp day", 13, 600}
def card_tree(c: Card) -> P.Tree:
  match c:
    case InvitationCard{Invitacion{tree}}: tree
    case SharingCard{Compartir{tree}}: tree
def item_tree(i: Item) -> P.Tree:
  match i:
    case Said{b}: bubble_tree(b)
    case Receipt{+label, +time}: P.layout(named(A11yRole.Text{}, label ++ " " ++ time), P.Horizontal{}, 4, 0, 0, 0, P.Trailing{}, [words("Word", label, stamp_bold(), muted(), P.Middle{}), words("Time", time, stamp_type(), muted(), P.Middle{})])
    case Stamp{+day, +time}: P.layout(named(A11yRole.Text{}, day ++ " " ++ time), P.Horizontal{}, 4, 0, 0, 0, P.Middle{}, [words("Day", day, stamp_bold(), muted(), P.Middle{}), words("Time", time, stamp_type(), muted(), P.Middle{})])
    case Waiting{t}: indicator_tree(t)
    case Attached{c}: card_tree(c)
def item_trees(xs: List<&2, Item>, tail: List<&2, P.Tree>) -> List<&2, P.Tree>:
  match xs:
    case Nil{}: tail
    case Con{x, rest}: Con{item_tree(x), item_trees(rest, tail)}
def skeleton(+w: U32, align: P.Align) -> P.Tree:
  P.rounded("Placeholder", P.Solid{T.SurfaceRole.Surface{}, T.State.Rest{}}, w, 44, P.Full{}, P.NoStroke{}, align)
def empty_state(+box: U32) -> P.Tree:
  P.layout("Empty", P.Depth{}, 0, 0, box, 96, P.Leading{}, [words("Empty", "Aún no hay mensajes", note_type(), muted(), P.Middle{})])
# The load failure is the retry button (a 44pt press region).
def banner(+box: U32) -> P.Tree:
  P.layout(named(A11yRole.Button{}, intent_label(Intent.Reload{})), P.Depth{}, 0, 0, box, 44, P.Leading{}, [
    filled("Container", T.SurfaceRole.Danger{}, box, 44, P.Corner{14}, edge(hairline())),
    aligned(retry_line("No se pudo cargar", P.Middle{}), P.Middle{})])
def is_empty(xs: List<&2, Item>) -> Bool:
  match xs:
    case Nil{}: True{}
    case _: False{}
# A growing slot: the item's box, its height scaled by `e`; at full size it
# is the item itself (a Reserved bubble still draws nothing).
def slot(+t: P.Tree, +e: U32) -> P.Tree:
  Bool.pick(P.Tree, U32.is_ge(e, 1000), t, spacer("Slot", width(t), U32.div(U32.mul(height(t), e), 1000), align_of(t)))
# Near's reply growing out of the typing indicator: until it is full size the
# box morphs (dots first, then empty); at full size it is the bubble.
def morph(+t: P.Tree, +e: U32, +m: Moment) -> P.Tree:
  +w = lerp(64, width(t), e)
  +h = lerp(36, height(t), e)
  Bool.pick(P.Tree, U32.is_ge(e, 1000), t, P.layout("Reply", P.Depth{}, 0, 0, w, h, P.Leading{}, Con{
    filled("Container", T.SurfaceRole.Surface{}, w, h, P.Corner{lerp(18, 22, e)}, P.NoStroke{}),
    Bool.pick(List<&2, P.Tree>, U32.is_lt(e, 400), [aligned(indicator_tree(typing_indicator(Settled{}, m)), P.Middle{})], [])}))
def moving_items(xs: List<&2, Item>, +index: U32, +from: U32, +grows: Bool, +reply: Bool, +e: U32, +m: Moment, tail: List<&2, P.Tree>) -> List<&2, P.Tree>:
  match xs:
    case Nil{}: tail
    case Con{+x, rest}:
      +own = Bool.pick(P.Tree, Bool.and(grows, U32.is_eq(index, from)), Bool.pick(P.Tree, reply, morph(item_tree(x), e, m), slot(item_tree(x), e)), item_tree(x))
      Con{own, moving_items(rest, U32.add(index, 1), from, grows, reply, e, m, tail)}
def is_shown(t: Typing) -> Bool:
  match t:
    case Typing.Shown{}: True{}
    case Typing.Hidden{}: False{}
def typing_tail(+typing: Typing, +appear: Bool, +started_at: U32, +m: Moment) -> List<&2, P.Tree>:
  Bool.pick(List<&2, P.Tree>, is_shown(typing), [indicator_tree(typing_indicator(Bool.pick(Transit<&2, Visibility>, appear, Transitioning{Visibility.Hidden{}, Visibility.Visible{}, started_at}, Settled{}), m))], [])
def ready_trees(+xs: List<&2, Item>, +tail: List<&2, P.Tree>, +box: U32) -> List<&2, P.Tree>:
  Bool.pick(List<&2, P.Tree>, is_empty(xs), Con{empty_state(box), tail}, item_trees(xs, tail))
def static_trees(messages: Remote<&2, List<&2, Item>>, +tail: List<&2, P.Tree>, +box: U32) -> List<&2, P.Tree>:
  match messages:
    case Loading{}: Con{skeleton(180, P.Leading{}), Con{skeleton(140, P.Trailing{}), Con{skeleton(220, P.Leading{}), tail}}}
    case Ready{xs}: ready_trees(xs, tail, box)
    case Pending{xs}: item_trees(xs, Con{busy_line("Sincronizando…"), tail})
    case Failed{Some{xs}}: Con{banner(box), item_trees(xs, tail)}
    case Failed{None{}}: Con{banner(box), tail}
def moving_trees(messages: Remote<&2, List<&2, Item>>, +from: U32, +grows: Bool, +reply: Bool, +e: U32, +m: Moment, +tail: List<&2, P.Tree>, +box: U32) -> List<&2, P.Tree>:
  match messages:
    case Ready{xs}: moving_items(xs, 0, from, grows, reply, e, m, tail)
    case Pending{xs}: moving_items(xs, 0, from, grows, reply, e, m, tail)
    case other: static_trees(other, tail, box)
def content_width(+box: U32) -> U32: U32.min(box, readable())
def thread_frame(+box: U32, items: List<&2, P.Tree>, +inset: U32) -> Thread:
  Thread{P.layout(named(A11yRole.List{}, "Conversación"), P.Vertical{}, 0, 0, box, 0, P.Leading{}, [
    aligned(P.layout("Items", P.Vertical{}, 12, 0, content_width(box), 0, P.Leading{}, items), P.Middle{}),
    spacer("Keyboard inset", box, inset, P.Leading{})])}
def pose_items(p: Pose) -> U32:
  match p:
    case Pose{items, keyboard, typing}: items
def pose_keyboard(p: Pose) -> U32:
  match p:
    case Pose{items, keyboard, typing}: keyboard
def pose_typing(p: Pose) -> Typing:
  match p:
    case Pose{items, keyboard, typing}: typing
def thread(slice: ThreadState, +box: U32) -> Thread:
  match slice:
    case ThreadState{messages, scroll, +typing, keyboard, motion, +m}:
      match motion:
        case Settled{}: thread_frame(box, static_trees(messages, typing_tail(typing, False{}, 0, m), box), keyboard)
        case Transitioning{+from, +to, +started_at}:
          +e = ease_of(started_at, m, item_t())
          +grows = U32.is_ge(pose_items(to), U32.add(pose_items(from), 1))
          +reply = Bool.and(grows, Bool.and(is_shown(pose_typing(from)), Bool.not(is_shown(pose_typing(to)))))
          thread_frame(box, moving_trees(messages, pose_items(from), grows, reply, e, m, typing_tail(pose_typing(to), Bool.not(is_shown(pose_typing(from))), started_at, m), box), lerp(pose_keyboard(from), pose_keyboard(to), e))
def thread_tree(t: Thread) -> P.Tree:
  match t:
    case Thread{tree}: tree
def invitacion_tree(c: Invitacion) -> P.Tree:
  match c:
    case Invitacion{tree}: tree
def compartir_tree(c: Compartir) -> P.Tree:
  match c:
    case Compartir{tree}: tree
def thread_range() -> Range: Range{column(), 0, 0, 0}
# The highlight of an opened search result (the Thread's transition): a ring
# over the item, Accent, its stroke thinning from 3pt to nothing (Slow,
# feedback). Same box as the item: the layout never moves.
def tenths(+n: U32) -> String: U32.show(U32.div(n, 10)) ++ "." ++ U32.show(U32.mod(n, 10))
def ringed(+t: P.Tree, +e: U32) -> P.Tree:
  +sw = lerp(30, 0, e)
  Bool.pick(P.Tree, U32.is_zero(sw), t, P.layout("Highlighted", P.Depth{}, 0, 0, width(t), height(t), align_of(t), [aligned(t, P.Middle{}), P.rounded("Highlight ring", P.Fill.None{}, width(t), height(t), P.Corner{22}, P.Stroke{T.LineRole.Accent{}, T.State.Rest{}, tenths(sw)}, P.Middle{})]))
def marked(i: Item, +e: U32) -> Item:
  match i:
    case Said{Bubble{+t}}: Said{Bubble{ringed(t, e)}}
    case other: other

# Conversation
# ------------

# Conversation = Thread + Composer. Holes: the composer's accessories and
# placeholder. Size case derived from the box: Compact, or Regular once the
# box holds the readable width and its margins (content is centered). Motion
# case: Settled, or Sending = Transitioning{from: composer text box, to: new
# bubble box, started_at} (Local, Ephemeral). While Sending, the composer is
# already cleared, the new bubble is Reserved and its slot grows (the
# Thread's transition), and a flying copy of the bubble is drawn on the top
# Depth layer. Both start at the same started_at with the same duration, so
# the copy lands exactly on the slot when it reaches full size; then the
# screen settles and the bubble is Shown.
type Area is Data:
  Area{x: U32, y: U32, width: U32, height: U32}
type ConversationSize is Data:
  ConversationSize.Compact{}
  ConversationSize.Regular{}
type SettledState is Data:
  SettledState{messages: Remote<&2, List<&2, Item>>, draft: String, focus: Focus, menu: AttachMenu}
type SendingState is Data:
  SendingState{messages: List<&2, Item>, text: String, moment: Moment}
def ConversationSlice(flight: Transit<&2, Area>) -> Data:
  match flight:
    case Settled{}: SettledState
    case Transitioning{from, to, started_at}: SendingState
def conversation_slice() -> List<&2, Part>:
  [Part{"flight", "Settled | Sending{from, to, started_at}", Source.Local{}, Persistence.Ephemeral{}, ""},
   Part{"messages", "Remote<List<Item>>", Source.Server{}, Persistence.Persistent{}, "a Ready list while Sending"},
   Part{"draft, focus", "String, Blurred | Focused", Source.Local{}, Persistence.Persistent{}, "only when Settled"},
   Part{"attach menu", "Closed | Open", Source.Local{}, Persistence.Ephemeral{}, "only when Settled"},
   Part{"text, now", "String, U32", Source.Local{}, Persistence.Ephemeral{}, "only while Sending"}]
type Conversation is Data:
  Conversation{tree: P.Tree}
def margin() -> U32: 24
def regular_min() -> U32: U32.add(readable(), U32.mul(2, margin()))
def conversation_size(+box: U32) -> ConversationSize:
  Bool.pick(ConversationSize, U32.is_ge(box, regular_min()), ConversationSize.Regular{}, ConversationSize.Compact{})
def inner_of(+box: U32) -> U32: Bool.pick(U32, U32.is_ge(box, regular_min()), readable(), box)
# The composer's size follows the Conversation's. Compact insets the pill
# from the thread's edges, as in the iPhone reference.
def composer_size(+box: U32) -> ComposerSize:
  Bool.pick(ComposerSize, U32.is_ge(box, regular_min()), ComposerSize.Regular{}, ComposerSize.Compact{})
def compact_inset() -> U32: 19
def composer_w(+box: U32) -> U32: Bool.pick(U32, U32.is_ge(box, regular_min()), inner_of(box), U32.sub(U32.max(box, U32.add(168, U32.mul(2, compact_inset()))), U32.mul(2, compact_inset())))
# The attach panel, when the menu is Open: a layer over the thread and the
# composer, the panel left-aligned (10pt outside the composer, as in the
# reference) and level with its bottom, over an empty scrim (a tap outside closes it).
def attach_layer(menu: AttachMenu, +box: U32, +box_h: U32) -> List<&2, P.Tree>:
  match menu:
    case AttachMenu.Closed{}: []
    case AttachMenu.Open{}:
      +panel = attach_panel(Lang.Es{})
      [P.layout("Attach layer", P.Depth{}, 0, 0, box, box_h, P.Leading{}, [P.rounded("Menu scrim", P.Fill.None{}, box, box_h, P.Corner{0}, P.NoStroke{}, P.Leading{}), placed_at("Placement", U32.sub(U32.div(U32.sub(box, composer_w(box)), 2), U32.min(10, U32.div(U32.sub(box, composer_w(box)), 2))), U32.sub(box_h, U32.min(box_h, height(panel))), panel)])]
# The Thread and the Composer, without the flight.
# The box height goes to the composer first; the thread area takes the rest.
def body_tree(+placeholder: String, +box: U32, +box_h: U32, messages: Remote<&2, List<&2, Item>>, motion: Transit<&2, Pose>, +m: Moment, draft: String, focus: Focus, menu: AttachMenu) -> P.Tree:
  +inner = inner_of(box)
  +c = composer_tree(composer(FieldMarkup{Lines.Growing{4}, placeholder, [], FieldState{draft, focus}, Settled{}, m}, composer_size(box), composer_w(box)))
  P.layout("Layers", P.Depth{}, 0, 0, box, box_h, P.Leading{}, Con{P.layout("Body", P.Vertical{}, 12, 0, box, box_h, P.Leading{}, [
    P.layout("Thread area", P.Depth{}, 0, 0, box, U32.sub(box_h, U32.add(height(c), 12)), P.Leading{}, [aligned(thread_tree(thread(ThreadState{messages, 0, Typing.Hidden{}, 0, motion, m}, box)), P.Trailing{})]),
    aligned(c, P.Middle{})]), attach_layer(menu, box, box_h)})
def mine_new(+text: String, presence: Presence, +box: U32) -> Item:
  Said{bubble(Role.Mine{}, Delivery.Sending{}, Said.Words{text}, presence, box)}
def append_items(xs: List<&2, Item>, ys: List<&2, Item>) -> List<&2, Item>:
  match xs:
    case Nil{}: ys
    case Con{x, rest}: Con{x, append_items(rest, ys)}
def item_count(xs: List<&2, Item>) -> U32:
  match xs:
    case Nil{}: 0
    case Con{x, rest}: U32.add(1, item_count(rest))
# The Thread's transition while Sending: same started_at, same duration.
def sending_motion(+n: U32, +started_at: U32) -> Transit<&2, Pose>:
  Transitioning{Pose{n, 0, Typing.Hidden{}}, Pose{U32.add(n, 1), 0, Typing.Hidden{}}, started_at}
def find_area(boxes: List<&2, P.Box>, +name: String) -> Area:
  match boxes:
    case Nil{}: Area{0, 0, 0, 0}
    case Con{P.Box{+n, mark, +x, +y, +w, +h, level, layer}, rest}: Bool.pick(Area, String.eq(n, name), Area{x, y, w, h}, find_area(rest, name))
def placed(+t: P.Tree) -> List<&2, P.Box>:
  P.place(t, P.Depth{}, 0, 0, 0, width(t), height(t), 0, 0, 0)
def area_x(a: Area) -> U32:
  match a:
    case Area{x, y, w, h}: x
def area_y(a: Area) -> U32:
  match a:
    case Area{x, y, w, h}: y
def area_w(a: Area) -> U32:
  match a:
    case Area{x, y, w, h}: w
def area_h(a: Area) -> U32:
  match a:
    case Area{x, y, w, h}: h
# Start a send: the composer text box before sending, and the new bubble's
# final box (the pill at the top right of its slot at full size).
def start_send(+placeholder: String, +box: U32, +box_h: U32, +messages: List<&2, Item>, +text: String, +started_at: U32) -> Transit<&2, Area>:
  +inner = inner_of(box)
  +from = find_area(placed(body_tree(placeholder, box, box_h, Ready{messages}, Settled{}, still(), text, Focus.Focused{}, AttachMenu.Closed{})), "Field text")
  +landing = placed(body_tree(placeholder, box, box_h, Ready{append_items(messages, [mine_new(text, Presence.Reserved{}, inner)])}, sending_motion(item_count(messages), started_at), Moment{U32.add(started_at, duration_ms(Duration.Normal{})), Motion.Full{}}, "", Focus.Blurred{}, AttachMenu.Closed{}))
  +s = find_area(landing, "Reserved")
  +pw = pill_width(text, inner)
  Transitioning{from, Area{U32.sub(U32.add(area_x(s), area_w(s)), pw), area_y(s), pw, pill_height(text, inner)}, started_at}
# The flying copy at the interpolated box.
def lerp_area(+a: Area, +b: Area, +e: U32) -> Area:
  Area{lerp(area_x(a), area_x(b), e), lerp(area_y(a), area_y(b), e), lerp(area_w(a), area_w(b), e), lerp(area_h(a), area_h(b), e)}
def flight(+text: String, +at: Area, +box: U32) -> P.Tree:
  P.layout("Flight layer", P.Vertical{}, 0, 0, 0, 0, P.Leading{}, [
    spacer("Offset", 0, area_y(at), P.Leading{}),
    P.layout("Row", P.Horizontal{}, 0, 0, 0, 0, P.Leading{}, [spacer("Offset", area_x(at), 0, P.Leading{}),
      P.layout("Flight", P.Depth{}, 0, 0, U32.max(1, area_w(at)), U32.max(1, area_h(at)), P.Leading{}, [
        filled("Container", T.SurfaceRole.Mine{}, U32.max(1, area_w(at)), U32.max(1, area_h(at)), P.Corner{22}, P.NoStroke{}),
        message(text, box)])])])
def conversation(+placeholder: String, +box: U32, +box_h: U32, flight_case: Transit<&2, Area>, slice: ConversationSlice(flight_case)) -> Conversation:
  match flight_case:
    case Settled{}:
      match slice:
        case SettledState{messages, draft, focus, menu}:
          Conversation{P.layout(named(A11yRole.Group{}, "Conversación con Near"), P.Depth{}, 0, 0, box, 0, P.Leading{}, [body_tree(placeholder, box, box_h, messages, Settled{}, still(), draft, focus, menu)])}
    case Transitioning{+from, +to, +started_at}:
      match slice:
        case SendingState{+messages, +text, +m}:
          +inner = inner_of(box)
          Conversation{P.layout(named(A11yRole.Group{}, "Conversación con Near"), P.Depth{}, 0, 0, box, 0, P.Leading{}, [
            body_tree(placeholder, box, box_h, Ready{append_items(messages, [mine_new(text, Presence.Reserved{}, inner)])}, sending_motion(item_count(messages), started_at), m, "", Focus.Blurred{}, AttachMenu.Closed{}),
            flight(text, lerp_area(from, to, ease_of(started_at, m, send_t())), inner)])}
def conversation_tree(c: Conversation) -> P.Tree:
  match c:
    case Conversation{tree}: tree
def conversation_ranges() -> List<&2, CaseRange>:
  [CaseRange{"Compact", Range{column(), U32.sub(regular_min(), 1), 0, 0}}, CaseRange{"Regular", Range{regular_min(), 0, 0, 0}}]
def conversation_threshold() -> Threshold: Threshold{"Conversation", regular_min(), "Compact", "Regular"}

# Size cases and representative boxes
# ------------------------------------

# Each component's size cases are ranges of the box width its parent gives
# it; it switches case exactly when the current case's minimum no longer
# fits. The thresholds are derived from content (metrics.bend), never picked.
def ceil_div(+a: U32, +b: U32) -> U32: U32.div(U32.add(a, U32.sub(b, 1)), b)
def whole_or_truncated(+full: U32, +min: U32) -> List<&2, CaseRange>:
  [CaseRange{"Whole", Range{full, 0, 0, 0}}, CaseRange{"Truncated", Range{min, U32.sub(full, 1), 0, 0}}]
def button_sizes(+label: String) -> List<&2, CaseRange>:
  whole_or_truncated(U32.max(44, U32.add(36, U32.min(label_max(), M.width(label, label_type())))), U32.max(44, U32.add(36, M.width(M.ellipsis(), label_type()))))
def badge_sizes(+text: String) -> List<&2, CaseRange>:
  whole_or_truncated(U32.add(30, U32.min(badge_max(), M.width(text, name_type()))), U32.max(32, U32.add(30, M.width(M.ellipsis(), name_type()))))
# A bubble is one line while 75% of its box holds the whole line.
def bubble_sizes(+text: String) -> List<&2, CaseRange>:
  +one = ceil_div(U32.mul(U32.add(M.width(text, body()), 32), 4), 3)
  [CaseRange{"One line", Range{one, 0, 0, 0}}, CaseRange{"Wrapped", Range{ceil_div(U32.mul(U32.max(44, U32.add(32, M.longest_word(text, body()))), 4), 3), U32.sub(one, 1), 0, 0}}]
def header_sizes(+side: U32, +n: NearIdentity) -> List<&2, CaseRange>:
  [CaseRange{"Full", Range{header_min(side, width(identity_tree(n))), 0, 0, 0}}, CaseRange{"Collapsed", Range{header_min(side, width(identity_compact(n))), U32.sub(header_min(side, width(identity_tree(n))), 1), 0, 0}}]
def thread_sizes() -> List<&2, CaseRange>:
  [CaseRange{"Compact", Range{column(), U32.sub(readable(), 1), 0, 0}}, CaseRange{"Margins", Range{readable(), 0, 0, 0}}]
def fill_sizes(+min: U32) -> List<&2, CaseRange>: [CaseRange{"Fill", Range{min, 0, 0, 0}}]
def fixed_sizes(+w: U32) -> List<&2, CaseRange>: [CaseRange{"Fixed", Range{w, w, 0, 0}}]
def conversation_sizes() -> List<&2, CaseRange>:
  [CaseRange{"Compact", Range{column(), U32.sub(regular_min(), 1), 0, 0}}, CaseRange{"Regular", Range{regular_min(), 0, 0, 0}}]
def in_case(+w: U32, c: CaseRange) -> Bool:
  match c:
    case CaseRange{name, Range{+a, +b, c2, d}}: Bool.and(U32.is_ge(w, a), Bool.or(U32.is_zero(b), U32.is_le(w, b)))
def case_name(c: CaseRange) -> String:
  match c:
    case CaseRange{name, r}: name
def case_of(+w: U32, cases: List<&2, CaseRange>) -> String:
  match cases:
    case Nil{}: "Overflow"
    case Con{+c, rest}: Bool.pick(String, in_case(w, c), case_name(c), case_of(w, rest))
def case_min(c: CaseRange) -> U32:
  match c:
    case CaseRange{name, Range{a, b, c2, d}}: a
def sizes_min(cases: List<&2, CaseRange>) -> U32:
  match cases:
    case Nil{}: 4294967295
    case Con{c, rest}: U32.min(case_min(c), sizes_min(rest))

# Representative viewports. Components never read them: each viewport gives
# the box a component receives inside the screen (16pt margins, then the
# Conversation column: the readable width once Regular).
type Viewport is Data:
  Viewport{name: String, width: U32, height: U32}
def viewports() -> List<&2, Viewport>:
  [Viewport{"Phone portrait", 390, 844}, Viewport{"Phone landscape", 844, 390}, Viewport{"Phone with keyboard", 390, 500}, Viewport{"Desktop", 1440, 900}]
def screen_box(+vw: U32) -> U32: U32.sub(vw, 32)
def column_box(+vw: U32) -> U32: inner_of(screen_box(vw))
# A representative box: from a viewport, or typical for a case no viewport
# lands in (comfortably inside the case's range).
type Preset is Data:
  Preset{label: String, width: U32, height: U32, size: String}
def typical(c: CaseRange) -> U32:
  match c:
    case CaseRange{name, Range{+a, +b, c2, d}}: Bool.pick(U32, U32.is_zero(b), U32.add(a, 48), U32.div(U32.add(a, b), 2))
def viewport_presets(vps: List<&2, Viewport>, +whole_screen: Bool, +cases: List<&2, CaseRange>) -> List<&2, Preset>:
  match vps:
    case Nil{}: []
    case Con{Viewport{+name, +w, +h}, rest}:
      +bw = Bool.pick(U32, whole_screen, screen_box(w), column_box(w))
      Con{Preset{"in " ++ name ++ ": " ++ U32.show(bw) ++ "×" ++ U32.show(U32.sub(h, 32)), bw, U32.sub(h, 32), case_of(bw, cases)}, viewport_presets(rest, whole_screen, cases)}
def preset_in(ps: List<&2, Preset>, +c: CaseRange) -> Bool:
  match ps:
    case Nil{}: False{}
    case Con{Preset{label, +w, h, size}, rest}: Bool.or(in_case(w, c), preset_in(rest, c))
def append_presets(xs: List<&2, Preset>, ys: List<&2, Preset>) -> List<&2, Preset>:
  match xs:
    case Nil{}: ys
    case Con{x, rest}: Con{x, append_presets(rest, ys)}
def typicals(+ps: List<&2, Preset>, cases: List<&2, CaseRange>, +all: List<&2, CaseRange>) -> List<&2, Preset>:
  match cases:
    case Nil{}: []
    case Con{+c, rest}: append_presets(Bool.pick(List<&2, Preset>, preset_in(ps, c), [], [Preset{"typical " ++ case_name(c) ++ ": " ++ U32.show(typical(c)), typical(c), 0, case_name(c)}]), typicals(ps, rest, all))
# The phone portrait and keyboard boxes have the same width; width-only
# components skip the keyboard preset.
def width_viewports() -> List<&2, Viewport>:
  [Viewport{"Phone portrait", 390, 844}, Viewport{"Phone landscape", 844, 390}, Viewport{"Desktop", 1440, 900}]
def presets(+cases: List<&2, CaseRange>, +whole_screen: Bool, +with_height: Bool) -> List<&2, Preset>:
  +vp = viewport_presets(Bool.pick(List<&2, Viewport>, with_height, viewports(), width_viewports()), whole_screen, cases)
  append_presets(vp, typicals(vp, cases, cases))
def sizes_text(+cases: List<&2, CaseRange>) -> String: "Sizes: " ++ ranges_text(cases) ++ "."

# Printed slices
# --------------

def axes(source: Source, persistence: Persistence) -> String:
  match source persistence:
    case Source.Local{} Persistence.Persistent{}: "Local × Persistent"
    case Source.Local{} Persistence.Ephemeral{}: "Local × Ephemeral"
    case Source.Server{} Persistence.Persistent{}: "Server × Persistent"
    case Source.Server{} Persistence.Ephemeral{}: "Server × Ephemeral"
def part_text(p: Part) -> String:
  match p:
    case Part{name, shape, source, persistence, +when}:
      name ++ ": " ++ shape ++ " (" ++ axes(source, persistence) ++ Bool.pick(String, String.is_empty(when), "", ", " ++ when) ++ ")"
def parts_text(xs: List<&2, Part>) -> String:
  match xs:
    case Nil{}: ""
    case Con{x, Nil{}}: part_text(x)
    case Con{x, rest}: part_text(x) ++ " · " ++ parts_text(rest)
def slice_text(+xs: List<&2, Part>) -> String:
  match xs:
    case Nil{}: "Slice: none."
    case _: "Slice: " ++ parts_text(xs) ++ "."
def append_players(xs: List<&2, P.Player>, ys: List<&2, P.Player>) -> List<&2, P.Player>:
  match xs:
    case Nil{}: ys
    case Con{x, rest}: Con{x, append_players(rest, ys)}

# Scrolled to the end
# -------------------

# A screen gives the Conversation a box of fixed height; the thread is
# scrolled to its end (the scroll slice): the newest items that fit, older
# ones scrolled away above. The newest item always shows.
def thread_height(+xs: List<&2, Item>, +box: U32) -> U32:
  height(thread_tree(thread(calm(Ready{xs}, Typing.Hidden{}), box)))
def newest(+xs: List<&2, Item>, +box: U32, +h: U32) -> List<&2, Item>:
  match xs:
    case Nil{}: []
    case Con{x, Nil{}}: [x]
    case Con{+x, +rest}: Bool.pick(List<&2, Item>, U32.is_le(thread_height(Con{x, rest}, box), h), Con{x, rest}, newest(rest, box, h))
# The thread's room inside a Conversation box: the box less the composer.
def composer_height(+placeholder: String, +box: U32, draft: String, focus: Focus, menu: AttachMenu) -> U32:
  height(composer_tree(composer(FieldMarkup{Lines.Growing{4}, placeholder, [], FieldState{draft, focus}, Settled{}, still()}, composer_size(box), composer_w(box))))
def thread_room(+placeholder: String, +box: U32, +box_h: U32, draft: String, focus: Focus, menu: AttachMenu) -> U32:
  +c = U32.add(composer_height(placeholder, box, draft, focus, menu), 12)
  Bool.pick(U32, U32.is_lt(box_h, c), 0, U32.sub(box_h, c))

# WelcomeHero
# -----------

# The magic-link landing. Holes: title and text (Wrap), the button content
# (the one tap: "Entrar a Near"). Case (S): Arrival, from the URL and the
# session: Link{token} | NoLink | Expired (the session expired; the reason
# is shown). The link is never redeemed on load: only the tap sends Redeem
# (pessimistic). The slice depends on the arrival: with a Link, the redeem
# request (None until tapped, then Remote); otherwise nothing. Motion: the
# sky (Local, Ephemeral): Settled, or Transitioning{Resting, Leaving}: the
# gradient clouds and the hero move down and away (the App's Welcome →
# Conversation transition runs it, revealing the Conversation). Size case
# from its box: Stacked | Beside (the pet beside the text once both fit).
type Arrival is Data:
  Arrival.Link{token: String}
  Arrival.NoLink{}
  Arrival.Expired{}
type Sky is Data:
  Sky.Resting{}
  Sky.Leaving{}
type HeroState is Data:
  HeroState{redeem: Maybe<&2, Remote<&2, String>>}
def HeroSlice(arrival: Arrival) -> Data:
  match arrival:
    case Arrival.Link{token}: HeroState
    case Arrival.NoLink{}: Unit
    case Arrival.Expired{}: Unit
def hero_slice() -> List<&2, Part>:
  [Part{"redeem", "Maybe<Remote<name>>", Source.Server{}, Persistence.Persistent{}, "only with a Link; None until tapped"},
   Part{"sky", "Transit<Resting | Leaving>", Source.Local{}, Persistence.Ephemeral{}, ""}]
type WelcomeHero is Data:
  WelcomeHero{tree: P.Tree}
type HeroSize is Data:
  HeroSize.Stacked{}
  HeroSize.Beside{}
def display_type() -> P.TextType: P.TextType{"Display", 28, 700}
def hero_text() -> U32: column()
def hero_identity() -> NearIdentity: near_identity(N.Waving{}, Motion.Full{}, Clock{0})
def hero_beside_min() -> U32: U32.add(U32.add(width(identity_tree(hero_identity())), 32), U32.add(hero_text(), U32.mul(2, margin())))
def hero_size(+box: U32) -> HeroSize:
  Bool.pick(HeroSize, U32.is_ge(box, hero_beside_min()), HeroSize.Beside{}, HeroSize.Stacked{})
def hero_column(+box: U32) -> U32: U32.min(hero_text(), U32.sub(U32.max(box, U32.add(120, U32.mul(2, margin()))), U32.mul(2, margin())))
def entering(+content: Intent, redeem: Maybe<&2, Remote<&2, String>>, +col: U32) -> List<&2, P.Tree>:
  match redeem:
    case None{}: [button_tree(act(ButtonKind.Primary{}, content, Form.Text{}))]
    case Some{Loading{}}: [button_tree(button(ButtonKind.Primary{}, Served{Form.Text{}}, ServedState.Disabled{Loading{}})), busy_line("Entrando a Near…")]
    case Some{Pending{name}}: [button_tree(act_off(ButtonKind.Primary{}, content, Form.Text{})), busy_line(M.truncate("Entrando como " ++ name ++ "…", U32.sub(col, 22), small_type()))]
    case Some{Ready{name}}: [status_line(accent_dot(), M.truncate("Hola, " ++ name ++ ". Ya entraste.", U32.sub(col, 16), small_type()))]
    case Some{Failed{last}}: [button_tree(button(ButtonKind.Primary{}, Served{Form.Text{}}, ServedState.Enabled{Press.Up{}, Failed{Some{content}}})), status_line(alert(), "No se pudo entrar. Inténtalo otra vez.")]
def arrival_lines(arrival: Arrival, slice: HeroSlice(arrival), +content: Intent, +col: U32) -> List<&2, P.Tree>:
  match arrival:
    case Arrival.Link{token}:
      match slice:
        case HeroState{redeem}: entering(content, redeem, col)
    case Arrival.NoLink{}: [status_line(muted_dot(), "Abre tu enlace de invitación.")]
    case Arrival.Expired{}: [status_line(alert(), "Tu sesión expiró. Abre un enlace nuevo.")]
def hero_copy(+title: String, +text: String, lines: List<&2, P.Tree>, +col: U32) -> P.Tree:
  P.layout("Copy", P.Vertical{}, 16, 0, col, 0, P.Middle{}, Con{renamed(paragraph("Title", title, display_type(), ink(), col, P.Leading{}), named(A11yRole.Heading{}, title)), Con{paragraph("Text", text, body(), muted(), col, P.Leading{}), lines}})
def hero_body(size: HeroSize, ident: P.Tree, copy: P.Tree) -> P.Tree:
  match size:
    case HeroSize.Stacked{}: P.layout("Stacked", P.Vertical{}, 24, 0, 0, 0, P.Middle{}, [aligned(ident, P.Middle{}), copy])
    case HeroSize.Beside{}: P.layout("Beside", P.Horizontal{}, 32, 0, 0, 0, P.Middle{}, [aligned(ident, P.Middle{}), copy])
# Gradient clouds: Rounded (Full) shapes filled Accent or Raised to Clear,
# in the top of the box, so they never sit behind the text.
def cloud(+w: U32, +h: U32, from: T.SurfaceRole) -> P.Tree:
  P.leaf("Cloud", P.Shape{P.Rounded{w, h, P.Full{}}, P.Gradient{T.Stop.Of{from}, T.Stop.Clear{}, 0}, P.NoStroke{}, []}, w, h, P.Leading{})
def clouds(+box: U32, +box_h: U32) -> List<&2, P.Tree>:
  [placed_at("Cloud 1", U32.div(box, 12), U32.div(box_h, 14), cloud(U32.div(U32.mul(box, 7), 10), U32.div(box_h, 6), T.SurfaceRole.Accent{})),
   placed_at("Cloud 2", U32.div(box, 2), U32.div(box_h, 10), cloud(U32.div(box, 2), U32.div(box_h, 7), T.SurfaceRole.Raised{})),
   placed_at("Cloud 3", 0, U32.div(box_h, 6), cloud(U32.div(U32.mul(box, 2), 5), U32.div(box_h, 10), T.SurfaceRole.Accent{}))]
def sky_y(s: Sky, +box_h: U32) -> U32:
  match s:
    case Sky.Resting{}: 0
    case Sky.Leaving{}: box_h
def sky_drop(sky: Transit<&2, Sky>, m: Moment, +box_h: U32) -> U32:
  match sky:
    case Settled{}: 0
    case Transitioning{from, to, +started_at}: lerp(sky_y(from, box_h), sky_y(to, box_h), ease_of(started_at, m, hero_leave_t()))
def welcome_hero(+title: String, +text: String, +content: Intent, arrival: Arrival, slice: HeroSlice(arrival), sky: Transit<&2, Sky>, +m: Moment, +box: U32, +box_h: U32) -> WelcomeHero:
  +col = hero_column(box)
  +inner = P.layout(named(A11yRole.Group{}, "Bienvenida"), P.Depth{}, 0, 0, box, box_h, P.Leading{}, Con{filled("Background", T.SurfaceRole.Background{}, box, box_h, P.Corner{0}, P.NoStroke{}), append_trees(clouds(box, box_h), [aligned(hero_body(hero_size(box), identity_tree(hero_identity()), hero_copy(title, text, arrival_lines(arrival, slice, content, col), col)), P.Middle{})])})
  WelcomeHero{P.layout("Hero viewport", P.Depth{}, 0, 0, box, box_h, P.Leading{}, [placed_at("Hero", 0, sky_drop(sky, m, box_h), inner)])}
# The hero's content height in a box (the screen derives its height ranges
# from its tallest case).
def hero_height(+title: String, +text: String, +content: Intent, arrival: Arrival, slice: HeroSlice(arrival), +box: U32) -> U32:
  +col = hero_column(box)
  height(hero_body(hero_size(box), identity_tree(hero_identity()), hero_copy(title, text, arrival_lines(arrival, slice, content, col), col)))
def hero_tree(h: WelcomeHero) -> P.Tree:
  match h:
    case WelcomeHero{tree}: tree
def hero_sizes() -> List<&2, CaseRange>:
  [CaseRange{"Stacked", Range{column(), U32.sub(hero_beside_min(), 1), 0, 0}}, CaseRange{"Beside", Range{hero_beside_min(), 0, 0, 0}}]
def hero_threshold() -> Threshold: Threshold{"WelcomeHero", hero_beside_min(), "Stacked", "Beside"}

# Search
# ------

# Searching the conversation. Hole: placeholder. Slice: the query (Local,
# Ephemeral); the results are derived by the screen (a pure function over
# its messages). Cases from the results: Recent (empty query: the latest
# messages) | Matches (each result shows its snippet with the match
# highlighted) | Nothing (no matches: an empty state). Each result is a
# button (it opens the message). Role: group; the field is the textbox.
type Found is Data:
  Found{id: U32, label: String, before: String, hit: String, after: String}
type Results is Data:
  Results.Recent{items: List<&2, Found>}
  Results.Matches{items: List<&2, Found>}
  Results.Nothing{query: String}
def search_slice() -> List<&2, Part>:
  [Part{"query", "String", Source.Local{}, Persistence.Ephemeral{}, ""},
   Part{"results", "Recent | Matches | Nothing", Source.Local{}, Persistence.Ephemeral{}, "derived from the messages"}]
type Search is Data:
  Search{tree: P.Tree}
# The match: Ink on an Accent highlight (a Rounded behind the text).
def highlight_text(+text: String) -> P.Tree:
  +w = U32.add(M.width(text, body()), 4)
  P.layout("Match", P.Depth{}, 0, 0, w, line_height(body()), P.Middle{}, [P.rounded("Highlight", P.Solid{T.SurfaceRole.Accent{}, T.State.Rest{}}, w, line_height(body()), P.Corner{4}, P.NoStroke{}, P.Middle{}), words("Text", text, body(), ink(), P.Middle{})])
# The snippet: a little context before the match, the match, and what
# fits after it (Truncate).
def snippet(+f: Found, +w: U32) -> P.Tree:
  match f:
    case Found{id, label, +before, +hit, +after}:
      +b = M.truncate(before, U32.div(w, 3), body())
      +m = Bool.pick(List<&2, P.Tree>, String.is_empty(hit), [], [highlight_text(hit)])
      +room = U32.sub(w, U32.min(w, U32.add(M.width(b, body()), Bool.pick(U32, String.is_empty(hit), 0, U32.add(M.width(hit, body()), 4)))))
      P.layout("Snippet", P.Horizontal{}, 0, 0, 0, 0, P.Leading{}, Con{words("Before", b, body(), muted(), P.Middle{}), append_trees(m, [words("After", M.truncate(after, room, body()), body(), Bool.pick(T.TextRole, String.is_empty(hit), ink(), muted()), P.Middle{})])})
def result_label(f: Found) -> String:
  match f:
    case Found{+id, +label, before, hit, after}: intent_label(Intent.Open{id, label})
def result_row(+f: Found, +w: U32) -> P.Tree:
  match f:
    case Found{id, +label, before, hit, after}:
      +inner = P.layout("Result", P.Vertical{}, 4, 10, w, 0, P.Leading{}, [words("Who", label, small_type(), muted(), P.Leading{}), snippet(f, U32.sub(w, 20))])
      P.layout(named(A11yRole.Button{}, result_label(f)), P.Depth{}, 0, 0, w, height(inner), P.Leading{}, [filled("Container", T.SurfaceRole.Surface{}, w, height(inner), P.Corner{14}, P.NoStroke{}), inner])
def result_rows(xs: List<&2, Found>, +w: U32) -> List<&2, P.Tree>:
  match xs:
    case Nil{}: []
    case Con{x, rest}: Con{result_row(x, w), result_rows(rest, w)}
def results_trees(r: Results, +w: U32) -> List<&2, P.Tree>:
  match r:
    case Results.Recent{xs}: Con{words("Heading", "Recientes", small_type(), muted(), P.Leading{}), result_rows(xs, w)}
    case Results.Matches{xs}: Con{words("Heading", "Resultados", small_type(), muted(), P.Leading{}), result_rows(xs, w)}
    case Results.Nothing{+q}: [P.layout(named(A11yRole.Status{}, "Sin resultados"), P.Depth{}, 0, 0, w, 96, P.Leading{}, [words("Empty", M.truncate("Sin resultados para «" ++ q ++ "»", w, note_type()), note_type(), muted(), P.Middle{})])]
def search_icon_drawing() -> S.Drawing: S.drawing(S.Search{})
def search(+placeholder: String, state: FieldState, results: Results, +w: U32) -> Search:
  Search{P.layout(named(A11yRole.Group{}, "Buscar"), P.Vertical{}, 12, 0, w, 0, P.Leading{}, Con{field_tree(field(plain(Lines.Single{}, placeholder, [search_icon_drawing()], state), w)), results_trees(results, w)})}
def search_tree(s: Search) -> P.Tree:
  match s:
    case Search{tree}: tree

# Sheet
# -----

# A drawer: a Depth layer over the screen, not a screen. Holes: title, body:
# Editor{field markup} (a long draft, with Send) | Detail{bubble, status,
# Buttons} (one message) | Find{search} | Menu{intents} (the header's menu,
# its rows drawn like the attach panel's). Which sheet is open (Closed | Editor |
# Message{id}) is the screen's navigation state: back closes it. Motion
# (Local, Ephemeral): Transitioning{Closed, Open} slides the panel in
# (Normal, continuity). Size case from its box: Bottom (full width, from the
# bottom, over a scrim) | Side (a side panel once the box holds the
# Conversation's Regular width beside it; no scrim).
type SheetBody is Data:
  SheetBody.Editor{markup: FieldMarkup}
  SheetBody.Detail{said: Bubble, status: String, buttons: List<&2, Button>}
  SheetBody.Find{search: Search}
  # The header's menu: one row per intent (only Search for now).
  SheetBody.Menu{items: List<&2, Intent>}
type Openness is Data:
  Openness.Closed{}
  Openness.Open{}
type SheetSize is Data:
  SheetSize.Bottom{}
  SheetSize.Side{}
def sheet_slice() -> List<&2, Part>:
  [Part{"motion", "Transit<Closed | Open>", Source.Local{}, Persistence.Ephemeral{}, ""}]
type Sheet is Data:
  Sheet{tree: P.Tree}
def sheet_w() -> U32: 400
def side_min() -> U32: U32.add(regular_min(), U32.add(24, sheet_w()))
def sheet_size(+box: U32) -> SheetSize:
  Bool.pick(SheetSize, U32.is_ge(box, side_min()), SheetSize.Side{}, SheetSize.Bottom{})
def is_side(s: SheetSize) -> Bool:
  match s:
    case SheetSize.Side{}: True{}
    case SheetSize.Bottom{}: False{}
def close_button() -> Button: act(ButtonKind.Quiet{}, Intent.Close{}, Form.Icon{})
def back_button() -> Button: act(ButtonKind.Quiet{}, Intent.Back{}, Form.Icon{})
def sheet_top(+title: String, +w: U32) -> P.Tree:
  +t = renamed(words("Title", M.truncate(title, U32.sub(w, 56), title_type()), title_type(), ink(), P.Middle{}), named(A11yRole.Heading{}, title))
  P.layout("Top", P.Horizontal{}, 0, 0, w, 0, P.Leading{}, [t, spacer("Room", U32.sub(w, U32.add(width(t), 44)), 1, P.Middle{}), aligned(button_tree(close_button()), P.Middle{})])
def grabber(+side: Bool) -> List<&2, P.Tree>:
  Bool.pick(List<&2, P.Tree>, side, [], [P.rounded("Grabber", P.Solid{T.SurfaceRole.Background{}, T.State.Rest{}}, 36, 6, P.Full{}, P.Stroke{T.LineRole.Muted{}, T.State.Rest{}, "1"}, P.Middle{})])
def sheet_content(body: SheetBody, +w: U32) -> List<&2, P.Tree>:
  match body:
    case SheetBody.Editor{markup}:
      +f = field(markup, w)
      [field_tree(f), aligned(button_tree(invite_button(Intent.Send{}, field_empty(f))), P.Trailing{})]
    case SheetBody.Find{x}: [search_tree(x)]
    case SheetBody.Menu{xs}: attach_rows(xs, Lang.Es{}, w)
    case SheetBody.Detail{said, +status, buttons}:
      [P.layout("Lane", P.Vertical{}, 0, 0, w, 0, P.Leading{}, [bubble_tree(said)]), status_line(muted_dot(), status), actions(buttons)]
def sheet_panel(+side: Bool, +title: String, body: SheetBody, +w: U32, +box_h: U32) -> P.Tree:
  +inner = P.layout("Content", P.Vertical{}, 16, 20, w, 0, P.Leading{}, append_trees(grabber(side), Con{sheet_top(title, U32.sub(w, 40)), sheet_content(body, U32.sub(w, 40))}))
  +h = Bool.pick(U32, side, box_h, U32.min(height(inner), box_h))
  P.layout("Panel", P.Depth{}, 0, 0, w, h, P.Leading{}, [filled("Container", T.SurfaceRole.Raised{}, w, h, P.Corner{24}, edge(hairline())), aligned(inner, P.Leading{})])
def open_off(o: Openness, +extent: U32) -> U32:
  match o:
    case Openness.Closed{}: extent
    case Openness.Open{}: 0
def sheet_offset(motion: Transit<&2, Openness>, m: Moment, +extent: U32) -> U32:
  match motion:
    case Settled{}: 0
    case Transitioning{from, to, +started_at}: lerp(open_off(from, extent), open_off(to, extent), ease_of(started_at, m, sheet_t()))
# The scrim: Background under the Disabled rule (50% opacity).
def scrim(+box: U32, +box_h: U32) -> P.Tree:
  P.rounded("Scrim", P.Solid{T.SurfaceRole.Background{}, T.State.Disabled{}}, box, box_h, P.Corner{0}, P.NoStroke{}, P.Leading{})
def sheet(+title: String, body: SheetBody, motion: Transit<&2, Openness>, +m: Moment, +box: U32, +box_h: U32) -> Sheet:
  +side = is_side(sheet_size(box))
  +pw = Bool.pick(U32, side, sheet_w(), box)
  +p = sheet_panel(side, title, body, pw, box_h)
  +off = sheet_offset(motion, m, Bool.pick(U32, side, pw, height(p)))
  +x = Bool.pick(U32, side, U32.add(U32.sub(box, pw), off), 0)
  +y = Bool.pick(U32, side, 0, U32.add(U32.sub(box_h, height(p)), off))
  Sheet{P.layout(named(A11yRole.Dialog{}, title), P.Depth{}, 0, 0, box, box_h, P.Leading{}, append_trees(Bool.pick(List<&2, P.Tree>, side, [], [scrim(box, box_h)]), [placed_at("Placement", x, y, p)]))}
def sheet_tree(s: Sheet) -> P.Tree:
  match s:
    case Sheet{tree}: tree
def sheet_sizes() -> List<&2, CaseRange>:
  [CaseRange{"Bottom", Range{column(), U32.sub(side_min(), 1), 0, 0}}, CaseRange{"Side", Range{side_min(), 0, 0, 0}}]
def sheet_threshold() -> Threshold: Threshold{"Sheet", side_min(), "Bottom", "Side"}

# CallControls
# ------------

# No holes. Case (S): Permission Unknown | Granted | Denied (the browser's
# microphone permission). The slice depends on it: Unknown carries the
# request (Idle, or Prompting while the browser asks: pessimistic); Granted
# the call (phase Ringing{since} | Connected{since} | Ended{at}, mic,
# speaker and the moment, for the timer); Denied nothing. Phase changes are
# Instant (status). Sound is the Call screen's output, not drawn here.
type Permission is Data:
  Permission.Unknown{}
  Permission.Granted{}
  Permission.Denied{}
type Asking is Data:
  Asking.Idle{}
  Asking.Prompting{}
type Phase is Data:
  Phase.Ringing{since: U32}
  Phase.Connected{since: U32}
  Phase.Ended{at: U32}
type Mic is Data:
  Mic.Live{}
  Mic.Muted{}
type Speaker is Data:
  Speaker.Off{}
  Speaker.On{}
type LiveCall is Data:
  LiveCall{phase: Phase, mic: Mic, speaker: Speaker, moment: Moment}
def CallSlice(permission: Permission) -> Data:
  match permission:
    case Permission.Unknown{}: Asking
    case Permission.Granted{}: LiveCall
    case Permission.Denied{}: Unit
def call_slice() -> List<&2, Part>:
  [Part{"request", "Idle | Prompting", Source.Local{}, Persistence.Ephemeral{}, "only when Unknown"},
   Part{"phase", "Ringing{since} | Connected{since} | Ended{at}", Source.Server{}, Persistence.Ephemeral{}, "only when Granted"},
   Part{"mic, speaker", "Live | Muted, Off | On", Source.Local{}, Persistence.Ephemeral{}, "only when Granted"},
   Part{"now", "Moment", Source.Local{}, Persistence.Ephemeral{}, "only when Granted (the timer)"}]
type CallControls is Data:
  CallControls{tree: P.Tree}
def control(+label: String, b: Button) -> P.Tree:
  P.layout("Control", P.Vertical{}, 6, 0, 76, 0, P.Middle{}, [aligned(button_tree(b), P.Middle{}), words("Caption", label, small_type(), muted(), P.Middle{})])
def toggle(+on: Bool, +when_on: Intent, +when_off: Intent) -> Button:
  act(Bool.pick(ButtonKind, on, ButtonKind.Primary{}, ButtonKind.Quiet{}), Bool.pick(Intent, on, when_on, when_off), Form.Icon{})
def is_muted(m: Mic) -> Bool:
  match m:
    case Mic.Muted{}: True{}
    case Mic.Live{}: False{}
def is_on(s: Speaker) -> Bool:
  match s:
    case Speaker.On{}: True{}
    case Speaker.Off{}: False{}
def hang_up() -> Button: act(ButtonKind.Danger{}, Intent.HangUp{}, Form.Icon{})
def live_controls(+muted: Bool, +loud: Bool) -> P.Tree:
  P.layout("Controls", P.Horizontal{}, 12, 0, 0, 0, P.Middle{}, [
    control(Bool.pick(String, muted, "Silenciado", "Silenciar"), toggle(muted, Intent.Unmute{}, Intent.Mute{})),
    control("Altavoz", toggle(loud, Intent.SpeakerOff{}, Intent.SpeakerOn{})),
    control("Colgar", hang_up())])
def two_digits(+n: U32) -> String: Bool.pick(String, U32.is_lt(n, 10), "0" ++ U32.show(n), U32.show(n))
def clock_text(+ms: U32) -> String:
  +s = U32.div(ms, 1000)
  U32.show(U32.div(s, 60)) ++ ":" ++ two_digits(U32.mod(s, 60))
def elapsed(+since: U32, m: Moment) -> U32:
  match m:
    case Moment{+now, pref}: Bool.pick(U32, U32.is_lt(now, since), 0, U32.sub(now, since))
def call_status(+text: String) -> P.Tree:
  renamed(paragraph("Status", text, body(), ink(), column(), P.Middle{}), named(A11yRole.Status{}, text))
def centered(buttons: List<&2, Button>) -> P.Tree: aligned(actions(buttons), P.Middle{})
def phase_trees(phase: Phase, +muted: Bool, +loud: Bool, m: Moment) -> List<&2, P.Tree>:
  match phase:
    case Phase.Ringing{since}: [call_status("Llamando a Near…"), live_controls(muted, loud)]
    case Phase.Connected{+since}: [call_status("En llamada · " ++ clock_text(elapsed(since, m))), live_controls(muted, loud)]
    case Phase.Ended{at}: [call_status("Llamada terminada"), centered([act(ButtonKind.Primary{}, Intent.Back{}, Form.Text{})])]
def call_trees(permission: Permission, slice: CallSlice(permission)) -> List<&2, P.Tree>:
  match permission:
    case Permission.Unknown{}:
      match slice:
        case Asking.Idle{}: [call_status("Near necesita tu micrófono para hablar contigo."), centered([act(ButtonKind.Quiet{}, Intent.NotNow{}, Form.Text{}), act(ButtonKind.Primary{}, Intent.AllowMic{}, Form.Text{})])]
        case Asking.Prompting{}: [call_status("Acepta el permiso del navegador para continuar."), centered([act_off(ButtonKind.Quiet{}, Intent.NotNow{}, Form.Text{}), button(ButtonKind.Primary{}, Served{Form.Text{}}, ServedState.Disabled{Loading{}})])]
    case Permission.Granted{}:
      match slice:
        case LiveCall{phase, mic, speaker, m}: phase_trees(phase, is_muted(mic), is_on(speaker), m)
    case Permission.Denied{}: [call_status("El micrófono está bloqueado. Actívalo en los ajustes del navegador."), centered([act(ButtonKind.Quiet{}, Intent.Retry{}, Form.Text{}), act(ButtonKind.Primary{}, Intent.Back{}, Form.Text{})])]
def call_controls(permission: Permission, slice: CallSlice(permission)) -> CallControls:
  CallControls{P.layout(named(A11yRole.Group{}, "Llamada"), P.Vertical{}, 20, 0, column(), 0, P.Middle{}, call_trees(permission, slice))}
def call_controls_tree(c: CallControls) -> P.Tree:
  match c:
    case CallControls{tree}: tree

# App blocks
# ----------

# One call each, sized to the column: an app's view needs no widths or slices.
def caption(+text: String) -> P.Tree:
  paragraph("Caption", text, body(), hint(), column(), P.Leading{})
def input(+placeholder: String, value: String) -> P.Tree:
  field_tree(field(plain(Lines.Single{}, placeholder, [], FieldState{value, Focus.Blurred{}}), column()))
def action(+kind: ButtonKind, +label: String, enabled: Bool) -> P.Tree:
  button_tree(Bool.pick(Button, enabled, say(kind, label), say_off(kind, label)))
# A line of a conversation: who said it and what.
type Line is Data:
  Line{role: Role, text: String}
def said(line: Line) -> P.Tree:
  match line:
    case Line{role, text}:
      match role:
        case Role.Mine{}: bubble_tree(bubble(Role.Mine{}, Delivery.Sent{}, Said.Words{text}, Presence.Shown{}, column()))
        case Role.Near{}: bubble_tree(bubble(Role.Near{}, Unit{}, Said.Words{text}, Presence.Shown{}, column()))
def lines(xs: List<&2, Line>) -> List<&2, P.Tree>:
  match xs:
    case []: []
    case x <> rest: said(x) <> lines(rest)
# A whole screen (the column plus its margins), and a stack inside it.
def screen(+name: String, children: List<&2, P.Tree>) -> P.Tree:
  P.layout(name, P.Vertical{}, 16, 24, U32.add(column(), 48), 0, P.Middle{}, children)
def stack(+name: String, children: List<&2, P.Tree>) -> P.Tree:
  P.layout(name, P.Vertical{}, 10, 0, column(), 0, P.Leading{}, children)
