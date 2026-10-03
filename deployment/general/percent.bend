import Base

type PctDecoded is Data:
  PctDecoded{value: U32, rest: String}

# Local RFC3986 percent decoding to Unicode scalars. No URL/Hub or foreign dependency.
# PctInvalid escapes, truncated UTF-8, overlong sequences and surrogate scalars fail closed.
def hex(+c: U32) -> Maybe<&2, U32>:
  Bool.pick(Maybe<&2, U32>, U32.is_ge(c, 48) && U32.is_le(c, 57), Some{U32.sub(c, 48)},
    Bool.pick(Maybe<&2, U32>, U32.is_ge(c, 65) && U32.is_le(c, 70), Some{U32.sub(c, 55)},
      Bool.pick(Maybe<&2, U32>, U32.is_ge(c, 97) && U32.is_le(c, 102), Some{U32.sub(c, 87)}, None{})))

def byte_hex(x: Maybe<&2, U32>, y: Maybe<&2, U32>, rest: String) -> Maybe<&2, PctDecoded>:
  match x y:
    case Some{a} Some{b}:
      Some{PctDecoded{U32.add(U32.mul(a, 16), b), rest}}
    case _ _:
      None{}

def byte(s: String) -> Maybe<&2, PctDecoded>:
  match s:
    case SCon{Chr{37}, SCon{Chr{a}, SCon{Chr{b}, rest}}}:
      byte_hex(hex(a), hex(b), rest)
    case _:
      None{}

def continuation(n: Nat, +code: U32, +minimum: U32, m: Maybe<&2, PctDecoded>) -> Maybe<&2, PctDecoded>:
  match n:
    case 0n:
      match m:
        case Some{PctDecoded{_, rest}}:
          Bool.pick(Maybe<&2, PctDecoded>, U32.is_ge(code, minimum) && U32.is_le(code, 1114111) && Bool.not(U32.is_ge(code, 55296) && U32.is_le(code, 57343)), Some{PctDecoded{code, rest}}, None{})
        case None{}:
          None{}
    case 1n+ +k:
      match m:
        case Some{PctDecoded{+b, +rest}}:
          Bool.pick(Maybe<&2, PctDecoded>, U32.is_ge(b, 128) && U32.is_le(b, 191), continuation(k, U32.add(U32.mul(code, 64), U32.sub(b, 128)), minimum, Bool.pick(Maybe<&2, PctDecoded>, Nat.is_eq(k, 0n), Some{PctDecoded{0, rest}}, byte(rest))), None{})
        case None{}:
          None{}

def scalar(+b: U32, +s: String) -> Maybe<&2, PctDecoded>:
  Bool.pick(Maybe<&2, PctDecoded>, U32.is_le(b, 127), Some{PctDecoded{b, s}},
    Bool.pick(Maybe<&2, PctDecoded>, U32.is_ge(b, 194) && U32.is_le(b, 223), continuation(1n, U32.sub(b, 192), 128, byte(s)),
      Bool.pick(Maybe<&2, PctDecoded>, U32.is_ge(b, 224) && U32.is_le(b, 239), continuation(2n, U32.sub(b, 224), 2048, byte(s)),
        Bool.pick(Maybe<&2, PctDecoded>, U32.is_ge(b, 240) && U32.is_le(b, 244), continuation(3n, U32.sub(b, 240), 65536, byte(s)), None{}))))

type PctStep is Data:
  PctDone{}
  PctInvalid{}
  PctNext{char: Char, rest: String}

def step_scalar(m: Maybe<&2, PctDecoded>) -> PctStep:
  match m:
    case Some{PctDecoded{c, tail}}:
      PctNext{Chr{c}, tail}
    case None{}:
      PctInvalid{}

def escaped(m: Maybe<&2, PctDecoded>) -> PctStep:
  match m:
    case Some{PctDecoded{b, after}}:
      step_scalar(scalar(b, after))
    case None{}:
      PctInvalid{}

def step(s: String) -> PctStep:
  match s:
    case SNil{}:
      PctDone{}
    case SCon{Chr{37}, rest}:
      escaped(byte(SCon{Chr{37}, rest}))
    case SCon{c, rest}:
      PctNext{c, rest}

def go(fuel: Nat, current: PctStep, acc: String) -> Maybe<&2, String>:
  match fuel:
    case 0n:
      None{}
    case 1n+k:
      match current:
        case PctDone{}:
          Some{String.reverse(acc)}
        case PctInvalid{}:
          None{}
        case PctNext{c, tail}:
          go(k, step(tail), SCon{c, acc})

def decode(+s: String) -> Maybe<&2, String>:
  go(1n+String.length(s), step(s), "")
