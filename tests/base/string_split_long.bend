import Base

def text(n: Nat, +s: String) -> String:
  match n:
    case 0n: s
    case 1n+p: text(p, s ++ s)

def parts(s: String, sep: Char) -> String:
  String.join(String.split(s, sep), "|")

def main() -> IO(Unit):
  +large = text(13n, "abcdefgh")
  +chunks = String.split(large ++ "\n" ++ large ++ "\n", '\n')
  do IO<Unit>:
    IO.print(Bool.show(String.eq(parts("", ','), "")))
    IO.print(Bool.show(String.eq(parts(",", ','), "|")))
    IO.print(Bool.show(String.eq(parts(",a,,b,", ','), "|a||b|")))
    IO.print(Bool.show(String.eq(parts("alpha", ','), "alpha")))
    IO.print(Bool.show(String.eq(parts("𐐀,é,日本", ','), "𐐀|é|日本")))
    IO.print(Bool.show(Nat.is_eq(List.length(&2, String, chunks), 3n)))
    IO.print(Bool.show(Nat.is_eq(String.length(Maybe.default(&2, String, List.get(&2, String, chunks, 0n), "")), 65536n)))
    IO.print(Bool.show(Nat.is_eq(String.length(Maybe.default(&2, String, List.get(&2, String, chunks, 1n), "")), 65536n)))
    IO.print(Bool.show(String.is_empty(Maybe.default(&2, String, List.get(&2, String, chunks, 2n), "missing"))))

#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
#|True
