import Base

# F can describe an implementation in this repository or mirror a foreign codebase.
# Pins identify exact source revisions; they do not prove semantic equivalence.
type RepositoryPin is Data:
  RepositoryPin{id: String, revision: String, origin: Maybe<&2, String>}
type Binding is Data:
  SameRepository{repository: RepositoryPin}
  Mirror{model: RepositoryPin, implementation: RepositoryPin}
type ArtifactPin is Data:
  ArtifactPin{path: String, sha256: String, receipt: String}
type Definition is Data:
  Definition{binding: Binding, artifacts: List<&2, ArtifactPin>}
type RepositoryEvidence is Data:
  RepositoryVerified{id: String, root: String, revision: String, origin: Maybe<&2, String>, clean: Bool}
  RepositoryUnavailable{}
type BuildReceipt is Data:
  Receipt{repository_id: String, revision: String, artifact_path: String, sha256: String}
  ReceiptUnavailable{}
type ArtifactEvidence is Data:
  ArtifactVerified{path: String, repository_id: String, revision: String, sha256: String, receipt: BuildReceipt}
  ArtifactUnavailable{}
type Observation is Data:
  Observation{model: RepositoryEvidence, implementation: RepositoryEvidence, artifacts: List<&2, ArtifactEvidence>}
type Check is Data:
  Verified{}
  Unverified{}
  WrongModel{}
  WrongImplementation{}
  WrongBinding{}
  WrongArtifact{}
