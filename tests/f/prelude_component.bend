import Base
import UI
import ../../bend2/std/F/ui/primitives.bend as P

def main() -> IO(Unit):
  IO.print(U32.show(P.height_of(P.size(Button.tree(Button.action(ButtonKind.Primary{}, Intent.Send{}, Form.Both{}))))))
#|44
