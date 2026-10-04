# A system's releases, one per thing released, through V's bare names: each
# code release is checked against its GitHub repository (origin, visibility
# from its source, clean, pushed) and each package against the hub, in order
import V

def releases() -> List<&2, Release>:
  [Code{GitHub{"o", "x", OpenSource{"MIT"}}}, Package{"near-function", "0.1.0.0", "f.bend", []},
    Code{GitHub{"o", "y", Proprietary{}}}, Code{GitHub{"o", "z", Proprietary{}}}, Code{GitHub{"o", "w", OpenSource{"MIT"}}}]

def remote(+slug: String, +vis: String, pushed: Bool) -> RepositoryStatus:
  RepositoryStatus{"github.com/" ++ slug, vis, True{}, pushed}

def main() -> IO(Unit):
  IO.write(show_all(plan(releases(), Observed{[], [], [PackageStatus.Same{}],
    [remote("o/x", "public", False{}), remote("o/x", "private", True{}), remote("o/z", "public", True{})], []})))
#|current  package near-function@0.1.0.0
#|push     github o/x
#|blocked  github o/y: origin is github.com/o/x, declared github.com/o/y
#|blocked  github o/z: GitHub says public, declared private
#|blocked  repository observation: missing GitHub snapshot for a declared repository
