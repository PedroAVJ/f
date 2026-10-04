# a module whose own names an import with no alias brings in bare; its main
# stays its own
type Shape is Data:
  Square{side: U32}
  Circle{r: U32}

def area(s: Shape) -> U32:
  match s:
    case Square{+x}: (x * x : U32)
    case Circle{+r}: (3 * r * r : U32)

def main() -> IO(Unit):
  IO.print("shapes")
