import Base
import ./type.bend as Pl

# Offline preparation retains version/name checks only; manifest serialization is deferred.
def version_show(v: Pl.Version) -> String:
  match v:
    case Pl.Version{major, minor, patch}:
      Nat.show(major) ++ "." ++ Nat.show(minor) ++ "." ++ Nat.show(patch)

# ---- the standard's rule for a name ----
def name_char(+c: Char) -> Bool:
  Char.is_lower(c) || Char.is_digit(c) || Char.is_eq(c, '.') || Char.is_eq(c, '-')

def edge_char(+c: Char) -> Bool:
  Char.is_lower(c) || Char.is_digit(c)

def repeats(cs: List<&2, Char>, +prev: Char) -> Bool:
  match cs:
    case []:
      False{}
    case +c <> rest:
      ((Char.is_eq(c, '-') || Char.is_eq(c, '.')) && Char.is_eq(c, prev)) || repeats(rest, c)

def all_name_chars(cs: List<&2, Char>) -> Bool:
  match cs:
    case []:
      True{}
    case +c <> rest:
      name_char(c) && all_name_chars(rest)

def first_ok(cs: List<&2, Char>) -> Bool:
  match cs:
    case []:
      False{}
    case +c <> _:
      edge_char(c)

# 1 to 64 of a-z, 0-9, . and -, starting and ending with a letter or digit, with no -- or ..
def name_ok(+n: String) -> Bool:
  Nat.is_ge(String.length(n), 1n) && Nat.is_le(String.length(n), 64n) && all_name_chars(String.to_list(n)) &&
  first_ok(String.to_list(n)) && first_ok(String.to_list(String.reverse(n))) && Bool.not(repeats(String.to_list(n), ' '))
