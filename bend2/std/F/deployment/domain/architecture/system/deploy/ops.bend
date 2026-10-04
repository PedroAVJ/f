import Base
import ../type.bend as S
import ../deployment/type.bend as D
import ../deployment/ops.bend as DO
import ../deployment/launchd/type.bend as L
import ../deployment/launchd/ops.bend as LO
import ../plan/type.bend as P
import ../plan/ops.bend as PO
import ../release/type.bend as Rl

# A system deployed from the repository it lives in (the current directory): observe the world, lower each
# deployment to its topology, plan from the declaration and what was observed, and run the plan. `check` stops
# at the plan; `release`, `deploy` and `ship` run its steps of their kinds.
# Each command is /bin/sh running a script with positional arguments, so no value is spliced into one.

type Ran is Data:
  Ran{code: U32, out: String, err: String}

def ran(r: Result<&1, &1, U32 & String, U32 & (String & String)>) -> Ran:
  match r:
    case Done{(code, (out, err))}:
      Ran{code, out, err}
    case Fail{(+code, message)}:
      Ran{Bool.pick(U32, U32.is_eq(code, 0), 1, code), "", "could not run it: " ++ message}

def strings(xs: List<&2, String>) -> List<String>:
  match xs:
    case []:
      []
    case x <> rest:
      x <> strings(rest)

def sh(script: String, args: List<&2, String>, input: String) -> IO(Ran):
  IO.bind(Result<&1, &1, U32 & String, U32 & (String & String)>, Ran,
    Process.run("/bin/sh", "-c" <> script <> "sh" <> strings(args), input, 16777216, 900000),
    r => IO.pure(Ran, ran(r)))

def ok(r: Ran) -> Bool:
  match r:
    case Ran{code, _, _}:
      U32.is_eq(code, 0)

def out(r: Ran) -> String:
  match r:
    case Ran{_, o, _}:
      o

def lines(r: Ran) -> List<&2, String>:
  String.lines(out(r))

def line(+ls: List<&2, String>, n: Nat) -> String:
  Maybe.default(&2, String, List.get(&2, String, ls, n), "")

def filled(ls: List<&2, String>) -> List<&2, String>:
  match ls:
    case []:
      []
    case +l <> rest:
      +r = filled(rest)
      Bool.pick(List<&2, String>, String.is_empty(l), r, l <> r)

# ---- observe the repository: its Bend files, then, for each declared GitHub repository ($1, owner/name):
# origin (as github.com/<owner>/<name> when it is on GitHub), GitHub's visibility (gh's, else the public
# API's), clean, pushed ----

def remote_script() -> String:
  "o=$(git remote get-url origin 2>/dev/null); p=${o#*github.com[:/]}; p=${p%.git}\n" ++
  "case \"$o\" in *github.com[:/]*) o=\"github.com/$p\";; esac\n" ++
  "v=$(gh api \"repos/$1\" --jq .visibility 2>/dev/null || curl -fsS --max-time 15 \"https://api.github.com/repos/$1\" 2>/dev/null | sed -n 's/.*\"visibility\": *\"\\([a-z]*\\)\".*/\\1/p' | head -1)\n" ++
  "c=$(git status --porcelain | head -1); git fetch --quiet origin 2>/dev/null\n" ++
  "a=$(git rev-list --count '@{u}..HEAD' 2>/dev/null || echo none)\n" ++
  "printf '%s\\n%s\\n%s\\n%s\\n' \"$o\" \"$v\" \"$c\" \"$a\""

def remote(+ls: List<&2, String>) -> P.Remote:
  P.Remote{line(ls, 0n), line(ls, 1n), String.is_empty(line(ls, 2n)), String.eq(line(ls, 3n), "0")}

def remotes(rs: List<&2, Rl.Release>) -> IO(List<&2, P.Remote>):
  match rs:
    case []:
      IO.pure(List<&2, P.Remote>, [])
    case r <> rest:
      match r:
        case Rl.Code{Rl.GitHub{owner, name, _}}:
          do IO<List<&2, P.Remote>>:
            rm : Ran <- sh(remote_script(), [owner ++ "/" ++ name], "")
            ms : List<&2, P.Remote> <- remotes(rest)
            return remote(lines(rm)) <> ms
        case _:
          remotes(rest)

