import Base
import ./system/type.bend as S
import ./system/container/type.bend as Ct
import ./environment/type.bend as En
import ./system/deployment/type.bend as D

# An architecture: a software system (its key, name and description, then what it releases and deploys), the
# containers it is made of, the nodes they run on, in its environment.
type Architecture is Data:
  Architecture{key: String, name: String, description: String, system: S.System, containers: List<&2, Ct.Container>, nodes: List<&2, D.Node>, environment: En.Environment}

# What each key in an architecture is, for drawing it.
type Level is Data:
  PersonLevel{}
  SystemLevel{}
  ContainerLevel{}
  ComponentLevel{}
  ExternalLevel{}

type Element is Data:
  Element{name: String, description: String, technology: String, level: Level}
