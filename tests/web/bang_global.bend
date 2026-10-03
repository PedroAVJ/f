import Base

def step(x: U32) -> U32:
  U32.add(x, 1)
def main() -> List<U32>:
  a = step!(10)
  b = step(20)
  [a, b]
#|[11, 21]
