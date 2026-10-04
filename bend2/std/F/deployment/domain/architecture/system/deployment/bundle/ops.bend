import Base
import ../../plan/type.bend as P
import ./type.bend as Bu

# ---- the plans for a Mac app, from what was seen of it: building it into dist/, and deploying what is
# there: installed in ~/Applications and opened when the copy there is not this build. A deploy never
# builds: it stops at an app not built from the current inputs, and never replaces another app ----

def ui(a: Bu.MacApp) -> String:
  match a:
    case Bu.MacApp{u, _, _}:
      u

def id(a: Bu.MacApp) -> String:
  match a:
    case Bu.MacApp{_, i, _}:
      i

def dir(a: Bu.MacApp) -> String:
  match a:
    case Bu.MacApp{_, _, d}:
      d

def built(o: P.Bundled) -> P.Built:
  match o:
    case P.Bundled{b, _, _, _, _}:
      b

def fresh(b: P.Built) -> Bool:
  match b:
    case P.Fresh{}:
      True{}
    case _:
      False{}

# Building: the app into its folder, unless it holds what the current inputs build.
def build_steps(+a: Bu.MacApp, o: P.Bundled) -> List<&2, P.Step>:
  Bool.pick(List<&2, P.Step>, fresh(built(o)), [P.Current{"build " ++ ui(a) ++ " -> " ++ dir(a)}],
    [P.BuildApp{ui(a), dir(a), id(a)}])

def shipped(+a: Bu.MacApp, b: P.Built) -> List<&2, P.Step>:
  match b:
    case P.Fresh{}:
      []
    case P.Stale{}:
      [P.Blocked{"deploy " ++ dir(a), "built from other sources; build first (bend system build)"}]
    case P.Missing{}:
      [P.Blocked{"deploy " ++ dir(a), "not built; build first (bend system build)"}]

# Shipping: the app built from the current inputs, which a deploy needs and never makes.
def ship_steps(+a: Bu.MacApp, o: P.Bundled) -> List<&2, P.Step>:
  shipped(a, built(o))

# Installing: blocked by another app of the same name, current when ~/Applications holds this build,
# else the build installed and opened.
def install_steps(+a: Bu.MacApp, o: P.Bundled) -> List<&2, P.Step>:
  match o:
    case P.Bundled{b, +name, +version, +installed, +other}:
      +app = name ++ ".app"
      Bool.pick(List<&2, P.Step>, Bool.not(String.is_empty(other)),
        [P.Blocked{"install " ++ app, other ++ " is another app by that name; not replacing it"}],
        Bool.pick(List<&2, P.Step>, fresh(b) && String.eq(installed, version) && Bool.not(String.is_empty(version)),
          [P.Current{"app ~/Applications/" ++ app ++ " " ++ version}],
          [P.Install{name, id(a), Bool.pick(String, String.is_empty(name), "", dir(a) ++ "/" ++ app), version}]))
