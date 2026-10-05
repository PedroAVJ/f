import Base
import ../type.bend as S
import ../deployment/type.bend as D
import ../deployment/ops.bend as DO
import ../deployment/launchd/type.bend as L
import ../deployment/launchd/ops.bend as LO
import ../deployment/bundle/type.bend as Bu
import ../deployment/bundle/ops.bend as BuO
import ../plan/type.bend as P
import ../plan/ops.bend as PO
import ../release/type.bend as Rl

# A system deployed from the repository it lives in (the current directory): observe the world, lower each
# deployment to its topology, plan from the declaration and what was observed, and run the plan. `diff` stops
# at the plan; `build`, `release` and `deploy` run its steps of their kind. This Mac's nodes deploy from
# here: launchd (a web app, served on the tailnet) and bundles (a Mac app, installed in ~/Applications).
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
# each agent of a lowered launchd node, and each Mac app's build and installed copy ----

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
# HTML) and dist/<app>.bend (the app): the page run by the fork's CLI ($BEND, else ../f/bend2/main.ts beside
# the repository; bun and emcc from PATH, then Homebrew), the app built by the fork's internal tool beside
# it (tool.ts `-o dist/<app>.web`, which needs Emscripten; the CLI only runs) into the folder dist/<app>.
# Its index.html is titled with the first screen's first text, holds that screen until the app starts,
# resolves its files from "/" (any path is the app) and loads the fork's address.js (the address bar follows
# the page). dist/<app>.stamp holds the hash of its inputs (the entries, the fork's commit, every Bend file of
# the repository) and of the folder; a build is fresh while both hold.
# Arguments: the page entry, the folder's index.html, the app entry.
def tools_script() -> String:
  "b=${BEND:-../f/bend2/main.ts}; export PATH=\"$PATH:/opt/homebrew/bin\"; u=$(command -v bun)\n" ++
  "h() { { printf '%s\\n%s\\n' \"$1\" \"$2\"; git -C \"$(dirname \"$b\")\" rev-parse HEAD 2>/dev/null; git ls-files -co --exclude-standard -z -- '*.bend' | xargs -0 shasum 2>/dev/null; } | shasum | cut -c1-40; }\n" ++
  "o() { (cd \"$1\" && find . -type f | LC_ALL=C sort | xargs shasum) | shasum | cut -c1-40; }\n"

def inputs_script() -> String:
  tools_script() ++ "d=$(dirname \"$2\")\n"

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
  "rm -rf \"$d.web\"; \"$u\" \"$(dirname \"$b\")/tool.ts\" \"$d.bend\" -o \"$d.web\" > \"$d.err\" 2>&1 || f\n" ++
  "cp \"$(dirname \"$b\")/std/F/browser/address.js\" \"$d.web/\" || f\n" ++
  "t=$(grep -o '>[^<>][^<>]*<' \"$d.out\" | head -1 | sed 's/^>//; s/<$//; s/[&|\\\\]/\\\\&/g')\n" ++
  "sed -i '' \"s|<title>Bend</title>|<base href=\\\"/\\\"><title>$t</title>|\" \"$d.web/index.html\" || f\n" ++
  "awk -v f=\"$d.out\" '{ i = index($0, \"<div id=\\\"app\\\"></div>\"); if (i) { printf \"%s<div id=\\\"app\\\">\", substr($0, 1, i - 1); while ((getline l < f) > 0) printf \"%s\", l; printf \"</div>%s\\n\", substr($0, i + 20) } else print } END { print \"<script type=\\\"module\\\" src=\\\"./address.js\\\"></script>\" }' \"$d.web/index.html\" > \"$d.html\" && mv -f \"$d.html\" \"$d.web/index.html\" || f\n" ++
  "rm -rf \"$d.old\"; { [ ! -e \"$d\" ] || mv \"$d\" \"$d.old\"; } && mv \"$d.web\" \"$d\" || f\n" ++
  "rm -rf \"$d.old\" \"$d.out\" \"$d.err\"; printf '%s\\n%s\\n' \"$k\" \"$(o \"$d\")\" > \"$d.stamp\""