def observe_release(rs: List<&2, Rl.Release>) -> IO(P.Observed):
  do IO<P.Observed>:
    fs : Ran <- sh("git ls-files '*.bend'", [], "")
    ms : List<&2, P.Remote> <- remotes(rs)
    +files : List<&2, String> = filled(lines(fs))
    return P.Observed{files, files, [], ms, []}

# ---- observe this Mac: who and where, a free local port, Tailscale; then each program built afresh and
# each agent of a lowered launchd node ----

# Lines: home, launchd domain, the repository's folder, Tailscale's command, the tailnet name, the owner's
# short name, the repository's folder name, the first port of 4600, 4610, .. 4990 nothing listens on or is
# served from (0 when none is), then `tailscale serve status`.
def here_script() -> String:
  "t=$(command -v tailscale || echo /Applications/Tailscale.app/Contents/MacOS/Tailscale)\n" ++
  "n=$(\"$t\" status --json --peers=false 2>/dev/null | grep -m1 '\"DNSName\"' | sed 's/.*\"DNSName\": *\"\\(.*\\)\\.\".*/\\1/')\n" ++
  "u=$(id -F 2>/dev/null | awk '{print tolower($1)}' | tr -cd 'a-z0-9-'); [ -n \"$u\" ] || u=$(id -un)\n" ++
  "s=$(\"$t\" serve status 2>&1); l=$(lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | awk 'NR>1{n=split($9,a,\":\"); print a[n]}')\n" ++
  "p=4600; while [ $p -lt 5000 ]; do printf '%s\\n' \"$l\" | grep -qx \"$p\" || printf '%s\\n' \"$s\" | grep -Eq \"127\\.0\\.0\\.1:$p([^0-9]|\\$)\" || break; p=$((p+10)); done; [ $p -lt 5000 ] || p=0\n" ++
  "printf '%s\\ngui/%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n%s\\n' \"$HOME\" \"$(id -u)\" \"$(pwd -P)\" \"$t\" \"$n\" \"$u\" \"$(basename \"$(pwd -P)\")\" \"$p\" \"$s\""

# What lowering a deployment reads from the Mac's lines.
def here(+ls: List<&2, String>) -> D.Here:
  D.Here{line(ls, 5n), line(ls, 6n), line(ls, 4n), List.drop(&2, String, ls, 8n), Maybe.default(&2, U32, U32.read(line(ls, 7n)), 0)}

# A Bend program is its entry's run, kept beside the installed file as <path>.next, next to whether it equals
# it. The fork runs from $BEND, else ../f/bend2/main.ts beside the repository; bun from PATH or Homebrew.
def build_script() -> String:
  "b=${BEND:-../f/bend2/main.ts}; u=$(command -v bun || echo /opt/homebrew/bin/bun); f=\"$2.next\"\n" ++
  "mkdir -p \"$(dirname \"$2\")\" || exit 1\n" ++
  "\"$u\" \"$b\" \"$1\" > \"$f\" 2> \"$f.err\" || { cat \"$f.err\" \"$f\" >&2; rm -f \"$f\" \"$f.err\"; exit 1; }; rm -f \"$f.err\"\n" ++
  "if cmp -s \"$f\" \"$2\"; then rm -f \"$f\"; printf '%s\\nsame\\n' \"$f\"; else printf '%s\\ndiffers\\n' \"$f\"; fi"

def built(r: Ran) -> P.Built:
  match r:
    case Ran{code, o, e}:
      +ls = String.lines(o)
      Bool.pick(P.Built, U32.is_eq(code, 0), P.Built{line(ls, 0n), String.eq(line(ls, 1n), "same"), ""},
        P.Built{"", False{}, "does not build: " ++ String.trim(e)})

def build_program(p: L.Program, +dir: String) -> IO(P.Built):
  match p:
    case L.Program{+path, b}:
      match b:
        case L.Bend{e}:
          IO.bind(Ran, P.Built, sh(build_script(), [e, LO.at(dir, path)], ""), r => IO.pure(P.Built, built(r)))
        case _:
          IO.pure(P.Built, P.Built{"", False{}, ""})

def builds(ps: List<&2, L.Program>, +dir: String) -> IO(List<&2, P.Built>):
  match ps:
    case []:
      IO.pure(List<&2, P.Built>, [])
    case p <> rest:
      do IO<List<&2, P.Built>>:
        b : P.Built <- build_program(p, dir)
        bs : List<&2, P.Built> <- builds(rest, dir)
        return b <> bs

