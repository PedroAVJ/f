import Base

type PairU is Data:
  Pair{a: U32, b: U32}
def recursive(n: Nat) -> U32:
  match n:
    case Zero{}: 0
    case Succ{n}: U32.inc(recursive(n))
def pair(x: U32) -> PairU:
  Pair{x, 9}
def fields(n: U32, p: PairU) -> List<U32>:
  match p:
    case Pair{x, y}: [n, x, y]
def main() -> List<U32>:
  a = recursive!(12n)
  b = pair!(7)
  fields(a, b)
#|[12, 7, 9]