# The entries V writes for a web app at dist/<app> from its UI module, which defines State (with a
# `page: Page` field, and a `lang: Lang` one for any language but English), s() (the first state),
# update(s, input) and f(s): the first screen as HTML; and the app: wait for the browser's address, then show
# f(s) at its page's address in its language, with the states its inputs own, wait for an input, and either
# go to the page an address names or update (keeping the inputs' states), again.
def page_entry(+ui: String) -> String:
  "# Generated by V's build: " ++ ui ++ ".bend's f at its s(), as HTML.\nimport UI\nimport ../" ++ ui ++
  " as Ui\n\ndef main() -> IO(Unit):\n  IO.print(UI.html(Ui.f(Ui.s()), Ui.State.lang(Ui.s())))\n"

# An app's step and loop, shared by the web app and the Mac app: show is how one shows f(s).
def step_entry(+ui: String) -> String:
  "import UI\nimport ../" ++ ui ++ " as Ui\n\n" ++
  "def step(+s: Ui.State, +i: Input) -> Ui.State:\n  match i:\n    case Navigated{a}:\n      Ui.State.with_page(s, Ui.Page.at(a))\n" ++
  "    case Clicked{l}:\n      Ui.update(s, Clicked{l})\n    case Typed{l, v}:\n      Ui.update(s, Typed{l, v})\n" ++
  "    case Focused{l}:\n      Ui.update(s, Focused{l})\n    case Blurred{l}:\n      Ui.update(s, Blurred{l})\n    case Ignored{}:\n      Ui.update(s, Ignored{})\n    case _:\n      Ui.update(s, i)\n\n"

def loop_entry(+show: String) -> String:
  "def loop(fuel: Nat, +s: Ui.State, +k: List<&2, Held>) -> IO(Unit):\n  match fuel:\n    case 0n:\n      IO.pure(Unit, Unit{})\n    case 1n+n:\n" ++
  "      do IO<Unit>:\n        u : Unit <- " ++ show ++ "\n" ++
  "        +i : Input <- Input.next()\n        loop(n, step(s, i), Input.keep(k, i))\n\n"

def app_entry(+ui: String) -> String:
  "# Generated by V's build: the web app of " ++ ui ++ ".bend's s, update and f, its address its Page's.\n" ++
  step_entry(ui) ++ loop_entry("UI.show_at(Ui.f(s), Rendering{Ui.State.lang(s), k}, Ui.Page.url(Ui.State.page(s)))") ++
  "def main() -> IO(Unit):\n  do IO<Unit>:\n    i : Input <- Input.next()\n    loop(4294967295n, step(Ui.s(), i), [])\n"

# The entry V writes for a Mac app at dist/<app>.macos.bend: from s(), show f(s) as Canvas commands (the
# native shell paints them, its buttons and textboxes live) with the states its inputs own, wait for an
# input, and update (an address the shell sends goes to its page), again.
def native_entry_options(+ui: String, +themed: Bool, +persist: Bool, +window: Bool) -> String:
  "# Generated by V's build: the Mac app of " ++ ui ++ ".bend's s, update and f, drawn as Canvas commands.\n" ++
  "import ../../f/bend2/std/F/browser/input.bend as Native\n" ++
  step_entry(ui) ++ loop_entry(Bool.pick(String, themed,
    "Native.show_canvas_in(Ui.f(s), Rendering{Ui.State.lang(s), k}, Ui.scheme())",
    "Native.show_canvas(Ui.f(s), Rendering{Ui.State.lang(s), k})")) ++
  Bool.pick(String, persist || window,
    "def main() -> IO(Unit):\n  do IO<Unit>:\n" ++
    Bool.pick(String, persist, "    u : Unit <- Native.configure_input_persistence(Ui.persist_inputs())\n", "") ++
    Bool.pick(String, window, "    w : Unit <- Native.configure_window(Ui.window())\n", "") ++
    "    loop(4294967295n, Ui.s(), [])\n",
    "def main() -> IO(Unit):\n  loop(4294967295n, Ui.s(), [])\n")

