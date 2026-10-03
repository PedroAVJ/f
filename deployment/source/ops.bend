import Base
import ./type.bend as T

def implementation(b: T.Binding) -> T.RepositoryPin:
  match b:
    case T.SameRepository{p}: p
    case T.Mirror{_, p}: p

def model(b: T.Binding) -> T.RepositoryPin:
  match b:
    case T.SameRepository{p}: p
    case T.Mirror{p, _}: p

def origin_matches(wanted: Maybe<&2, String>, actual: Maybe<&2, String>) -> Bool:
  match wanted actual:
    case None{} _: True{}
    case Some{a} Some{b}: String.eq(a, b)
    case _ _: False{}

def repository_matches(p: T.RepositoryPin, e: T.RepositoryEvidence) -> Bool:
  match p e:
    case T.RepositoryPin{a, revision, origin} T.RepositoryVerified{b, _, observed_revision, observed_origin, clean}:
      String.eq(a, b) && String.eq(revision, observed_revision) && origin_matches(origin, observed_origin) && clean
    case _ _: False{}

def binding_matches(b: T.Binding, model_e: T.RepositoryEvidence, implementation_e: T.RepositoryEvidence) -> Bool:
  match b model_e implementation_e:
    case T.SameRepository{_} T.RepositoryVerified{_, a, _, _, _} T.RepositoryVerified{_, c, _, _, _}: String.eq(a, c)
    case T.Mirror{T.RepositoryPin{a, _, _}, T.RepositoryPin{c, _, _}} T.RepositoryVerified{_, x, _, _, _} T.RepositoryVerified{_, y, _, _, _}: Bool.not(String.eq(a, c)) && Bool.not(String.eq(x, y))
    case _ _ _: False{}

def receipt_matches(p: T.RepositoryPin, a: T.ArtifactPin, r: T.BuildReceipt) -> Bool:
  match p a r:
    case T.RepositoryPin{id, revision, _} T.ArtifactPin{path, hash, _} T.Receipt{receipt_id, receipt_revision, receipt_path, receipt_hash}:
      String.eq(id, receipt_id) && String.eq(revision, receipt_revision) && String.eq(path, receipt_path) && String.eq(hash, receipt_hash)
    case _ _ _: False{}

def artifact_matches(+p: T.RepositoryPin, +pin: T.ArtifactPin, e: T.ArtifactEvidence) -> Bool:
  match p pin e:
    case T.RepositoryPin{id, revision, _} T.ArtifactPin{path, hash, receipt_file} T.ArtifactVerified{observed_path, observed_id, observed_revision, observed_hash, receipt}:
      String.eq(path, observed_path) && String.eq(id, observed_id) && String.eq(revision, observed_revision) && String.eq(hash, observed_hash) && receipt_matches(p, pin, receipt)
    case _ _ _: False{}

def artifacts_match(+p: T.RepositoryPin, pins: List<&2, T.ArtifactPin>, evidence: List<&2, T.ArtifactEvidence>) -> Bool:
  match pins:
    case []: List.is_empty(&2, T.ArtifactEvidence, evidence)
    case a <> rest:
      match evidence:
        case []: False{}
        case b <> more: artifact_matches(p, a, b) && artifacts_match(p, rest, more)

def check_observed(+d: T.Definition, o: T.Observation) -> T.Check:
  match d o:
    case T.Definition{+b, +pins} T.Observation{+m, +i, artifacts}:
      Bool.pick(T.Check, repository_matches(model(b), m),
        Bool.pick(T.Check, repository_matches(implementation(b), i),
          Bool.pick(T.Check, binding_matches(b, m, i),
            Bool.pick(T.Check, Bool.not(List.is_empty(&2, T.ArtifactPin, pins)) && artifacts_match(implementation(b), pins, artifacts), T.Verified{}, T.WrongArtifact{}), T.WrongBinding{}), T.WrongImplementation{}), T.WrongModel{})

def check(d: T.Definition, observation: Maybe<&2, T.Observation>) -> T.Check:
  match observation:
    case None{}: T.Unverified{}
    case Some{o}: check_observed(d, o)

def passed(c: T.Check) -> Bool:
  match c:
    case T.Verified{}: True{}
    case _: False{}
