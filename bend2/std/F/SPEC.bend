# N / F specification
# Ownership: types and laws are authored and signed by the user; agents fill
# bodies only. This transcribes the user-approved specification. A separate
# cryptographic signature has not been supplied; this file does not forge one.
# Proofs are defs, never unfilled `law` axioms. The deferred effect symbol
# is an explicit type parameter, so this specification adds no effect axiom.

import Base

def Command() -> Type:
  Enum(["Move", "Line", "Curve", "Arc", "Close"])

def Path() -> Type:
  List<Command()>

def Axis() -> Type:
  Enum(["Horizontal", "Vertical", "Depth"])

def UI() -> Type:
  Tree(Axis(), Path())

# Action is an opaque effect type, supplied in the effects pass. Unchanged
# denotes `after == before` for that action. Both are parameters until their
# semantics are defined; no inhabitant or purity proof is assumed here.
def Query(Action: Type, -Unchanged: @-action: Action -> Type) -> Type:
  Exists(Action, action => Unchanged(action))

def Mutation(Action: Type) -> Type:
  Action

def Store(Action: Type, -Unchanged: @-action: Action -> Type) -> Type:
  Pair(Record(Query(Action, Unchanged)), Record(Mutation(Action)))

def State(Action: Type, -Unchanged: @-action: Action -> Type) -> Type:
  Record(Store(Action, Unchanged))

def Component(Action: Type, -Unchanged: @-action: Action -> Type) -> Type:
  Injective(Pair(UI(), State(Action, Unchanged)), UI())

# To prove with defs, not axioms:
# Injective: for any a and b, component(a) == component(b) implies a == b.
# Locality: changing one input tree position changes only its matching output
# position. Position correspondence and the effects observation are still to
# be defined; neither statement is claimed proven by this specification.
