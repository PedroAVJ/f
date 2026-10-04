# an import with no alias brings the file's own types, constructors and defs
# in bare (not its main), and a path may leave off .bend
import ./bare/shapes
import ./bare/area as A

def main() -> IO(Unit):
  IO.print(U32.show(area(Square{3})) ++ " " ++ U32.show(area(Circle{2})) ++ " " ++ U32.show(A.area(5)))
#|9 12 5
