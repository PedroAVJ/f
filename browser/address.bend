import Base
import ../deployment/general/percent.bend as Percent

# A browser address (a path) as segments and back, for the Page an app derives its addresses from.

# The path, up to a "?" or "#".
def path(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{Chr{+c}, t}:
      Bool.pick(String, U32.is_eq(c, 63) || U32.is_eq(c, 35), "", SCon{Chr{c}, path(t)})

def decoded(+s: String) -> String:
  Maybe.default(&2, String, Percent.decode(s), s)

def kept(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case []:
      []
    case +x <> rest:
      +r = kept(rest)
      Bool.pick(List<&2, String>, String.is_empty(x), r, decoded(x) <> r)

# "/conversation/42?x" is ["conversation", "42"]: split on "/", empty parts dropped, each percent-decoded.
def segments(s: String) -> List<&2, String>:
  kept(String.split(path(s), '/'))

# The n-th segment ("" past the end), and a segment as a number (0 unless it is one).
def segment(+xs: List<&2, String>, n: Nat) -> String:
  Maybe.default(&2, String, List.get(&2, String, xs, n), "")

def number(+s: String) -> U32:
  +n = Maybe.default(&2, U32, U32.read(s), 0)
  Bool.pick(U32, String.eq(U32.show(n), s), n, 0)

def escape_char(+c: U32) -> String:
  Bool.pick(String, U32.is_eq(c, 37), "%25", Bool.pick(String, U32.is_eq(c, 47), "%2F", Bool.pick(String, U32.is_eq(c, 63), "%3F",
    Bool.pick(String, U32.is_eq(c, 35), "%23", Bool.pick(String, U32.is_eq(c, 32), "%20", SCon{Chr{c}, SNil{}})))))

# A segment as it goes in an address: "%", "/", "?", "#" and spaces escaped.
def escape(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{Chr{c}, t}:
      escape_char(c) ++ escape(t)
