import Base

# Sharing must not expand a bounded shader into an unbounded expression.
def kernel(x: U32) -> U32:
  +x = x
  a0 = U32.mul(x, x)
  +a0 = a0
  a1 = U32.mul(a0, a0)
  +a1 = a1
  a2 = U32.mul(a1, a1)
  +a2 = a2
  a3 = U32.mul(a2, a2)
  +a3 = a3
  a4 = U32.mul(a3, a3)
  +a4 = a4
  a5 = U32.mul(a4, a4)
  +a5 = a5
  a6 = U32.mul(a5, a5)
  +a6 = a6
  a7 = U32.mul(a6, a6)
  +a7 = a7
  a8 = U32.mul(a7, a7)
  +a8 = a8
  a9 = U32.mul(a8, a8)
  +a9 = a9
  a10 = U32.mul(a9, a9)
  +a10 = a10
  a11 = U32.mul(a10, a10)
  +a11 = a11
  a12 = U32.mul(a11, a11)
  +a12 = a12
  a13 = U32.mul(a12, a12)
  +a13 = a13
  a14 = U32.mul(a13, a13)
  +a14 = a14
  a15 = U32.mul(a14, a14)
  +a15 = a15
  a16 = U32.mul(a15, a15)
  +a16 = a16
  a17 = U32.mul(a16, a16)
  a17
def main() -> U32:
  kernel!(2)
#|0
