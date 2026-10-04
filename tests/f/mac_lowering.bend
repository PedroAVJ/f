# A Mac deployment lowers to its topology: the tailnet address, the web
# app's page (its UI module's) built to dist/web/index.html, a launch agent
# com.<user>.<repo>.web serving it on 127.0.0.1 (index.html for
# any path), and the HTTPS port served
# from there; the local port is the one Tailscale already serves the port
# from, else the Mac's free one
import V
import ../../bend2/std/F/deployment/domain/architecture/system/deployment/type.bend as D
import ../../bend2/std/F/deployment/domain/architecture/system/deployment/ops.bend as DO
import ../../bend2/std/F/deployment/domain/architecture/system/deployment/launchd/type.bend as L
import ../../bend2/std/F/deployment/domain/architecture/system/deployment/launchd/ops.bend as LO
import ../../bend2/std/F/deployment/domain/architecture/system/deployment/nix_darwin/type.bend as ND

def shown_agent(a: L.Agent) -> String:
  match a:
    case L.Agent{_, label, command, args, _, log, _}:
      label ++ " " ++ command ++ " -c <server> " ++ String.join(List.drop(&2, String, args, 2n), " ") ++ " > " ++ log

def shown_agents(xs: List<&2, L.Agent>) -> String:
  match xs:
    case []:
      ""
    case a <> rest:
      shown_agent(a) ++ "\n" ++ shown_agents(rest)

def shown_program(p: L.Program) -> String:
  match p:
    case L.Program{path, b}:
      match b:
        case L.Page{u}:
          u ++ " -> " ++ path
        case _:
          path

def shown_programs(xs: List<&2, L.Program>) -> String:
  match xs:
    case []:
      ""
    case p <> rest:
      shown_program(p) ++ "\n" ++ shown_programs(rest)

def shown_serves(xs: List<&2, ND.Serve>) -> String:
  match xs:
    case []:
      ""
    case s <> rest:
      LO.target(s) ++ "\n" ++ shown_serves(rest)

def shown_node(n: D.Node) -> String:
  match n:
    case D.Node{_, _, _, _, _, platform, _, _}:
      match platform:
        case D.Launchd{+ld}:
          shown_programs(LO.programs(ld)) ++ shown_agents(LO.agents(ld)) ++ shown_serves(LO.serves(ld))
        case _:
          "?"

def shown_nodes(xs: List<&2, D.Node>) -> String:
  match xs:
    case []:
      ""
    case n <> rest:
      shown_node(n) ++ shown_nodes(rest)

def shown(t: D.Topology) -> String:
  match t:
    case D.Topology{a, _, _, ns}:
      a ++ "\n" ++ shown_nodes(ns)

def mac() -> Deployment:
  Mac{Tailscale{9453}, [Web{"ui"}]}

def served() -> List<&2, String>:
  ["https://m.ts.net:9452 (tailnet only)", "|-- / proxy http://127.0.0.1:4630", "",
   "https://m.ts.net:9453 (tailnet only)", "|-- / proxy http://127.0.0.1:4640"]

def main() -> IO(Unit):
  do IO<Unit>:
    IO.write(shown(DO.lower(mac(), D.Here{"pedro", "open-dot", "m.ts.net", served(), 4600})))
    IO.write(shown(DO.lower(mac(), D.Here{"ana", "shop", "m.ts.net", [], 4600})))
#|https://m.ts.net:9453
#|ui -> dist/web/index.html
#|com.pedro.open-dot.web /usr/bin/python3 -c <server> 4640 dist/web > open-dot-web
#|http://127.0.0.1:4640
#|https://m.ts.net:9453
#|ui -> dist/web/index.html
#|com.ana.shop.web /usr/bin/python3 -c <server> 4600 dist/web > shop-web
#|http://127.0.0.1:4600
