import Base
import ../../bend2/std/F/browser/host.bend as Host

def walk(fuel: Nat, +left: U32, right: U32) -> U32 & U32:
  match fuel:
    case 0n: (left, right)
    case 1n+next: walk(next, U32.add(left, 1), U32.add(right, left))

def present(pair: U32 & U32, f: U32 -> U32) -> String:
  (left, right) = pair
  U32.show(f(left)) ++ ":" ++ U32.show(right)

def advance(pair: U32 & U32) -> U32 & U32:
  (left, right) = pair
  (right, U32.add(left, 1))

def reply_text(reply: Host.Reply) -> String:
  match reply:
    case Host.Reply{status, data}: data

def finish(pair: U32 & U32) -> IO(Unit):
  do IO<Unit>:
    printed : Unit <- IO.print(present(pair, x => U32.add(x, 11)))
    reply : Host.Reply <- Host.request(71, "continue")
    IO.print(reply_text(reply))

def main() -> IO(Unit): finish(walk(10000n, 3, 7))
#|10014:50025007
#|browser host unavailable
