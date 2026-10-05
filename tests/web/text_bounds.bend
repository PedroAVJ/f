import Base
import ../../bend2/std/F/ui/metrics.bend as M
import ../../bend2/std/F/ui/primitives.bend as P

def repeat(n: Nat) -> String:
  match n:
    case 0n: ""
    case Succ{k}: "A" ++ repeat(k)

def main() -> IO(Unit):
  +font : P.TextType = P.TextType{"body", 17, 400}
  +width = M.width("AAAA…", font)
  do IO<Unit>:
    IO.print(Bool.show(String.eq(M.truncate(repeat(8192n), width, font), "AAAA…")))
    IO.print(Bool.show(String.eq(M.truncate("AAAA", width, font), "AAAA")))
    IO.print(Bool.show(String.eq(M.truncate("", width, font), "")))
    IO.print(Bool.show(String.eq(M.truncate(repeat(8192n), 0, font), "…")))
#|True
#|True
#|True
#|True
