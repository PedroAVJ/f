import Base
import ./type.bend as D
import ./host/type.bend as H
import ./launchd/type.bend as L
import ./launchd/ops.bend as LO
import ./nix_darwin/type.bend as ND
import ./bundle/type.bend as Bu

# ---- what a deploy breaks: compared with what was deployed before (its address and stores) ----
def address(d: D.Topology) -> String:
  match d:
    case D.Topology{a, _, _, _}:
      a

def stores(d: D.Topology) -> List<&2, String>:
  match d:
    case D.Topology{_, ss, _, _}:
      ss

def accepted(d: D.Topology) -> List<&2, D.Break>:
  match d:
    case D.Topology{_, _, acc, _}:
      acc

def keep_break(present: Bool, +o: String, rest: List<&2, D.Break>) -> List<&2, D.Break>:
  match present:
    case True{}:
      rest
    case False{}:
      D.StoreRemoved{o} <> rest

def removed(olds: List<&2, String>, +news: List<&2, String>) -> List<&2, D.Break>:
  match olds:
    case []:
      []
    case +o <> rest:
      keep_break(List.contains(~String, ~String.eq, news, o), o, removed(rest, news))

# The address changing, then each store the new deployment drops. A first deploy (no address before) breaks nothing.
def breaks(+before: String, olds: List<&2, String>, +d: D.Topology) -> List<&2, D.Break>:
  List.append(&2, D.Break,
    Bool.pick(List<&2, D.Break>, String.is_empty(before) || String.eq(before, address(d)), [], [D.AddressChanged{}]),
    removed(olds, stores(d)))

def break_eq(a: D.Break, b: D.Break) -> Bool:
  match a b:
    case D.AddressChanged{} D.AddressChanged{}:
      True{}
    case D.StoreRemoved{x} D.StoreRemoved{y}:
      String.eq(x, y)
    case _ _:
      False{}

def breaks_eq(a: List<&2, D.Break>, b: List<&2, D.Break>) -> Bool:
  match a:
    case []:
      List.is_empty(&2, D.Break, b)
    case x <> xs:
      match b:
        case []:
          False{}
        case y <> ys:
          break_eq(x, y) && breaks_eq(xs, ys)

def show_break(b: D.Break) -> String:
  match b:
    case D.AddressChanged{}:
      "the address changes"
    case D.StoreRemoved{n}:
      "store " ++ n ++ " is removed"

def shown(bs: List<&2, D.Break>) -> List<&2, String>:
  match bs:
    case []:
      []
    case b <> rest:
      show_break(b) <> shown(rest)

def show_breaks(bs: List<&2, D.Break>) -> String:
  String.join(shown(bs), ", ")

def store_lines(ss: List<&2, String>) -> String:
  match ss:
    case []:
      ""
    case s <> rest:
      "store " ++ s ++ "\n" ++ store_lines(rest)

# What a deploy records as deployed: the address, then one store per line.
def record(+d: D.Topology) -> String:
  "address " ++ address(d) ++ "\n" ++ store_lines(stores(d))

def keep_rest(c: Bool, +prefix: String, l: String, rest: List<&2, String>) -> List<&2, String>:
  match c:
    case True{}:
      String.drop(l, String.length(prefix)) <> rest
    case False{}:
      rest

# The lines that start with a prefix, without it.
def after(+prefix: String, ls: List<&2, String>) -> List<&2, String>:
  match ls:
    case []:
      []
    case +l <> rest:
      keep_rest(String.starts_with(l, prefix), prefix, l, after(prefix, rest))

# The address and stores in a record ("" and [] when nothing was deployed).
def recorded_address(+text: String) -> String:
  Maybe.default(&2, String, List.head(&2, String, after("address ", String.lines(text))), "")

def recorded_stores(+text: String) -> List<&2, String>:
  after("store ", String.lines(text))

# ---- lowering a Mac deployment to its topology: what V derives from the intent and the Mac ----

def digits(+s: String) -> U32:
  +p = Maybe.default(&2, U32, U32.read(s), 0)
  Bool.pick(U32, String.eq(U32.show(p), s), p, 0)

# The local port a `tailscale serve status` line proxies "/" to (0 for any other line).
def proxied(m: Maybe<&2, String>) -> U32:
  match m:
    case None{}:
      0
    case Some{l}:
      +t = String.trim(l)
      +pre : String = "|-- / proxy http://127.0.0.1:"
      Bool.pick(U32, String.starts_with(t, pre), digits(String.drop(t, String.length(pre))), 0)