def agent_script() -> String:
  "launchctl print \"$2/$1\" >/dev/null 2>&1 && echo loaded || echo unloaded\n" ++
  "printf '%s\\n' \"$(lsof -nP -iTCP:\"$3\" -sTCP:LISTEN 2>/dev/null | awk 'NR==2{print $1}')\""

def running(a: L.Agent, +home: String, +domain: String) -> IO(P.Running):
  match a:
    case L.Agent{_, +label, _, _, _, _, port}:
      do IO<P.Running>:
        st : Ran <- sh(agent_script(), [label, domain, U32.show(port)], "")
        pl : Ran <- sh("cat \"$1\" 2>/dev/null", [LO.path(home, label)], "")
        +ls : List<&2, String> = lines(st)
        return P.Running{out(pl), String.eq(line(ls, 0n), "loaded"), line(ls, 1n)}

def runnings(xs: List<&2, L.Agent>, +home: String, +domain: String) -> IO(List<&2, P.Running>):
  match xs:
    case []:
      IO.pure(List<&2, P.Running>, [])
    case a <> rest:
      do IO<List<&2, P.Running>>:
        r : P.Running <- running(a, home, domain)
        rs : List<&2, P.Running> <- runnings(rest, home, domain)
        return r <> rs

def observe_at(+ld: L.Launchd, +ls: List<&2, String>) -> IO(P.Seen):
  +home = line(ls, 0n)
  +domain = line(ls, 1n)
  +dir = line(ls, 2n)
  do IO<P.Seen>:
    bs : List<&2, P.Built> <- builds(LO.programs(ld), dir)
    rs : List<&2, P.Running> <- runnings(LO.agents(ld), home, domain)
    return P.Seen{home, domain, dir, bs, rs, line(ls, 3n), line(ls, 4n), List.drop(&2, String, ls, 8n)}

# ---- the plan: the release's steps, then each deployment's, lowered to its topology. Only launchd nodes
# (this Mac) deploy from here ----

# The steps, and the address of each deployment they reach.
type Planned is Data:
  Planned{steps: List<&2, P.Step>, addresses: List<&2, String>}

def node_plan(n: D.Node, +address: String, +ls: List<&2, String>) -> IO(List<&2, P.Step>):
  match n:
    case D.Node{+key, _, _, _, _, platform, _, _}:
      match platform:
        case D.Unmanaged{}:
          IO.pure(List<&2, P.Step>, [])
        case D.Launchd{+ld}:
          IO.bind(P.Seen, List<&2, P.Step>, observe_at(ld, ls), s => IO.pure(List<&2, P.Step>, LO.steps(ld, s, address)))
        case _:
          IO.pure(List<&2, P.Step>, [P.Blocked{"node " ++ key, "only launchd nodes deploy from here"}])

def node_plans(ns: List<&2, D.Node>, +address: String, +ls: List<&2, String>) -> IO(List<&2, P.Step>):
  match ns:
    case []:
      IO.pure(List<&2, P.Step>, [])
    case n <> rest:
      do IO<List<&2, P.Step>>:
        a : List<&2, P.Step> <- node_plan(n, address, ls)
        b : List<&2, P.Step> <- node_plans(rest, address, ls)
        return List.append(&2, P.Step, a, b)

def topology_plan(t: D.Topology, +ls: List<&2, String>) -> IO(Planned):
  match t:
    case D.Topology{+a, _, _, ns}:
      IO.bind(List<&2, P.Step>, Planned, node_plans(ns, a, ls), ss => IO.pure(Planned, Planned{ss, [a]}))

# What stops a Mac deployment before it is lowered: other than one app (one Tailscale port serves one app
# so far), or no free local port for it.
def unlowered(+d: D.Deployment, +h: D.Here) -> List<&2, P.Step>:
  Bool.pick(List<&2, P.Step>, Bool.not(Nat.is_eq(List.length(&2, D.Application, DO.apps(d)), 1n)),
    [P.Blocked{"mac :" ++ U32.show(DO.https(d)), "one app per Tailscale port so far"}],
    Bool.pick(List<&2, P.Step>, U32.is_eq(DO.port(d, h), 0),
      [P.Blocked{"mac :" ++ U32.show(DO.https(d)), "no free local port in 4600-4990"}], []))

