import Base
import ./type.bend as Rl

# ---- the hub's rules: a name is 12 to 64 characters of a-z, 0-9 and -; a version is four numbers ----
def digits_only(cs: List<&2, Char>) -> Bool:
  match cs:
    case []:
      True{}
    case c <> rest:
      Char.is_digit(c) && digits_only(rest)

def all_numbers(xs: List<&2, String>) -> Bool:
  match xs:
    case []:
      True{}
    case +x <> rest:
      Bool.not(String.is_empty(x)) && digits_only(String.to_list(x)) && all_numbers(rest)

def name_chars(cs: List<&2, Char>) -> Bool:
  match cs:
    case []:
      True{}
    case +c <> rest:
      (Char.is_lower(c) || Char.is_digit(c) || Char.is_eq(c, '-')) && name_chars(rest)

def package_ok(r: Rl.Release) -> Bool:
  match r:
    case Rl.Package{+n, +v, _, _}:
      Nat.is_ge(String.length(n), 12n) && Nat.is_le(String.length(n), 64n) && name_chars(String.to_list(n)) &&
      Nat.is_eq(List.length(&2, String, String.split(v, '.')), 4n) && all_numbers(String.split(v, '.'))
    case _:
      True{}

# Every package the system releases follows the hub's rules.
def packages_ok(rs: List<&2, Rl.Release>) -> Bool:
  match rs:
    case []:
      True{}
    case r <> rest:
      package_ok(r) && packages_ok(rest)

def is_open(s: Rl.Source) -> Bool:
  match s:
    case Rl.OpenSource{_}:
      True{}
    case Rl.Proprietary{}:
      False{}

# Every repository the system releases its code from is open source.
def open_source(rs: List<&2, Rl.Release>) -> Bool:
  match rs:
    case []:
      True{}
    case r <> rest:
      match r:
        case Rl.Code{Rl.GitHub{_, _, s}}:
          is_open(s) && open_source(rest)
        case _:
          open_source(rest)

# Every component any package or plugin ships.
def shipped_components(rs: List<&2, Rl.Release>) -> List<&2, String>:
  match rs:
    case []:
      []
    case r <> rest:
      match r:
        case Rl.Package{_, _, _, cs}:
          List.append(&2, String, cs, shipped_components(rest))
        case Rl.Plugin{_, _, _, cs, _}:
          List.append(&2, String, cs, shipped_components(rest))
        case _:
          shipped_components(rest)

# Every package's entry file.
def entries(rs: List<&2, Rl.Release>) -> List<&2, String>:
  match rs:
    case []:
      []
    case r <> rest:
      match r:
        case Rl.Package{_, _, e, _}:
          e <> entries(rest)
        case _:
          entries(rest)

# Every plugin's entry file.
def plugin_entries(rs: List<&2, Rl.Release>) -> List<&2, String>:
  match rs:
    case []:
      []
    case r <> rest:
      match r:
        case Rl.Plugin{_, _, e, _, _}:
          e <> plugin_entries(rest)
        case _:
          plugin_entries(rest)

# ---- the repository: Bend only, and no dead code ----
# Bend, or a foreign effect in C or JavaScript (Bend's two lanes).
def is_source(+f: String) -> Bool:
  String.ends_with(f, ".bend") || String.ends_with(f, ".c") || String.ends_with(f, ".js")

def base_name(f: String) -> String:
  Maybe.default(&2, String, List.head(&2, String, List.reverse(&2, String, String.split(f, '/'))), "")

# Every source file is reachable from an entry: a package's, or the system's own.
def no_dead_code(fs: List<&2, String>, +reached: List<&2, String>) -> Bool:
  match fs:
    case []:
      True{}
    case +f <> rest:
      (Bool.not(is_source(f)) || List.contains(~String, ~String.eq, reached, f)) && no_dead_code(rest, reached)

# The first source file nothing reaches, "" when there is none.
def dead(fs: List<&2, String>, +reached: List<&2, String>) -> String:
  match fs:
    case []:
      ""
    case +f <> rest:
      Bool.pick(String, is_source(f) && Bool.not(List.contains(~String, ~String.eq, reached, f)), f, dead(rest, reached))

# The first file that is not Bend, "" when there is none.
# ---- the hub's path rule: every segment is [A-Za-z_][A-Za-z0-9_]* (the file name also ends in .bend, .c or
# .js, or is a LICENSE), under 256 characters ----
def name_char(+c: Char, first: Bool) -> Bool:
  Char.is_lower(c) || Char.is_upper(c) || Char.is_eq(c, '_') || (Bool.not(first) && Char.is_digit(c))

def name_chars_ok(cs: List<&2, Char>, first: Bool) -> Bool:
  match cs:
    case []:
      Bool.not(first)
    case +c <> rest:
      name_char(c, first) && name_chars_ok(rest, False{})

def stem(+f: String) -> String:
  Bool.pick(String, String.ends_with(f, ".bend"), String.take(f, Nat.sub(String.length(f), 5n)),
    Bool.pick(String, String.ends_with(f, ".js"), String.take(f, Nat.sub(String.length(f), 3n)),
      Bool.pick(String, String.ends_with(f, ".c"), String.take(f, Nat.sub(String.length(f), 2n)), f)))

def segments_ok(ss: List<&2, String>) -> Bool:
  match ss:
    case []:
      True{}
    case +s <> rest:
      match rest:
        case []:
          String.eq(s, "LICENSE") || (is_source(s) && name_chars_ok(String.to_list(stem(s)), True{}))
        case _ <> _:
          name_chars_ok(String.to_list(s), True{}) && segments_ok(rest)

def hub_path_ok(+f: String) -> Bool:
  Nat.is_lt(String.length(f), 256n) && segments_ok(String.split(f, '/'))

# The first file the hub would refuse, "" when there is none.
def hub_refused(fs: List<&2, String>) -> String:
  match fs:
    case []:
      ""
    case +f <> rest:
      Bool.pick(String, hub_path_ok(f), hub_refused(rest), f)
