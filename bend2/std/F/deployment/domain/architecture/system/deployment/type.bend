import Base
import ./host/type.bend as H
import ./nix_darwin/type.bend as ND
import ./azure/type.bend as Az
import ./launchd/type.bend as Ld

# A device is someone's own (a phone, a laptop); a server runs the system for others.
type Role is Data:
  Device{}
  Server{}

# What configures a node: nothing V manages, nix-darwin, an Azure subscription, or only the launch agents and
# Tailscale serves V declares on a Mac something else configures.
type Platform is Data:
  Unmanaged{}
  Darwin{config: ND.NixDarwin}
  AzureCloud{config: Az.Azure}
  Launchd{config: Ld.Launchd}

# Where containers run: a machine, a runtime inside it, nested as deep as it is. Instances are container keys.
type Node is Data:
  Node{key: String, name: String, technology: String, role: Role, host: H.Host, platform: Platform, children: List<&2, Node>, instances: List<&2, String>}

# What a deploy breaks, compared with what was deployed before.
type Break is Data:
  AddressChanged{}
  StoreRemoved{name: String}

# Where the system runs, lowered: the address it is reached at, the data stores that must survive a deploy,
# the breaks accepted for the next deploy, and the nodes.
type Topology is Data:
  Topology{address: String, stores: List<&2, String>, accepted: List<&2, Break>, nodes: List<&2, Node>}

# How a Mac's apps are reached: at an HTTPS port Tailscale serves to the tailnet.
type Exposure is Data:
  Tailscale{port: U32}

# One app V builds and runs: a web app, a UI module's s, update and f (ui, its path without ".bend"),
# built to dist/web with its first screen in index.html.
type Application is Data:
  Web{ui: String}

# Where the system runs, as intent: on this Mac, these apps, reached this way. V lowers it to a Topology.
type Deployment is Data:
  Mac{exposure: Exposure, apps: List<&2, Application>}

# What lowering a Mac deployment reads from the Mac: the owner's short name for launchd labels (the first
# word of the account's full name, lowercased), the repository's folder name, the tailnet name ("" when
# Tailscale is down), `tailscale serve status` one line each, and a local port nothing listens on or is
# served from (0 when there is none).
type Here is Data:
  Here{user: String, repo: String, name: String, served: List<&2, String>, free: U32}
