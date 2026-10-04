import Base
import ./type.bend as S
import ./container/type.bend as Ct
import ./release/type.bend as Rl
import ./release/ops.bend as RlO
import ../ops.bend as O

def releases(s: S.System) -> List<&2, Rl.Release>:
  match s:
    case S.System{_, _, _, rs, _}:
      rs

# Everything the system is made of (its containers) ships in a declared package or plugin: what is not
# published cannot be used.
def components_published(cs: List<&2, Ct.Container>, s: S.System) -> Bool:
  O.all_listed(O.all_component_keys(cs), RlO.shipped_components(releases(s)))
