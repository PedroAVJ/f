import Base
import ../../../../../general/markup/type.bend as M
import ../../../../../general/markup/ops.bend as MO
import ../nix_darwin/type.bend as ND
import ../../plan/type.bend as P
import ./type.bend as L

# A launch agent's property list, written as XML through markup.

def key(+k: String) -> M.Node:
  M.Element{"key", [], [M.Text{k}]}

def str(+s: String) -> M.Node:
  M.Element{"string", [], [M.Text{s}]}

def strs(xs: List<&2, String>) -> List<&2, M.Node>:
  match xs:
    case []:
      []
    case x <> rest:
      str(x) <> strs(rest)

def vars(vs: List<&2, L.Variable>) -> List<&2, M.Node>:
  match vs:
    case []:
      []
    case L.Variable{k, v} <> rest:
      key(k) <> str(v) <> vars(rest)

def path(+home: String, +label: String) -> String:
  home ++ "/Library/LaunchAgents/" ++ label ++ ".plist"

# Run from dir (the repository), so an agent's arguments may name the repository's files.
def plist(+home: String, dir: String, a: L.Agent) -> String:
  match a:
    case L.Agent{_, label, command, args, env, +log, _}:
      "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" ++
      "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n" ++
      MO.print([M.Element{"plist", [M.Attribute{"version", "1.0"}], [M.Element{"dict", [], [
        key("Label"), str(label),
        key("ProgramArguments"), M.Element{"array", [], str(command) <> strs(args)},
        key("EnvironmentVariables"), M.Element{"dict", [], vars(env)},
        key("WorkingDirectory"), str(dir),
        key("RunAtLoad"), M.Raw{"<true/>"},
        key("KeepAlive"), M.Raw{"<true/>"},
        key("StandardOutPath"), str(home ++ "/Library/Logs/" ++ log ++ ".log"),
        key("StandardErrorPath"), str(home ++ "/Library/Logs/" ++ log ++ ".log")]}]}]) ++ "\n"

def label_of(a: L.Agent) -> String:
  match a:
    case L.Agent{_, label, _, _, _, _, _}:
      label

def programs(ld: L.Launchd) -> List<&2, L.Program>:
  match ld:
    case L.Launchd{xs, _, _}:
      xs

def agents(ld: L.Launchd) -> List<&2, L.Agent>:
  match ld:
    case L.Launchd{_, xs, _}:
      xs

def serves(ld: L.Launchd) -> List<&2, ND.Serve>:
  match ld:
    case L.Launchd{_, _, xs}:
      xs

def port_of(a: L.Agent) -> U32:
  match a:
    case L.Agent{_, _, _, _, _, _, p}:
      p

def ports(xs: List<&2, L.Agent>) -> List<&2, U32>:
  match xs:
    case []:
      []
    case a <> rest:
      port_of(a) <> ports(rest)

# ---- the plans for a launchd node, from what was seen on it: building each program into dist/, and
# deploying what is there: each agent (re)loaded when its plist changed or it is not loaded, each serve on
# Tailscale. A deploy never builds: it stops at a program not built from the current inputs ----

def at(+dir: String, +p: String) -> String:
  Bool.pick(String, String.starts_with(p, "/"), p, dir ++ "/" ++ p)

def build_step(p: L.Program, b: P.Built) -> P.Step:
  match p:
    case L.Program{+path, build}:
      match build:
        case L.Installed{}:
          P.Current{"program " ++ path}
        case L.Page{+ui}:
          match b:
            case P.Fresh{}:
              P.Current{"build " ++ ui ++ " -> " ++ path}
            case _:
              P.BuildPage{ui, path}
        case L.Next{f}:
          P.Blocked{"build " ++ f, "Next.js builds are not run from here yet"}
        case L.Node{f}:
          P.Blocked{"build " ++ f, "Node builds are not run from here yet"}

# What a deploy needs of a program: built, from the current inputs.
def shipped_step(p: L.Program, b: P.Built) -> List<&2, P.Step>:
  match p:
    case L.Program{+path, build}:
      match build:
        case L.Page{_}:
          match b:
            case P.Fresh{}:
              []
            case P.Stale{}:
              [P.Blocked{"deploy " ++ path, "built from other sources; build first (bend system build)"}]
            case P.Missing{}:
              [P.Blocked{"deploy " ++ path, "not built; build first (bend system build)"}]
        case _:
          []

def build_steps_of(ps: List<&2, L.Program>, bs: List<&2, P.Built>) -> List<&2, P.Step>:
  match ps:
    case []:
      []
    case p <> prest:
      match bs:
        case []:
          [P.Blocked{"program observation", "missing build state for a declared program"}]
        case b <> brest:
          build_step(p, b) <> build_steps_of(prest, brest)

def shipped_steps(ps: List<&2, L.Program>, bs: List<&2, P.Built>) -> List<&2, P.Step>:
  match ps:
    case []:
      []
    case p <> prest:
      match bs:
        case []:
          [P.Blocked{"program observation", "missing build state for a declared program"}]
        case b <> brest:
          List.append(&2, P.Step, shipped_step(p, b), shipped_steps(prest, brest))

