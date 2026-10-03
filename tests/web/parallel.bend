import Base

def sum(depth: Nat, +x: U32) -> U32:
  match depth:
    case Zero{}: x
    case Succ{+n}:
      a b = sum(n, x) sum(n, U32.add(x, 1))
      U32.add(a, b)
def main() -> U32: sum(18n, 1)
#|2621440
