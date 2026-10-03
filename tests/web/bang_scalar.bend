import Base

def step(x: U32) -> U32:
  U32.add(U32.mul(x, 3), 1)
def main() -> U32:
  step!(14)
#|43