def mac_plan(+d: D.Deployment, +ls: List<&2, String>) -> IO(Planned):
  +h = here(ls)
  +no = unlowered(d, h)
  Bool.pick(IO(Planned), List.is_empty(&2, P.Step, no), topology_plan(DO.lower(d, h), ls), IO.pure(Planned, Planned{no, []}))

def deployment_plan(+d: D.Deployment) -> IO(Planned):
  IO.bind(Ran, Planned, sh(here_script(), [], ""), r => mac_plan(d, lines(r)))

def joined(a: Planned, b: Planned) -> Planned:
  match a b:
    case Planned{x, p} Planned{y, q}:
      Planned{List.append(&2, P.Step, x, y), List.append(&2, String, p, q)}

def deployment_plans(ds: List<&2, D.Deployment>) -> IO(Planned):
  match ds:
    case []:
      IO.pure(Planned, Planned{[], []})
    case d <> rest:
      do IO<Planned>:
        x : Planned <- deployment_plan(d)
        y : Planned <- deployment_plans(rest)
        return joined(x, y)

def planned(s: S.System) -> IO(Planned):
  match s:
    case S.System{+rs, ds}:
      do IO<Planned>:
        o : P.Observed <- observe_release(rs)
        n : Planned <- deployment_plans(ds)
        return joined(Planned{PO.plan(rs, o), []}, n)

# ---- running a step: stop at the first that fails, with what it said ----

def done(r: Ran, +what: String) -> IO(Unit):
  match r:
    case Ran{+code, o, e}:
      Bool.pick(IO(Unit), U32.is_eq(code, 0), IO.print("done     " ++ what),
        IO.die(Unit, 1, "failed   " ++ what ++ " (exit " ++ U32.show(code) ++ "): " ++ String.trim(e ++ o)))

def launch_script() -> String:
  "mkdir -p \"$(dirname \"$2\")\" \"$HOME/Library/Logs\" && cat > \"$2\" || exit 1\n" ++
  "launchctl bootout \"$3/$1\" 2>/dev/null; i=0\n" ++
  "until e=$(launchctl bootstrap \"$3\" \"$2\" 2>&1); do i=$((i+1)); [ $i -ge 20 ] && { echo \"$e\" >&2; exit 1; }; sleep 0.5; done"

def run(+s: P.Step) -> IO(Unit):
  match s:
    case P.Push{_}:
      IO.bind(Ran, Unit, sh("git push 2>&1", [], ""), r => done(r, PO.show(s)))
    case P.Install{from, to}:
      IO.bind(Ran, Unit, sh("mv -f \"$1\" \"$2\"", [from, to], ""), r => done(r, PO.show(s)))
    case P.Launch{label, path, plist, domain}:
      IO.bind(Ran, Unit, sh(launch_script(), [label, path, domain], plist), r => done(r, PO.show(s)))
    case P.ServePort{https, target, ts}:
      IO.bind(Ran, Unit, sh("\"$1\" serve --bg --https=\"$2\" \"$3\" 2>&1", [ts, U32.show(https), target], ""), r => done(r, PO.show(s)))
    case P.Current{_}:
      IO.pure(Unit, Unit{})
    case P.Change{_, _, _}:
      IO.pure(Unit, Unit{})
    case _:
      IO.die(Unit, 1, "failed   " ++ PO.show(s) ++ ": not a step this deploy runs yet")

# What a step is for: 1 builds an artifact, 2 releases (push, publish), 3 deploys (launch, serve, rebuild); 0
# changes nothing.
def kind(s: P.Step) -> U32:
  match s:
    case P.Install{_, _}:
      1
    case P.BuildNext{_, _, _}:
      1
    case P.BuildNode{_, _, _}:
      1
    case P.Push{_}:
      2
    case P.Publish{_, _, _}:
      2
    case P.ReleasePlugin{_, _, _, _}:
      2
    case P.Launch{_, _, _, _}:
      3
    case P.ServePort{_, _, _}:
      3
    case P.Rebuild{_, _, _}:
      3
    case _:
      0

