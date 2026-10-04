import Base
import ../release/type.bend as Rl
import ../release/ops.bend as RlO
import ../release/plugin/ops.bend as PlO
import ./type.bend as P

# GitHub's visibility for a repository whose source is open, or proprietary.
def visibility(s: Rl.Source) -> String:
  match s:
    case Rl.OpenSource{_}:
      "public"
    case Rl.Proprietary{}:
      "private"

# ---- the repository: no dead Bend and hub paths the hub takes come first, then GitHub. What else the
# repository holds is its containers' business, checked against their declared stacks ----
def repo_steps(+fs: List<&2, String>, +reached: List<&2, String>) -> List<&2, P.Step>:
  List.append(&2, P.Step,
    Bool.pick(List<&2, P.Step>, String.is_empty(RlO.dead(fs, reached)), [],
      [P.Blocked{"repository", RlO.dead(fs, reached) ++ " is dead code: no entry reaches it"}]),
    Bool.pick(List<&2, P.Step>, String.is_empty(RlO.hub_refused(reached)), [],
      [P.Blocked{"repository", RlO.hub_refused(reached) ++ ": the Bend hub refuses this path (segments of letters, digits and _)"}]))

# ---- each repository the code is released from: origin is github.com/<owner>/<name>, GitHub's visibility
# follows its source, and the working tree is clean and pushed ----
def remote_step(repo: Rl.Repository, rm: P.Remote) -> P.Step:
  match repo rm:
    case Rl.GitHub{+owner, +name, src} P.Remote{+origin, +vis, clean, pushed}:
      +slug = owner ++ "/" ++ name
      +want = visibility(src)
      Bool.pick(P.Step, String.eq(origin, "github.com/" ++ slug),
        Bool.pick(P.Step, String.eq(vis, want),
          Bool.pick(P.Step, clean,
            Bool.pick(P.Step, pushed, P.Current{"github " ++ slug}, P.Push{slug}),
            P.Blocked{"github " ++ slug, "uncommitted changes"}),
          P.Blocked{"github " ++ slug, "GitHub says " ++ Bool.pick(String, String.is_empty(vis), "nothing (unreachable)", vis) ++ ", declared " ++ want}),
        P.Blocked{"github " ++ slug, "origin is " ++ Bool.pick(String, String.is_empty(origin), "missing", origin) ++ ", declared github.com/" ++ slug})

def remote_steps(rs: List<&2, Rl.Release>, ms: List<&2, P.Remote>) -> List<&2, P.Step>:
  match rs:
    case []:
      []
    case r <> rest:
      match r:
        case Rl.Code{repo}:
          match ms:
            case []:
              [P.Blocked{"repository observation", "missing GitHub snapshot for a declared repository"}]
            case m <> mrest:
              remote_step(repo, m) <> remote_steps(rest, mrest)
        case _:
          remote_steps(rest, ms)

# ---- each package: already published as it is, new, or changed without a new version ----
def package_step(p: Rl.Release, h: P.Hub) -> P.Step:
  match p:
    case Rl.Package{+n, +v, e, _}:
      match h:
        case P.Same{}:
          P.Current{"package " ++ n ++ "@" ++ v}
        case P.Unpublished{}:
          P.Publish{n, v, e}
        case P.Differs{f}:
          P.Blocked{"package " ++ n ++ "@" ++ v, f ++ " changed since it was published; give it a new version"}
    case _:
      P.Blocked{"package", "not a package release"}

def package_steps(ps: List<&2, Rl.Release>, hs: List<&2, P.Hub>) -> List<&2, P.Step>:
  match ps:
    case []:
      []
    case p <> prest:
      match p:
        case Rl.Package{_, _, _, _}:
          match hs:
            case []:
              [P.Blocked{"package observation", "missing Hub snapshot for a declared package"}]
            case h <> hrest:
              package_step(p, h) <> package_steps(prest, hrest)
        case _:
          package_steps(prest, hs)

