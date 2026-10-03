import Base
import ../../bend2/std/F/ui/components.bend as C
import ../../bend2/std/F/ui/nearling.bend as N
import ../../bend2/std/F/browser/components.bend as Render

def frame(asset: String) -> N.Frame:
  N.Frame{"sprite",asset,N.Idle{},0,False{},0,1,16,2,16,12,32,16}
def main() -> IO(Unit):
  do IO<Unit>:
    crop : Unit <- IO.print(Render.html(C.Symbol{C.Sprite{frame("./atlas&\"<>.svg")}}))
    IO.print("blank:" ++ Render.html(C.Symbol{C.Sprite{frame("")}}))

#|<svg class="sprite" role="img" aria-label="Near" width="16" height="12" viewBox="16 2 16 12" preserveAspectRatio="none"><image href="./atlas&amp;&quot;&lt;&gt;.svg" width="32" height="16"/></svg>
#|blank:
