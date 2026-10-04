import Base
import ./system/type.bend as S
import ./system/container/type.bend as Ct
import ./environment/type.bend as En

# An architecture: a software system, the containers it is made of, in its environment.
type Architecture is Data:
  Architecture{system: S.System, containers: List<&2, Ct.Container>, environment: En.Environment}

# What each key in an architecture is, for drawing it.
type Level is Data:
  PersonLevel{}
  SystemLevel{}
  ContainerLevel{}
  ComponentLevel{}
  ExternalLevel{}

type Element is Data:
  Element{name: String, description: String, technology: String, level: Level}