# The local port behind a tailnet HTTPS port: the one Tailscale already serves it from, which records an
# earlier deploy's choice, else the Mac's free one.
def local_port(+https: U32, h: D.Here) -> U32:
  match h:
    case D.Here{_, _, _, served, free}:
      +p = proxied(LO.under(served, ":" ++ U32.show(https) ++ " ("))
      Bool.pick(U32, U32.is_eq(p, 0), free, p)

def tailnet_address(+name: String, +https: U32) -> String:
  "https://" ++ name ++ Bool.pick(String, U32.is_eq(https, 443), "", ":" ++ U32.show(https))

# A web app on this Mac, named web: built to dist/web, a launch agent com.<user>.<repo>.web serving that
# folder on 127.0.0.1 at the local port (python3's http.server, its index.html for any path that is not a
# file, so every page's address loads the app), and the tailnet HTTPS port proxied to it.
def app_server() -> String:
  "import functools, http.server as s, os, sys\n" ++
  "class H(s.SimpleHTTPRequestHandler):\n" ++
  "    def send_head(self):\n" ++
  "        if not os.path.isfile(self.translate_path(self.path)): self.path = '/index.html'\n" ++
  "        return super().send_head()\n" ++
  "s.ThreadingHTTPServer(('127.0.0.1', int(sys.argv[1])), functools.partial(H, directory=sys.argv[2])).serve_forever()\n"

def web_node(+user: String, +repo: String, +https: U32, +port: U32, ui: String) -> D.Node:
  +a : String = "web"
  +dir = "dist/" ++ a
  D.Node{"mac", "this Mac", "launchd", D.Server{}, H.Owned{"this Mac"},
    D.Launchd{L.Launchd{
      [L.Program{dir ++ "/index.html", L.Page{ui}}],
      [L.Agent{a, "com." ++ user ++ "." ++ repo ++ "." ++ a, "/usr/bin/python3",
        ["-c", app_server(), U32.show(port), dir], [], repo ++ "-" ++ a, port}],
      [ND.Serve{a, https, port, "/"}]}},
    [], [a]}

# A Mac app on this Mac, named mac: built to dist/mac.macos, bundle identifier com.<user>.<repo>.mac,
# installed in ~/Applications.
def mac_node(+user: String, +repo: String, ui: String) -> D.Node:
  +a : String = "mac"
  D.Node{"mac", "this Mac", "AppKit", D.Device{}, H.Owned{"this Mac"},
    D.Bundle{Bu.MacApp{ui, "com." ++ user ++ "." ++ repo ++ "." ++ a, "dist/" ++ a ++ ".macos"}}, [], [a]}

def app_node(+user: String, +repo: String, +https: U32, +port: U32, app: D.Application) -> D.Node:
  match app:
    case D.Web{ui}:
      web_node(user, repo, https, port, ui)
    case D.MacOS{ui}:
      mac_node(user, repo, ui)

def app_nodes(+user: String, +repo: String, +https: U32, +port: U32, apps: List<&2, D.Application>) -> List<&2, D.Node>:
  match apps:
    case []:
      []
    case app <> rest:
      app_node(user, repo, https, port, app) <> app_nodes(user, repo, https, port, rest)

# How many of the apps are web apps (the ones Tailscale serves).
def webs(apps: List<&2, D.Application>) -> Nat:
  match apps:
    case []:
      0n
    case app <> rest:
      match app:
        case D.Web{_}:
          Nat.add(1n, webs(rest))
        case _:
          webs(rest)

# Mac apps currently share one native output folder and bundle identifier per deployment.
def native_apps(apps: List<&2, D.Application>) -> Nat:
  match apps:
    case []:
      0n
    case app <> rest:
      match app:
        case D.MacOS{_}:
          Nat.add(1n, native_apps(rest))
        case _:
          native_apps(rest)

def https_of(x: D.Exposure) -> U32:
  match x:
    case D.Tailscale{p}:
      p

# The tailnet HTTPS port a deployment is reached at, its apps, and the local port its app listens on.
def https(d: D.Deployment) -> U32:
  match d:
    case D.Mac{x, _}:
      https_of(x)

def apps(d: D.Deployment) -> List<&2, D.Application>:
  match d:
    case D.Mac{_, xs}:
      xs

def port(+d: D.Deployment, h: D.Here) -> U32:
  local_port(https(d), h)

# A Mac deployment lowered: reached at https://<tailnet name>:<port> ("" when it has no web app), one node
# per app (launchd for a web app, a bundle for a Mac app).
def lower(+d: D.Deployment, +h: D.Here) -> D.Topology:
  match h:
    case D.Here{+user, +repo, +name, _, _}:
      +x = https(d)
      D.Topology{Bool.pick(String, Nat.is_eq(webs(apps(d)), 0n), "", tailnet_address(name, x)), [], [],
        app_nodes(user, repo, x, port(d, h), apps(d))}
