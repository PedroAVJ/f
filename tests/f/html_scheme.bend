# HTML selects the same role tokens as Canvas. Existing exports keep their
# Light markup, and selecting Dark preserves input values and HTML escaping.
import Base
import ../../bend2/std/F/ui/primitives.bend as P
import ../../bend2/std/F/ui/tokens.bend as T
import ../../bend2/std/F/ui/symbols.bend as S
import ../../bend2/std/F/browser/scene.bend as Scene

def tile() -> P.UI:
  P.rounded("tile", P.Solid{T.SurfaceRole.Background{}, T.State.Rest{}}, 32, 24, P.Full{}, P.NoStroke{}, P.Leading{})
def gradient() -> P.Fill:
  P.Gradient{T.Stop.Of{T.SurfaceRole.Accent{}},T.Stop.Clear{},50}
def ink() -> P.Stroke: P.Stroke{T.LineRole.Ink{},T.State.Rest{},"1.5"}
def view() -> P.UI:
  P.layout("frame",P.Vertical{},8,4,160,0,P.Leading{},[
    tile(),
    P.text("label","Dot <&\"'>",P.TextType{"Body",17,600},T.TextRole.Ink{},144,24,P.Leading{}),
    P.rounded("gradient",gradient(),32,24,P.Corner{4},ink(),P.Leading{}),
    P.leaf("glass",P.Shape{P.Rounded{32,24,P.Corner{4}},P.Solid{T.SurfaceRole.Background{},T.State.Rest{}},P.NoStroke{},[P.Glass{8,140,2,30,80,T.LineRole.Edge{},T.Backdrop.Base{}}]},32,24,P.Leading{}),
    P.leaf("path",P.Shape{P.Path{S.Drawing{"glyph <&\"'>","0","0","1",[S.Path{"M0 0\" onload=\"x<&'>"}]}},gradient(),ink(),[]},24,24,P.Leading{}),
    P.layout("textbox · Write <&\"'>",P.Depth{},0,0,144,24,P.Leading{},[
      P.text("value · \" autofocus onfocus=\"x<&'>","\" autofocus onfocus=\"x<&'>",P.TextType{"Body",17,400},T.TextRole.Ink{},144,24,P.Leading{})]),
    P.rounded("button, disabled · Later",P.Solid{T.SurfaceRole.Surface{},T.State.Disabled{}},32,24,P.Full{},P.NoStroke{},P.Leading{}),
    P.rounded("photo",P.Image{P.Bitmap.Photo{"./photo\" onerror=\"x<&'>",32,24},0},32,24,P.Full{},P.NoStroke{},P.Leading{})])

def main() -> IO(Unit):
  +light = Scene.html(view())
  +dark = Scene.html_in(view(),T.Scheme.Dark{})
  +field = Scene.textbox_html("textbox · Write","\" autofocus onfocus=\"x<&'>",0,0,32,24,1)
  +bad = Scene.stroke_css_in(P.Stroke{T.LineRole.Ink{},T.State.Rest{},"1\" onclick=\"x"},T.Scheme.Dark{})
  do IO<Unit>:
    IO.print(Bool.show(String.eq(Scene.html(tile()),"<div style=\"position:relative;width:32px;height:24px\"><div style=\"position:absolute;box-sizing:border-box;left:0px;top:0px;width:32px;height:24px;width:32px;height:24px;border-radius:12px;overflow:hidden;--bend-fill:#ffffff;background:var(--bend-fill);box-shadow:;\" ></div></div>")))
    IO.print(Bool.show(String.eq(light,Scene.html_in(view(),T.Scheme.Light{}))))
    IO.print(Bool.show(String.contains(field,"caret-color:#101112;")))
    IO.print(Bool.show(String.contains(dark,"--bend-fill:#000000;")))
    IO.print(Bool.show(String.contains(dark,"color:#f6f7f8;font-family:")))
    IO.print(Bool.show(String.contains(dark,"background:linear-gradient(#2c5785 50% ,rgba(0,0,0,0));")))
    IO.print(Bool.show(String.contains(dark,"box-shadow:inset 0 0 0 1.5px #f6f7f8;")))
    IO.print(Bool.show(String.contains(dark,"inset 0 0 0 0.5px #414141;")))
    IO.print(Bool.show(String.contains(Scene.path_html_in(S.drawing(S.Plus{}),P.Solid{T.SurfaceRole.Background{},T.State.Rest{}},ink(),0,T.Scheme.Dark{}),"fill=\"#000000\"")))
    IO.print(Bool.show(String.contains(dark,"stroke=\"#f6f7f8\" stroke-width=\"1.5\"")))
    IO.print(Bool.show(String.contains(dark,"stop-color=\"#2c5785\"") && String.contains(dark,"stop-color=\"rgba(0,0,0,0)\"")))
    IO.print(Bool.show(String.contains(dark,"caret-color:#f6f7f8;")))
    IO.print(Bool.show(String.contains(dark,"value=\"&quot; autofocus onfocus=&quot;x&lt;&amp;&#39;&gt;\"")))
    IO.print(Bool.show(String.contains(dark,"data-bend-field=\"textbox · Write &lt;&amp;&quot;&#39;&gt;\"")))
    IO.print(Bool.show(String.contains(dark,"aria-label=\"glyph &lt;&amp;&quot;&#39;&gt;\"")))
    IO.print(Bool.show(String.contains(dark,"d=\"M0 0&quot; onload=&quot;x&lt;&amp;&#39;&gt;\"")))
    IO.print(Bool.show(String.contains(dark,"src=\"./photo&quot; onerror=&quot;x&lt;&amp;&#39;&gt;\"")))
    IO.print(Bool.show(String.contains(dark,"data-bend-event=\"button, disabled · Later\" aria-label=\"Later\" role=\"button\" disabled ")))
    IO.print(Bool.show(String.eq(bad,"inset 0 0 0 0px #f6f7f8")))
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
