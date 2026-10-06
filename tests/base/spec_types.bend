import Base
import ../../bend2/std/F/SPEC.bend as S

def identity(value: Nat) -> Nat:
  value

def identity_proof(-a: Nat, -b: Nat,
  same: {identity(a) == identity(b) : Nat}) -> {a == b : Nat}:
  same

def injective_identity() -> Injective(Nat, Nat):
  Tuple{identity, identity_proof}

def zero(value: Nat) -> Nat:
  0n

def zero_bound(-value: Nat) -> {Nat.is_le(identity(zero(value)), 0n) == True{} : Bool}:
  {==}

def bounded_zero() -> Bounded(Nat, Nat, Nat, identity, Nat.is_le, 0n):
  Tuple{zero, zero_bound}

def line() -> S.Command():
  Inr{Inl{Unit{}}}

def path() -> S.Path():
  [line()]

def vertical() -> S.Axis():
  Inr{Inl{Unit{}}}

def tree() -> S.UI():
  Fork{vertical(), [Tip{path()}]}

def fields() -> Record(Nat):
  MLeaf{"count", 0n}

def main() -> U32:
  1

#| 1
