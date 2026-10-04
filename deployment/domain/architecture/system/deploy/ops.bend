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
# deployment to its topology, plan from the declaration and what was observed, and run the plan. `diff` stops
# at the plan; `build`, `release` and `deploy` run its steps of their kind.
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

# A web app's build: the two entries V writes beside its folder, dist/<app>.page.bend (the first screen, as
# HTML) and dist/<app>.bend (the app: render f(state), wait for an input, update, again), run and built by
# the fork ($BEND, else ../f/bend2/main.ts beside the repository; bun and emcc from PATH, then Homebrew) into
# the folder dist/<app> (`-o dist/<app>.web`, which needs Emscripten), its index.html titled with the first screen's
# first text and holding that screen until the app starts; and dist/<app>.stamp, the hash of its inputs
# (the entries, the fork's commit, every Bend file of the repository) and of the folder. A build is fresh
# while both hashes hold. Arguments: the page entry, the folder's index.html, the app entry.
def inputs_script() -> String:
  "b=${BEND:-../f/bend2/main.ts}; export PATH=\"$PATH:/opt/homebrew/bin\"; u=$(command -v bun)\n" ++
  "h() { { printf '%s\\n%s\\n' \"$1\" \"$2\"; git -C \"$(dirname \"$b\")\" rev-parse HEAD 2>/dev/null; git ls-files -co --exclude-standard -z -- '*.bend' | xargs -0 shasum 2>/dev/null; } | shasum | cut -c1-40; }\n" ++
  "o() { (cd \"$1\" && find . -type f | LC_ALL=C sort | xargs shasum) | shasum | cut -c1-40; }\n" ++
  "d=$(dirname \"$2\")\n"

def stamp_script() -> String:
  inputs_script() ++
  "[ -f \"$2\" ] || { echo missing; exit 0; }\n" ++
  "w=$(printf '%s\\n%s' \"$(h \"$1\" \"$3\")\" \"$(o \"$d\")\")\n" ++
  "[ \"$(cat \"$d.stamp\" 2>/dev/null)\" = \"$w\" ] && echo fresh || echo stale"

def page_script() -> String:
  inputs_script() ++
  "f() { cat \"$d.err\" >&2 2>/dev/null; rm -rf \"$d.out\" \"$d.err\" \"$d.web\"; exit 1; }\n" ++
  "mkdir -p \"$(dirname \"$d\")\" || exit 1; k=$(h \"$1\" \"$3\"); printf '%s' \"$1\" > \"$d.page.bend\" && printf '%s' \"$3\" > \"$d.bend\" || exit 1\n" ++
  "\"$u\" \"$b\" \"$d.page.bend\" > \"$d.out\" 2> \"$d.err\" || f\n" ++
  "rm -rf \"$d.web\"; \"$u\" \"$b\" \"$d.bend\" -o \"$d.web\" > \"$d.err\" 2>&1 || f\n" ++
  "t=$(grep -o '>[^<>][^<>]*<' \"$d.out\" | head -1 | sed 's/^>//; s/<$//; s/[&|\\\\]/\\\\&/g')\n" ++
  "sed -i '' \"s|<title>Bend</title>|<title>$t</title>|\" \"$d.web/index.html\" || f\n" ++
  "awk -v f=\"$d.out\" '{ i = index($0, \"<div id=\\\"app\\\"></div>\"); if (i) { printf \"%s<div id=\\\"app\\\">\", substr($0, 1, i - 1); while ((getline l < f) > 0) printf \"%s\", l; printf \"</div>%s\\n\", substr($0, i + 20) } else print }' \"$d.web/index.html\" > \"$d.html\" && mv -f \"$d.html\" \"$d.web/index.html\" || f\n" ++
  "rm -rf \"$d.old\"; { [ ! -e \"$d\" ] || mv \"$d\" \"$d.old\"; } && mv \"$d.web\" \"$d\" || f\n" ++
  "rm -rf \"$d.old\" \"$d.out\" \"$d.err\"; printf '%s\\n%s\\n' \"$k\" \"$(o \"$d\")\" > \"$d.stamp\""

# The entries V writes for a web app at dist/<app>: the UI module's f at state.bend's initial(), as HTML;
# and the app, which renders f(state), waits for an input and applies update.bend's update to it.
def page_entry(+ui: String) -> String:
  "# Generated by V's build: " ++ ui ++ ".bend's f at state.bend's initial(), as HTML.\nimport F\nimport ../" ++ ui ++
  " as Ui\nimport ../state as St\n\ndef main() -> IO(Unit):\n  IO.print(Tree.html(Ui.f(St.initial())))\n"