def native_entry_config(+ui: String, +themed: Bool, +persist: Bool) -> String:
  native_entry_options(ui, themed, persist, False{})

def native_entry_in(+ui: String, +themed: Bool) -> String:
  native_entry_config(ui, themed, False{})

def native_entry(+ui: String) -> String:
  native_entry_in(ui, False{})

def built_of(+w: String) -> P.Built:
  Bool.pick(P.Built, String.eq(w, "fresh"), P.Fresh{}, Bool.pick(P.Built, String.eq(w, "missing"), P.Missing{}, P.Stale{}))

def stamped(r: Ran) -> P.Built:
  built_of(String.trim(out(r)))

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

# ---- a Mac app: the entries V writes beside its folder dist/<app>.macos, <folder>.page.bend (the first screen,
# as HTML, run for its first text, the app's name) and <folder>.bend (the native entry), built by the fork's
# internal tool (tool.ts `-o <folder> --id <bundle identifier> --name <name> --version <CFBundleVersion>`, which
# needs Xcode's clang) into <folder>/<name>.app, its version the build's time. <folder>.stamp holds the hash of
# its inputs (the entries, the fork's commit and its uncommitted bend2/ changes, every Bend file of the
# repository), of the folder, then its version and name; a build is fresh while both hashes hold.
# A UI module may opt into a native scheme with def scheme() -> T.Scheme, and
# choose whether the shell retains textbox values with def persist_inputs() -> Bool.
# def window() -> Native.WindowConfig opts into viewport resize events and gives the
# initial and minimum content sizes. An app's State handles Resized in update.
# Build and stamp select the same generated entry; web rendering keeps its defaults.
# Arguments: the page entry, the folder, the default app entry, the bundle identifier,
# the UI module path, the themed entry, the persistence entry, both options' entry ----
# The native entry follows the selected compiler, including app packages inside F.
def native_import_script() -> String:
  "e=$(printf '%s' \"$e\" | python3 -c 'import os,sys; p=os.path.relpath(os.path.join(sys.argv[1], \"std/F/browser/input.bend\"), os.path.dirname(sys.argv[2]) or \".\"); sys.stdout.write(sys.stdin.read().replace(\"import ../../f/bend2/std/F/browser/input.bend as Native\", \"import \" + p + \" as Native\"))' \"$f\" \"$d\") || exit 1\n"

def app_script() -> String:
  tools_script() ++
  "d=$2; f=$(dirname \"$b\"); e=$3\n" ++
  "if [ -n \"$5\" ] && [ -f \"$5.bend\" ]; then\n" ++
  "  if grep -Eq '^def scheme[[:space:]]*\\(' \"$5.bend\"; then e=$6; if grep -Eq '^def persist_inputs[[:space:]]*\\(' \"$5.bend\"; then e=$8; fi\n" ++
  "  elif grep -Eq '^def persist_inputs[[:space:]]*\\(' \"$5.bend\"; then e=$7; fi\n" ++
  "  if grep -Eq '^def window[[:space:]]*\\(' \"$5.bend\"; then\n" ++
  "    e=${9}; if grep -Eq '^def scheme[[:space:]]*\\(' \"$5.bend\"; then e=${10}; if grep -Eq '^def persist_inputs[[:space:]]*\\(' \"$5.bend\"; then e=${12}; fi\n" ++
  "    elif grep -Eq '^def persist_inputs[[:space:]]*\\(' \"$5.bend\"; then e=${11}; fi\n" ++
  "  fi\n" ++
  "fi\n" ++ native_import_script() ++
  "o() { (cd \"$1\" && find . -type f -exec shasum {} + | LC_ALL=C sort) | shasum | cut -c1-40; }\n" ++
  "k() { printf '%s\\n%s\\n%s\\n' \"$(h \"$1\" \"$2\")\" \"$3\" \"$( (cd \"$f\" && { git diff HEAD -- .; git ls-files -o --exclude-standard -z -- . | xargs -0 shasum; }) 2>/dev/null | shasum | cut -c1-40)\" | shasum | cut -c1-40; }\n" ++
  "p() { plutil -extract \"$2\" raw -o - \"$1/Contents/Info.plist\" 2>/dev/null; }\n"

