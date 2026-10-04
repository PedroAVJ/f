# A file named system.bend sees V with no import (and Base, as every file):
# its bindings are the canonical types, and check and deploy are there.
import ../../bend2/std/F/deployment/domain/architecture/system/release/type.bend as R

def release_identity(r: Release) -> R.Release: r
def main() -> IO(Unit):
  IO.print(show_all(plan(release_identity(Release{Repository{"x", True{}}, [], []}),
    Observed{[], [], [], RepositoryStatus{"github.com/o/x", "public", True{}, True{}}, []})))
#|current  github x
