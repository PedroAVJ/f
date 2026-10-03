import Base

def step(x: U32) -> U32:
  U32.add(U32.mul(x, 3), 1)
def main() -> U32:
  a b = step!(14) step!(15)
  U32.add(a, b)
#|89
