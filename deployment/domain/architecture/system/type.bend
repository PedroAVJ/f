import Base
import ./deployment/type.bend as D
import ./release/type.bend as Rl

# A software system: what it releases, and where it runs.
type System is Data:
  System{key: String, name: String, description: String, releases: List<&2, Rl.Release>, deployments: List<&2, D.Deployment>}
