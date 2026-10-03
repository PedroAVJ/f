# F's source pins: a mirror or one repository, its artifact and its
# receipt, checked against seven observations (F's deployment/tests/source.bend,
# its imports by module)
import Base
import ../../bend2/std/F/deployment/source/type.bend as T
import ../../bend2/std/F/deployment/source/ops.bend as O

def model() -> T.RepositoryPin: T.RepositoryPin{"model", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", None{}}
def target() -> T.RepositoryPin: T.RepositoryPin{"target", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", Some{"https://example.invalid/target.git"}}
def pin() -> T.ArtifactPin: T.ArtifactPin{"dist/app.js", "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc", "receipts/app.json"}
def model_e() -> T.RepositoryEvidence: T.RepositoryVerified{"model", "/fixture/model", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", None{}, True{}}
def target_e() -> T.RepositoryEvidence: T.RepositoryVerified{"target", "/fixture/target", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", Some{"https://example.invalid/target.git"}, True{}}
def artifact(revision: String) -> T.ArtifactEvidence:
  T.ArtifactVerified{"dist/app.js", "target", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc", T.Receipt{"target", revision, "dist/app.js", "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"}}
def mirror() -> T.Definition: T.Definition{T.Mirror{model(), target()}, [pin()]}
def valid() -> T.Observation: T.Observation{model_e(), target_e(), [artifact("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")]}
def tests() -> Bool:
  O.passed(O.check(mirror(), Some{valid()})) &&
  O.passed(O.check(T.Definition{T.SameRepository{target()}, [pin()]}, Some{T.Observation{target_e(), target_e(), [artifact("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")]} })) &&
  Bool.not(O.passed(O.check(mirror(), None{}))) &&
  Bool.not(O.passed(O.check(mirror(), Some{T.Observation{model_e(), T.RepositoryUnavailable{}, []}}))) &&
  Bool.not(O.passed(O.check(mirror(), Some{T.Observation{model_e(), model_e(), []}}))) &&
  Bool.not(O.passed(O.check(mirror(), Some{T.Observation{model_e(), target_e(), []}}))) &&
  Bool.not(O.passed(O.check(mirror(), Some{T.Observation{model_e(), target_e(), [artifact("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")]}})))
def main() -> IO(Unit):
  Bool.pick(IO(Unit), tests(), IO.print("F source: 7 native binding/provenance checks passed"), IO.die(Unit, 1, "F source binding checks failed"))

#|F source: 7 native binding/provenance checks passed