# Run the steps of one kind, in order.
def run_kind(+k: U32, +ss: List<&2, P.Step>) -> IO(Unit):
  match ss:
    case []:
      IO.pure(Unit, Unit{})
    case +s <> +rest:
      Bool.pick(IO(Unit), U32.is_eq(kind(s), k), IO.bind(Unit, Unit, run(s), u => run_kind(k, rest)), run_kind(k, rest))

# Run the steps of each kind, kind by kind.
def run_kinds(ks: List<&2, U32>, +ss: List<&2, P.Step>) -> IO(Unit):
  match ks:
    case []:
      IO.pure(Unit, Unit{})
    case k <> rest:
      IO.bind(Unit, Unit, run_kind(k, ss), u => run_kinds(rest, ss))

# The deployed address answers (Tailscale needs a moment for a new serve's certificate).
def live(+a: String) -> IO(Unit):
  IO.bind(Ran, Unit,
    sh("i=0; until curl -fsS -o /dev/null --max-time 10 \"$1\" 2>/dev/null; do i=$((i+1)); [ $i -ge 30 ] && exit 1; sleep 1; done", [a], ""),
    r => done(r, "live     " ++ a))

def lives(xs: List<&2, String>) -> IO(Unit):
  match xs:
    case []:
      IO.pure(Unit, Unit{})
    case a <> rest:
      IO.bind(Unit, Unit, live(a), u => lives(rest))

def shown(+ss: List<&2, P.Step>) -> IO(Bool):
  IO.bind(Unit, Bool, IO.write(PO.show_all(ss)), u => IO.pure(Bool, PO.any_blocked(ss)))

def ran_kinds(p: Planned, ks: List<&2, U32>, deploys: Bool) -> IO(Unit):
  match p:
    case Planned{+ss, xs}:
      IO.bind(Unit, Unit, run_kinds(ks, ss), u => Bool.pick(IO(Unit), deploys, lives(xs), IO.pure(Unit, Unit{})))

def steps(p: Planned) -> List<&2, P.Step>:
  match p:
    case Planned{ss, _}:
      ss

# Observe, print the plan, and stop (exit 1) if a step is blocked; else run the steps of the given kinds (1
# builds, 2 releases, 3 deploys), then, when it deploys, confirm each deployment's address answers.
def go(+s: S.System, ks: List<&2, U32>, deploys: Bool) -> IO(Unit):
  do IO<Unit>:
    +p : Planned <- planned(s)
    b : Bool <- shown(steps(p))
    Bool.pick(IO(Unit), b, IO.die(Unit, 1, "blocked: nothing done"), ran_kinds(p, ks, deploys))

# check: observe and print the plan; change nothing (exit 1 when a step is blocked).
def check(s: S.System) -> IO(Unit):
  do IO<Unit>:
    p : Planned <- planned(s)
    b : Bool <- shown(steps(p))
    Bool.pick(IO(Unit), b, IO.die(Unit, 1, "blocked"), IO.print("ready"))

# release: build, then push the code and publish the packages and plugins.
def release(+s: S.System) -> IO(Unit):
  go(s, [1, 2], False{})

# deploy: build, then launch and serve, and confirm the address answers.
def deploy(+s: S.System) -> IO(Unit):
  go(s, [1, 3], True{})

# ship: build, release, deploy.
def ship(+s: S.System) -> IO(Unit):
  go(s, [1, 2, 3], True{})

def verb(+v: String, +s: S.System) -> IO(Unit):
  Bool.pick(IO(Unit), String.eq(v, "check"), check(s),
    Bool.pick(IO(Unit), String.eq(v, "release"), release(s),
      Bool.pick(IO(Unit), String.eq(v, "deploy"), deploy(s),
        Bool.pick(IO(Unit), String.eq(v, "ship"), ship(s),
          IO.die(Unit, 1, "unknown verb " ++ v ++ ": use check, release, deploy or ship")))))

def chosen(args: List<String>, +s: S.System) -> IO(Unit):
  match args:
    case _ <> rest:
      match rest:
        case []:
          check(s)
        case v <> more:
          match more:
            case []:
              verb(v, s)
            case _:
              IO.die(Unit, 1, "one verb: check, release, deploy or ship")
    case []:
      check(s)

# The command line of a system.bend: `bend system <verb>`, check when there is none.
def cli(+s: S.System) -> IO(Unit):
  IO.bind(List<String>, Unit, IO.args(), args => chosen(args, s))
