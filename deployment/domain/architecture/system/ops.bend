import Base
import ./type.bend as S
import ./release/type.bend as Rl
import ./release/ops.bend as RlO
import ../ops.bend as O

def releases(s: S.System) -> List<&2, Rl.Release>:
  match s:
    case S.System{_, _, _, _, _, rs}:
      rs

# Everything the system is made of ships in a declared package or plugin: what is not published cannot
# be used.
def components_published(+s: S.System) -> Bool:
  match s:
    case S.System{_, _, _, cs, _, rs}:
      O.all_listed(O.all_component_keys(cs), RlO.shipped_components(rs))