# Lines: fresh, stale or missing; the built app's name and version; the version of our app in
# ~/Applications under that name; another app in ~/Applications or /Applications under that name.
def app_stamp_script() -> String:
  app_script() ++
  "n=$(sed -n 4p \"$d.stamp\" 2>/dev/null); v=$(sed -n 3p \"$d.stamp\" 2>/dev/null); i=; x=\n" ++
  "if [ ! -d \"$d\" ] || [ -z \"$n\" ]; then w=missing; elif [ \"$(p \"$d/$n.app\" CFBundleIdentifier) $(p \"$d/$n.app\" CFBundleVersion)\" = \"$4 $v\" ] && [ \"$(sed -n 1,2p \"$d.stamp\")\" = \"$(printf '%s\\n%s' \"$(k \"$1\" \"$e\" \"$4\")\" \"$(o \"$d\")\")\" ]; then w=fresh; else w=stale; fi\n" ++
  "for a in \"$HOME/Applications/$n.app\" \"/Applications/$n.app\"; do\n" ++
  "  [ -n \"$n\" ] && [ -e \"$a\" ] || continue\n" ++
  "  if [ \"$(p \"$a\" CFBundleIdentifier)\" = \"$4\" ]; then [ \"$a\" != \"$HOME/Applications/$n.app\" ] || i=$(p \"$a\" CFBundleVersion); else x=\"$a ($(p \"$a\" CFBundleIdentifier || echo no bundle identifier))\"; fi\n" ++
  "done\n" ++
  "printf '%s\\n%s\\n%s\\n%s\\n%s\\n' \"$w\" \"$n\" \"$v\" \"$i\" \"$x\""

def app_build_script() -> String:
  app_script() ++
  "x() { cat \"$d.err\" >&2 2>/dev/null; rm -f \"$d.out\" \"$d.err\"; exit 1; }\n" ++
  "mkdir -p \"$(dirname \"$d\")\" || exit 1; c=$(k \"$1\" \"$e\" \"$4\"); printf '%s' \"$1\" > \"$d.page.bend\" && printf '%s' \"$e\" > \"$d.bend\" || exit 1\n" ++
  "\"$u\" \"$b\" \"$d.page.bend\" > \"$d.out\" 2> \"$d.err\" || x\n" ++
  "n=$(grep -o '>[^<>][^<>]*<' \"$d.out\" | head -1 | sed 's/^>//; s/<$//; s/&lt;/</g; s/&gt;/>/g; s/&quot;/\"/g; s/&#39;/'\"'\"'/g; s/&amp;/\\&/g; s/^[[:space:]]*//; s/[[:space:]]*$//' | tr '/:' '--')\n" ++
  "[ -n \"$n\" ] || n=$(basename \"$(pwd -P)\"); v=$(date +%s)\n" ++
  "\"$u\" \"$f/tool.ts\" \"$d.bend\" -o \"$d\" --id \"$4\" --name \"$n\" --version \"$v\" > \"$d.err\" 2>&1 || x\n" ++
  "[ \"$(p \"$d/$n.app\" CFBundleIdentifier) $(p \"$d/$n.app\" CFBundleVersion)\" = \"$4 $v\" ] || { echo \"the build made no $n.app with $4 at version $v\" >> \"$d.err\"; x; }\n" ++
  "rm -f \"$d.out\" \"$d.err\"; printf '%s\\n%s\\n%s\\n%s\\n' \"$c\" \"$(o \"$d\")\" \"$v\" \"$n\" > \"$d.stamp\""

