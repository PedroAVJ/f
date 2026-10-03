import Base

def kernel(x: U32) -> U32:
  +x = x
  a = U32.add(U32.mul(x, 4294967295), 7)
  b = U32.xor(U32.div(x, x), U32.mod(x, 0))
  c = U32.xor(U32.shln(x, 32n), U32.shrn(x, 33n))
  U32.xor(a, U32.add(b, c))
def main() -> List<U32>:
  a = kernel!(0)
  b = kernel!(1)
  c = kernel!(4294967295)
  [a, b, c]
#|[7, 6, 4294967286]
