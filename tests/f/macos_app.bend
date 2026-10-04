# A Mac app (MacOS{ui}) on this Mac lowers to a bundle node beside the web
# app's launchd one: its UI module built to dist/mac.macos, bundle
# identifier com.<user>.<repo>.mac; with no web app the deployment has no
# address and takes no port. Its plan, from what was seen of its build and
# of ~/Applications: build it unless dist/ holds the current build, never
# ship a build from other sources, install and open it until ~/Applications
# holds this build, and never replace another app by its name
import V
import ../../bend2/std/F/deployment/domain/architecture/system/deployment/type.bend as D
import ../../bend2/std/F/deployment/domain/architecture/system/deployment/ops.bend as DO
import ../../bend2/std/F/deployment/domain/architecture/system/deployment/bundle/type.bend as Bu
import ../../bend2/std/F/deployment/domain/architecture/system/deployment/bundle/ops.bend as BuO
import ../../bend2/std/F/deployment/domain/architecture/system/plan/type.bend as P
import ../../bend2/std/F/deployment/domain/architecture/system/plan/ops.bend as PO
import ../../bend2/std/F/deployment/domain/architecture/system/deploy/ops.bend as Verbs

def shown_node(n: D.Node) -> String:
  match n:
    case D.Node{_, _, tech, _, _, platform, _, _}:
      match platform:
        case D.Launchd{_}:
          tech ++ "\n"
        case D.Bundle{Bu.MacApp{ui, id, dir}}:
          tech ++ " " ++ ui ++ " -> " ++ dir ++ " as " ++ id ++ "\n"
        case _:
          "?\n"

def shown_nodes(xs: List<&2, D.Node>) -> String:
  match xs:
    case []:
      ""
    case n <> rest:
      shown_node(n) ++ shown_nodes(rest)

def shown(t: D.Topology) -> String:
  match t:
    case D.Topology{a, _, _, ns}:
      "[" ++ a ++ "]\n" ++ shown_nodes(ns)

def here() -> D.Here:
  D.Here{"pedro", "open-dot", "m.ts.net", [], 4600}

def app() -> Bu.MacApp:
  Bu.MacApp{"ui", "com.pedro.open-dot.mac", "dist/mac.macos"}

# Build, ship and install, for one observation.
def plan(+o: P.Bundled) -> String:
  PO.show_all(BuO.build_steps(app(), o)) ++ PO.show_all(BuO.ship_steps(app(), o)) ++ PO.show_all(BuO.install_steps(app(), o))

def main() -> IO(Unit):
  do IO<Unit>:
    IO.write(shown(DO.lower(Mac{Tailscale{9453}, [Web{"ui"}, Application.MacOS{"ui"}]}, here())))
    IO.write(shown(DO.lower(Mac{Tailscale{9453}, [Application.MacOS{"ui"}]}, D.Here{"ana", "shop", "", [], 0})))
    IO.write(PO.show_all(Verbs.unlowered(Mac{Tailscale{9453}, [Application.MacOS{"ui"}]}, D.Here{"ana", "shop", "", [], 0})))
    IO.write(PO.show_all(Verbs.unlowered(Mac{Tailscale{9453}, [Web{"ui"}, Application.MacOS{"ui"}, Web{"admin"}]}, here())))
    IO.write(PO.show_all(Verbs.unlowered(Mac{Tailscale{9453}, [Application.MacOS{"ui"}, Application.MacOS{"admin"}]}, here())))
    IO.write(PO.show_all(Verbs.unlowered(Mac{Tailscale{9453}, []}, here())))
    IO.print("-- not built")
    IO.write(plan(P.Bundled{P.Missing{}, "", "", "", ""}))
    IO.print("-- built, not installed")
    IO.write(plan(P.Bundled{P.Fresh{}, "Dot", "1791234567", "", ""}))
    IO.print("-- built, an older build installed")
    IO.write(plan(P.Bundled{P.Fresh{}, "Dot", "1791234567", "1791230000", ""}))
    IO.print("-- built and installed")
    IO.write(plan(P.Bundled{P.Fresh{}, "Dot", "1791234567", "1791234567", ""}))
    IO.print("-- built from other sources")
    IO.write(plan(P.Bundled{P.Stale{}, "Dot", "1791234567", "1791234567", ""}))
    IO.print("-- another app by its name")
    IO.write(plan(P.Bundled{P.Fresh{}, "Dot", "1791234567", "", "/Applications/Dot.app (com.example.dot)"}))
#|[https://m.ts.net:9453]
#|launchd
#|AppKit ui -> dist/mac.macos as com.pedro.open-dot.mac
#|[]
#|AppKit ui -> dist/mac.macos as com.ana.shop.mac
#|blocked  mac :9453: one app per Tailscale port so far
#|blocked  mac: one Mac app per deployment so far
#|blocked  mac: no app declared
#|-- not built
#|build    ui -> dist/mac.macos (Mac app com.pedro.open-dot.mac)
#|blocked  deploy dist/mac.macos: not built; build first (bend system build)
#|install  com.pedro.open-dot.mac -> ~/Applications, and open it (once built)
#|-- built, not installed
#|current  build ui -> dist/mac.macos
#|install  Dot.app (com.pedro.open-dot.mac, build 1791234567) -> ~/Applications, and open it
#|-- built, an older build installed
#|current  build ui -> dist/mac.macos
#|install  Dot.app (com.pedro.open-dot.mac, build 1791234567) -> ~/Applications, and open it
#|-- built and installed
#|current  build ui -> dist/mac.macos
#|current  app ~/Applications/Dot.app 1791234567
#|-- built from other sources
#|build    ui -> dist/mac.macos (Mac app com.pedro.open-dot.mac)
#|blocked  deploy dist/mac.macos: built from other sources; build first (bend system build)
#|install  Dot.app (com.pedro.open-dot.mac, build 1791234567) -> ~/Applications, and open it
#|-- another app by its name
#|current  build ui -> dist/mac.macos
#|blocked  install Dot.app: /Applications/Dot.app (com.example.dot) is another app by that name; not replacing it