# Install the built app ($1, its bundle identifier $2 and version $3) in ~/Applications: never over another
# app; quit the running copy (TERM, then KILL after 5 s), replace the installed one, open it, and see it run.
def install_script() -> String:
  "p() { plutil -extract \"$2\" raw -o - \"$1/Contents/Info.plist\" 2>/dev/null; }\n" ++
  "q() { lsappinfo info -only pid \"$1\" 2>/dev/null | sed -n 's/.*\"pid\"=\\([0-9][0-9]*\\).*/\\1/p'; }\n" ++
  "a=$1; n=$(basename \"$a\"); t=\"$HOME/Applications/$n\"\n" ++
  "[ \"$(p \"$a\" CFBundleIdentifier) $(p \"$a\" CFBundleVersion)\" = \"$2 $3\" ] || { echo \"$a is not the build its stamp records\" >&2; exit 1; }\n" ++
  "wanted=$2; check() { for o in \"$t\" \"/Applications/$n\"; do { [ ! -e \"$o\" ] && [ ! -L \"$o\" ]; } || [ \"$(p \"$o\" CFBundleIdentifier)\" = \"$wanted\" ] || { echo \"$o is another app; not replacing it\" >&2; return 1; }; done; }\n" ++
  "check || exit 1; mkdir -p \"$HOME/Applications\" || exit 1; stage=$(mktemp -d \"$HOME/Applications/.bend-install.XXXXXX\") || exit 1\n" ++
  "trap 'rm -rf \"$stage\"' EXIT; ditto \"$a\" \"$stage/$n\" && codesign --verify --strict \"$stage/$n\" || exit 1\n" ++
  "i=0; while c=$(q \"$2\"); [ -n \"$c\" ]; do kill -TERM \"$c\" 2>/dev/null; i=$((i+1)); [ $i -lt 20 ] || kill -KILL \"$c\" 2>/dev/null; [ $i -lt 40 ] || { echo \"$2 (pid $c) does not quit\" >&2; exit 1; }; sleep 0.25; done\n" ++
  "check || exit 1; if [ -e \"$t\" ] || [ -L \"$t\" ]; then mv \"$t\" \"$stage/previous\" || exit 1; fi\n" ++
  "mv \"$stage/$n\" \"$t\" || { [ ! -e \"$stage/previous\" ] || mv \"$stage/previous\" \"$t\"; exit 1; }\n" ++
  "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f \"$t\" 2>/dev/null\n" ++
  "open \"$t\" || exit 1; i=0; until [ -n \"$(q \"$2\")\" ]; do i=$((i+1)); [ $i -lt 60 ] || { echo \"$n did not start\" >&2; exit 1; }; sleep 0.25; done\n" ++
  "sleep 1; [ -n \"$(q \"$2\")\" ] || { echo \"$n quit as it started\" >&2; exit 1; }"

def bundled(+ls: List<&2, String>) -> P.Bundled:
  P.Bundled{built_of(line(ls, 0n)), line(ls, 1n), line(ls, 2n), line(ls, 3n), line(ls, 4n)}

def native_args(+ui: String, dir: String, id: String) -> List<&2, String>:
  [page_entry(ui), dir, native_entry(ui), id, ui, native_entry_in(ui, True{}),
   native_entry_config(ui, False{}, True{}), native_entry_config(ui, True{}, True{}),
   native_entry_options(ui, False{}, False{}, True{}), native_entry_options(ui, True{}, False{}, True{}),
   native_entry_options(ui, False{}, True{}, True{}), native_entry_options(ui, True{}, True{}, True{})]

# A Mac app's build and installed copy, its folder under the repository's (dir).
def bundle_state(a: Bu.MacApp, +dir: String) -> IO(P.Bundled):
  match a:
    case Bu.MacApp{+ui, id, path}:
      IO.bind(Ran, P.Bundled, sh(app_stamp_script(), native_args(ui, LO.at(dir, path), id), ""),
        r => IO.pure(P.Bundled, bundled(lines(r))))

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