def app_entry(+ui: String) -> String:
  "# Generated by V's build: the web app of " ++ ui ++ ".bend's f, state.bend's initial() and update.bend's update.\n" ++
  "import F\nimport ../" ++ ui ++ " as Ui\nimport ../state as St\nimport ../update as Up\n\n" ++
  "def loop(fuel: Nat, +s: St.State) -> IO(Unit):\n  match fuel:\n    case 0n:\n      IO.pure(Unit, Unit{})\n    case 1n+n:\n" ++
  "      do IO<Unit>:\n        u : Unit <- Tree.show(Ui.f(s))\n        i : Input <- Input.next()\n        loop(n, Up.update(s, i))\n\n" ++
  "def main() -> IO(Unit):\n  loop(4294967295n, St.initial())\n"

def stamped(r: Ran) -> P.Built:
  +w = String.trim(out(r))
  Bool.pick(P.Built, String.eq(w, "fresh"), P.Fresh{}, Bool.pick(P.Built, String.eq(w, "missing"), P.Missing{}, P.Stale{}))

def build_state(p: L.Program, +dir: String) -> IO(P.Built):
  match p:
    case L.Program{+path, b}:
      match b:
        case L.Page{+ui}:
          IO.bind(Ran, P.Built, sh(stamp_script(), [page_entry(ui), LO.at(dir, path), app_entry(ui)], ""), r => IO.pure(P.Built, stamped(r)))
        case _:
          IO.pure(P.Built, P.Fresh{})

def builds(ps: List<&2, L.Program>, +dir: String) -> IO(List<&2, P.Built>):
  match ps:
    case []:
      IO.pure(List<&2, P.Built>, [])
    case p <> rest:
      do IO<List<&2, P.Built>>:
        b : P.Built <- build_state(p, dir)
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

# The steps by what they are for: building, releasing, shipping (what a deploy needs built) and serving;
# and the address of each deployment.
type Planned is Data:
  Planned{builds: List<&2, P.Step>, releases: List<&2, P.Step>, ships: List<&2, P.Step>, serves: List<&2, P.Step>, addresses: List<&2, String>}

def joined(a: Planned, b: Planned) -> Planned:
  match a b:
    case Planned{w, x, y, z, p} Planned{w2, x2, y2, z2, q}:
      Planned{List.append(&2, P.Step, w, w2), List.append(&2, P.Step, x, x2), List.append(&2, P.Step, y, y2),
        List.append(&2, P.Step, z, z2), List.append(&2, String, p, q)}

def nothing() -> Planned:
  Planned{[], [], [], [], []}

def launchd_plan(+ld: L.Launchd, s: P.Seen, +address: String) -> Planned:
  +seen = s
  Planned{LO.build_steps(ld, seen), [], LO.ship_steps(ld, seen), LO.serve_all(ld, seen, address), []}

def node_plan(n: D.Node, +address: String, +ls: List<&2, String>) -> IO(Planned):
  match n:
    case D.Node{+key, _, _, _, _, platform, _, _}:
      match platform:
        case D.Unmanaged{}:
          IO.pure(Planned, nothing())
        case D.Launchd{+ld}:
          IO.bind(P.Seen, Planned, observe_at(ld, ls), s => IO.pure(Planned, launchd_plan(ld, s, address)))
        case _:
          IO.pure(Planned, Planned{[], [], [], [P.Blocked{"node " ++ key, "only launchd nodes deploy from here"}], []})

def node_plans(ns: List<&2, D.Node>, +address: String, +ls: List<&2, String>) -> IO(Planned):
  match ns:
    case []:
      IO.pure(Planned, nothing())
    case n <> rest:
      do IO<Planned>:
        a : Planned <- node_plan(n, address, ls)
        b : Planned <- node_plans(rest, address, ls)
        return joined(a, b)

def topology_plan(t: D.Topology, +ls: List<&2, String>) -> IO(Planned):
  match t:
    case D.Topology{+a, _, _, ns}:
      IO.bind(Planned, Planned, node_plans(ns, a, ls), p => IO.pure(Planned, joined(p, Planned{[], [], [], [], [a]})))

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
  Bool.pick(IO(Planned), List.is_empty(&2, P.Step, no), topology_plan(DO.lower(d, h), ls), IO.pure(Planned, Planned{no, [], [], [], []}))

def deployment_plan(+d: D.Deployment) -> IO(Planned):
  IO.bind(Ran, Planned, sh(here_script(), [], ""), r => mac_plan(d, lines(r)))

