import Base

def step(x: U32) -> U32:
  U32.add(x, 1)
def main() -> U32:
  f = {step!(): U32 -> U32}
  f(41)
#|42
