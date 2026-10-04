import Base
import ./plugin/type.bend as Pl

# Whether a repository's code is open, under the license it names (its SPDX identifier), or proprietary.
type Source is Data:
  OpenSource{license: String}
  Proprietary{}

# A repository on GitHub: github.com/<owner>/<name>, public when its source is open, private when it is not.
type Repository is Data:
  GitHub{owner: String, name: String, source: Source}

# One thing the system releases.
# Code: the repository it lives in, pushed.
# Package: a package on the Bend hub: its name, version (four numbers), entry file and the components it ships.
# Plugin: a plugin for Claude Code and Codex: built by its entry's `plugin <dir>` command at its version
# (semver), shipping its components, and released into a marketplace: a GitHub repository holding each plugin
# under plugins/<name>, listed for Claude Code in .claude-plugin/marketplace.json and for Codex in
# .agents/plugins/marketplace.json, and tagged <name>-v<version>. The marketplace is named after its
# repository.
type Release is Data:
  Code{repository: Repository}
  Package{name: String, version: String, entry: String, components: List<&2, String>}
  Plugin{name: String, version: Pl.Version, entry: String, components: List<&2, String>, marketplace: Repository}