def deployment_plans(ds: List<&2, D.Deployment>) -> IO(Planned):
  match ds:
    case []:
      IO.pure(Planned, nothing())
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
        return joined(Planned{[], PO.plan(rs, o), [], [], []}, n)

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
    case P.BuildPage{+ui, page}:
      IO.bind(Ran, Unit, sh(page_script(), [page_entry(ui), page, app_entry(ui)], ""), r => done(r, PO.show(s)))
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

# Run the steps in order.
def run_all(ss: List<&2, P.Step>) -> IO(Unit):
  match ss:
    case []:
      IO.pure(Unit, Unit{})
    case +s <> rest:
      IO.bind(Unit, Unit, run(s), u => run_all(rest))

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

def diff_steps(p: Planned) -> List<&2, P.Step>:
  match p:
    case Planned{w, x, _, z, _}:
      List.append(&2, P.Step, w, List.append(&2, P.Step, x, z))

def build_steps(p: Planned) -> List<&2, P.Step>:
  match p:
    case Planned{w, _, _, _, _}:
      w

def release_steps(p: Planned) -> List<&2, P.Step>:
  match p:
    case Planned{_, x, _, _, _}:
      x

def deploy_steps(p: Planned) -> List<&2, P.Step>:
  match p:
    case Planned{_, _, y, z, _}:
      List.append(&2, P.Step, y, z)

# The steps of a verb: 1 builds, 2 releases, 3 deploys.
def section(+p: Planned, +k: U32) -> List<&2, P.Step>:
  Bool.pick(List<&2, P.Step>, U32.is_eq(k, 1), build_steps(p),
    Bool.pick(List<&2, P.Step>, U32.is_eq(k, 2), release_steps(p), deploy_steps(p)))

def addresses(p: Planned) -> List<&2, String>:
  match p:
    case Planned{_, _, _, _, xs}:
      xs

# Observe, print what the verb would do, and stop (exit 1) if a step is blocked; else run its steps, then,
# when it deploys, confirm each deployment's address answers.
def go(+s: S.System, +k: U32) -> IO(Unit):
  do IO<Unit>:
    +p : Planned <- planned(s)
    +ss : List<&2, P.Step> = section(p, k)
    b : Bool <- shown(ss)
    Bool.pick(IO(Unit), b, IO.die(Unit, 1, "blocked: nothing done"),
      IO.bind(Unit, Unit, run_all(ss), u => Bool.pick(IO(Unit), U32.is_eq(k, 3), lives(addresses(p)), IO.pure(Unit, Unit{}))))

# diff: compare the system with the world and print the steps that would make them agree (what to build,
# release and serve); change nothing (exit 1 when a step is blocked).
def diff(s: S.System) -> IO(Unit):
  do IO<Unit>:
    p : Planned <- planned(s)
    b : Bool <- shown(diff_steps(p))
    Bool.pick(IO(Unit), b, IO.die(Unit, 1, "blocked"), IO.print("ready"))

# build: build every app into dist/, and nothing else.
def build(+s: S.System) -> IO(Unit):
  go(s, 1)

# release: push the code and publish the packages and plugins. It builds nothing.
def release(+s: S.System) -> IO(Unit):
  go(s, 2)

# deploy: ship what is in dist/ (blocked when an app is not built from the current inputs), launch and serve,
# and confirm each address answers. It builds nothing.
def deploy(+s: S.System) -> IO(Unit):
  go(s, 3)

def verb(+v: String, +s: S.System) -> IO(Unit):
  Bool.pick(IO(Unit), String.eq(v, "diff"), diff(s),
    Bool.pick(IO(Unit), String.eq(v, "build"), build(s),
      Bool.pick(IO(Unit), String.eq(v, "release"), release(s),
        Bool.pick(IO(Unit), String.eq(v, "deploy"), deploy(s),
          IO.die(Unit, 1, "unknown verb " ++ v ++ ": use diff, build, release or deploy")))))

def chosen(args: List<String>, +s: S.System) -> IO(Unit):
  match args:
    case _ <> rest:
      match rest:
        case []:
          diff(s)
        case v <> more:
          match more:
            case []:
              verb(v, s)
            case _:
              IO.die(Unit, 1, "one verb: diff, build, release or deploy")
    case []:
      diff(s)

# The command line of a system.bend: `bend system <verb>`, diff when there is none.
def cli(+s: S.System) -> IO(Unit):
  IO.bind(List<String>, Unit, IO.args(), args => chosen(args, s))
