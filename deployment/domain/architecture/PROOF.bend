import Base
import ../../general/rose/ops.bend as RO
import ./type.bend as A
import ./ops.bend as O
import ./environment/type.bend as En
import ./LAWS.bend as Laws

def Laws.first_key_is_system(a):
  match a:
    case A.Architecture{k, n, d, s, cs, ns, env}:
      match env:
        case En.Environment{ps, xs, ks, inv, ag}:
          {==}