# ---- the plan: the release's steps, then each deployment's, lowered to its topology. Only this Mac's nodes
# (launchd and bundles) deploy from here ----

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

# A Mac app: built, shipped (built from the current inputs) and installed.
def bundle_plan(+a: Bu.MacApp, +o: P.Bundled) -> Planned:
  Planned{BuO.build_steps(a, o), [], BuO.ship_steps(a, o), BuO.install_steps(a, o), []}

def node_plan(n: D.Node, +address: String, +ls: List<&2, String>) -> IO(Planned):
  match n:
    case D.Node{+key, _, _, _, _, platform, _, _}:
      match platform:
        case D.Unmanaged{}:
          IO.pure(Planned, nothing())
        case D.Launchd{+ld}:
          IO.bind(P.Seen, Planned, observe_at(ld, ls), s => IO.pure(Planned, launchd_plan(ld, s, address)))
        case D.Bundle{+a}:
          IO.bind(P.Bundled, Planned, bundle_state(a, line(ls, 2n)), o => IO.pure(Planned, bundle_plan(a, o)))
        case _:
          IO.pure(Planned, Planned{[], [], [], [P.Blocked{"node " ++ key, "only launchd and bundle nodes deploy from here"}], []})

def node_plans(ns: List<&2, D.Node>, +address: String, +ls: List<&2, String>) -> IO(Planned):
  match ns:
    case []:
      IO.pure(Planned, nothing())
    case n <> rest:
      do IO<Planned>:
        a : Planned <- node_plan(n, address, ls)
        b : Planned <- node_plans(rest, address, ls)
        return joined(a, b)

# The topology's steps, and its address when it has one (a deployment with no web app has none).
def topology_plan(t: D.Topology, +ls: List<&2, String>) -> IO(Planned):
  match t:
    case D.Topology{+a, _, _, ns}:
      IO.bind(Planned, Planned, node_plans(ns, a, ls),
        p => IO.pure(Planned, joined(p, Planned{[], [], [], [], Bool.pick(List<&2, String>, String.is_empty(a), [], [a])})))

# What stops a Mac deployment before it is lowered: no app, or more than one web app (one Tailscale port
# serves one app so far), or no free local port for its web app. Mac apps take no port.
def unlowered(+d: D.Deployment, +h: D.Here) -> List<&2, P.Step>:
  +w = DO.webs(DO.apps(d))
  Bool.pick(List<&2, P.Step>, List.is_empty(&2, D.Application, DO.apps(d)),
    [P.Blocked{"mac", "no app declared"}],
  Bool.pick(List<&2, P.Step>, Nat.is_gt(DO.native_apps(DO.apps(d)), 1n),
    [P.Blocked{"mac", "one Mac app per deployment so far"}],
  Bool.pick(List<&2, P.Step>, Nat.is_gt(w, 1n),
    [P.Blocked{"mac :" ++ U32.show(DO.https(d)), "one app per Tailscale port so far"}],
    Bool.pick(List<&2, P.Step>, Nat.is_eq(w, 1n) && U32.is_eq(DO.port(d, h), 0),
      [P.Blocked{"mac :" ++ U32.show(DO.https(d)), "no free local port in 4600-4990"}], []))))

def mac_plan(+d: D.Deployment, +ls: List<&2, String>) -> IO(Planned):
  +h = here(ls)
  +no = unlowered(d, h)
  Bool.pick(IO(Planned), List.is_empty(&2, P.Step, no), topology_plan(DO.lower(d, h), ls), IO.pure(Planned, Planned{no, [], no, [], []}))

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
    case P.BuildApp{+ui, dir, id}:
      IO.bind(Ran, Unit, sh(app_build_script(), native_args(ui, dir, id), ""), r => done(r, PO.show(s)))
    case P.Install{_, id, app, version}:
      IO.bind(Ran, Unit, sh(install_script(), [app, id, version], ""), r => done(r, PO.show(s)))
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