def agent_step(r: P.Running, +a: L.Agent, +home: String, +domain: String, +dir: String) -> P.Step:
  match r:
    case P.Running{now, +loaded, +listener}:
      +label = label_of(a)
      +want = plist(home, dir, a)
      Bool.pick(P.Step, Bool.not(loaded) && Bool.not(String.is_empty(listener)),
        P.Blocked{"port " ++ U32.show(port_of(a)), "already in use by " ++ listener},
        Bool.pick(P.Step, loaded && String.eq(now, want),
          P.Current{"launchd " ++ label}, P.Launch{label, path(home, label), want, domain}))

def agent_steps(xs: List<&2, L.Agent>, rs: List<&2, P.Running>, +home: String, +domain: String, +dir: String) -> List<&2, P.Step>:
  match xs:
    case []:
      []
    case a <> arest:
      match rs:
        case []:
          [P.Blocked{"agent observation", "missing launchd state for a declared agent"}]
        case r <> rrest:
          agent_step(r, a, home, domain, dir) <> agent_steps(arest, rrest, home, domain, dir)

# The line after the first line holding needle: what `tailscale serve status` serves under a port's heading.
def under(ls: List<&2, String>, +needle: String) -> Maybe<&2, String>:
  match ls:
    case []:
      None{}
    case +l <> +rest:
      Bool.pick(Maybe<&2, String>, String.contains(l, needle),
        Some{Maybe.default(&2, String, List.head(&2, String, rest), "")}, under(rest, needle))

def target(s: ND.Serve) -> String:
  match s:
    case ND.Serve{_, _, +port, +p}:
      "http://127.0.0.1:" ++ U32.show(port) ++ Bool.pick(String, String.eq(p, "/"), "", p)

def https_of(s: ND.Serve) -> U32:
  match s:
    case ND.Serve{_, h, _, _}:
      h

def serve_found(m: Maybe<&2, String>, +s: ND.Serve, +tailscale: String) -> P.Step:
  match m:
    case None{}:
      P.ServePort{https_of(s), target(s), tailscale}
    case Some{+l}:
      Bool.pick(P.Step, String.ends_with(String.trim(l), " proxy " ++ target(s)),
        P.Current{"tailscale :" ++ U32.show(https_of(s)) ++ " -> " ++ target(s)},
        P.Blocked{"tailscale :" ++ U32.show(https_of(s)), "already serves " ++ String.trim(l)})

def serve_steps(ss: List<&2, ND.Serve>, +served: List<&2, String>, +tailscale: String) -> List<&2, P.Step>:
  match ss:
    case []:
      []
    case +s <> rest:
      serve_found(under(served, ":" ++ U32.show(https_of(s)) ++ " ("), s, tailscale) <> serve_steps(rest, served, tailscale)

# The address a serve answers at on the tailnet.
def serve_address(+name: String, s: ND.Serve) -> String:
  +h = https_of(s)
  "https://" ++ name ++ Bool.pick(String, U32.is_eq(h, 443), "", ":" ++ U32.show(h))

def answers(ss: List<&2, ND.Serve>, +name: String, +address: String) -> Bool:
  match ss:
    case []:
      False{}
    case s <> rest:
      String.eq(serve_address(name, s), address) || answers(rest, name, address)

def address_step(+ss: List<&2, ND.Serve>, +name: String, +address: String) -> List<&2, P.Step>:
  Bool.pick(List<&2, P.Step>, String.is_empty(name), [P.Blocked{"tailscale", "not running (no tailnet name)"}],
    Bool.pick(List<&2, P.Step>, answers(ss, name, address) || List.is_empty(&2, ND.Serve, ss), [],
      [P.Blocked{"address", address ++ " is not one of this node's serves on " ++ name}]))

# Building: each program into dist/.
def build_steps(ld: L.Launchd, s: P.Seen) -> List<&2, P.Step>:
  match ld s:
    case L.Launchd{ps, _, _} P.Seen{_, _, _, bs, _, _, _, _}:
      build_steps_of(ps, bs)

# Shipping: each program built from the current inputs, which a deploy needs and never makes.
def ship_steps(ld: L.Launchd, s: P.Seen) -> List<&2, P.Step>:
  match ld s:
    case L.Launchd{ps, _, _} P.Seen{_, _, _, bs, _, _, _, _}:
      shipped_steps(ps, bs)

# Serving: the address, each agent and each serve.
def serve_all(ld: L.Launchd, s: P.Seen, +address: String) -> List<&2, P.Step>:
  match ld s:
    case L.Launchd{_, xs, +ss} P.Seen{+home, +domain, +dir, _, rs, +ts, +name, +served}:
      List.append(&2, P.Step, address_step(ss, name, address),
        List.append(&2, P.Step, agent_steps(xs, rs, home, domain, dir), serve_steps(ss, served, ts)))