# ---- each plugin: released as it builds, new, or changed without a new version ----
def plugin_step(g: Rl.Release, t: P.Tag) -> P.Step:
  match g t:
    case Rl.Plugin{+n, ver, _, _, Rl.GitHub{owner, name, _}} P.Tag{repo, tagged, +built, valid, differs}:
      +r = owner ++ "/" ++ name
      +v = PlO.version_show(ver)
      +what = "plugin " ++ n ++ "@" ++ v
      Bool.pick(P.Step, Bool.not(PlO.name_ok(n)), P.Blocked{what, "the name breaks Agent Plugins 1.0's rule: 1 to 64 of a-z, 0-9, . and -, a letter or digit at each end, no -- or .."},
      Bool.pick(P.Step, String.is_empty(built), P.Blocked{what, "does not build"},
        Bool.pick(P.Step, Bool.not(String.eq(built, v)), P.Blocked{what, "builds as version " ++ built},
        Bool.pick(P.Step, Bool.not(valid), P.Blocked{what, "claude plugin validate rejects the build"},
          Bool.pick(P.Step, Bool.not(repo), P.ReleasePlugin{n, v, r, True{}},
            Bool.pick(P.Step, Bool.not(tagged), P.ReleasePlugin{n, v, r, False{}},
              Bool.pick(P.Step, differs, P.Blocked{what, "changed since " ++ n ++ "-v" ++ v ++ " was released; give it a new version"},
                P.Current{what})))))))
    case _ _:
      P.Blocked{"plugin", "not a plugin release"}

def plugin_steps(gs: List<&2, Rl.Release>, ts: List<&2, P.Tag>) -> List<&2, P.Step>:
  match gs:
    case []:
      []
    case g <> grest:
      match g:
        case Rl.Plugin{_, _, _, _, _}:
          match ts:
            case []:
              [P.Blocked{"plugin observation", "missing tag snapshot for a declared plugin"}]
            case t <> trest:
              plugin_step(g, t) <> plugin_steps(grest, trest)
        case _:
          plugin_steps(grest, ts)

# The plan: what a deploy would do, from the releases and what was observed.
def plan(+rs: List<&2, Rl.Release>, o: P.Observed) -> List<&2, P.Step>:
  match o:
    case P.Observed{+fs, +reached, hs, ms, ts}:
      List.append(&2, P.Step, repo_steps(fs, reached), List.append(&2, P.Step, package_steps(rs, hs),
        List.append(&2, P.Step, plugin_steps(rs, ts), remote_steps(rs, ms))))

def blocked(s: P.Step) -> Bool:
  match s:
    case P.Blocked{_, _}:
      True{}
    case _:
      False{}

def any_blocked(ss: List<&2, P.Step>) -> Bool:
  match ss:
    case []:
      False{}
    case s <> rest:
      blocked(s) || any_blocked(rest)

def show(s: P.Step) -> String:
  match s:
    case P.Current{w}:
      "current  " ++ w
    case P.Publish{n, v, _}:
      "publish  " ++ n ++ "@" ++ v
    case P.Push{r}:
      "push     github " ++ r
    case P.ReleasePlugin{+n, +v, r, create}:
      "release  plugin " ++ n ++ "@" ++ v ++ " to marketplace github " ++ r ++ " as tag " ++ n ++ "-v" ++ v ++ Bool.pick(String, create, " (a new repository)", "")
    case P.Launch{l, _, _, _}:
      "launch   " ++ l
    case P.Install{_, t}:
      "install  " ++ t
    case P.BuildNext{f, +tree, d}:
      "build    " ++ f ++ " @ " ++ String.take(tree, 7n) ++ " (Next.js) into " ++ d
    case P.BuildNode{f, +tree, d}:
      "build    " ++ f ++ " @ " ++ String.take(tree, 7n) ++ " (Node) into " ++ d
    case P.Rebuild{h, _, _}:
      "rebuild  nix-darwin " ++ h
    case P.ServePort{p, t, _}:
      "serve    :" ++ U32.show(p) ++ " -> " ++ t
    case P.Change{w, now, want}:
      "change   " ++ w ++ ": " ++ now ++ " -> " ++ want
    case P.Blocked{w, why}:
      "blocked  " ++ w ++ ": " ++ why

def show_all(ss: List<&2, P.Step>) -> String:
  match ss:
    case []:
      ""
    case s <> rest:
      show(s) ++ "\n" ++ show_all(rest)
