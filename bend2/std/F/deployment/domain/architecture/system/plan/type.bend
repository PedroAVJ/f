import Base

# What the Bend hub has for one declared package.
type Hub is Data:
  Unpublished{}
  Same{}
  Differs{file: String}

# What the working tree and GitHub say about a declared repository: origin as github.com/<owner>/<name> (else as
# it is), GitHub's visibility for the declared one, and whether the tree is clean and pushed.
type Remote is Data:
  Remote{origin: String, visibility: String, clean: Bool, pushed: Bool}

# What GitHub has for one declared plugin, next to a fresh build of it: whether its marketplace exists,
# whether it is tagged <name>-v<version>, the version the build declares ("" when it did not build),
# whether `claude plugin validate` accepts the build, and whether the build differs from what the tag
# holds.
type Tag is Data:
  Tag{repository: Bool, tagged: Bool, built: String, valid: Bool, differs: Bool}

# What the world looks like now, as far as the releases are concerned: the hub's answer for each package, the
# repository for each code release and the tag for each plugin, in declaration order.
type Observed is Data:
  Observed{files: List<&2, String>, reached: List<&2, String>, hubs: List<&2, Hub>, remotes: List<&2, Remote>, tags: List<&2, Tag>}

# One step of a plan. BuildPage, Publish, Push, ReleasePlugin, Rebuild, ServePort and Launch change the world; Current and Change do not
# (a Change is what a Rebuild would change, shown by a dry run); Blocked stops the deploy.
# Rebuild: write a nix-darwin node's flake and darwin-rebuild switch it. ServePort: serve a tailnet
# HTTPS port from a local target, with the given Tailscale command. Launch: write a launch agent's plist and
# (re)load it in the user's launchd domain. BuildPage: render a UI module's page to its path in dist/.
type Step is Data:
  Current{what: String}
  Publish{name: String, version: String, entry: String}
  Push{repository: String}
  ReleasePlugin{name: String, version: String, marketplace: String, create: Bool}
  Rebuild{host: String, flake: String, mac: String}
  ServePort{https: U32, target: String, tailscale: String}
  Launch{label: String, path: String, plist: String, domain: String}
  BuildPage{ui: String, page: String}
  BuildNext{folder: String, tree: String, dir: String}
  BuildNode{folder: String, tree: String, dir: String}
  Change{what: String, now: String, want: String}
  Blocked{what: String, why: String}

# What one program of a launchd node looks like now: built from the current inputs (the repository's Bend
# files, the generated entry and the fork's commit, as its build recorded them beside it, with the page's
# hash), built from others or since changed, or not built.
type Built is Data:
  Fresh{}
  Stale{}
  Missing{}

# What one launch agent looks like now: its plist on disk ("" when absent), whether the user's launchd domain
# has it loaded, and the process listening on its port ("" for none).
type Running is Data:
  Running{plist: String, loaded: Bool, listener: String}

# What a launchd node (this Mac) looks like now: the home folder, the user's launchd domain (gui/<uid>), the
# repository's folder, each program and agent in declaration order, Tailscale's command, the node's tailnet
# name ("" when Tailscale is down) and `tailscale serve status`, one line each.
type Seen is Data:
  Seen{home: String, domain: String, dir: String, built: List<&2, Built>, running: List<&2, Running>, tailscale: String, name: String, served: List<&2, String>}
