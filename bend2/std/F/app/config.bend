import Base

type Dependency is Data:
  Dependency{name: String, repository: String, path: String, revision: String, version: String}

type Blob is Data:
  Chunk{text: String}
  Join{left: Blob, right: Blob}

type Asset is Data:
  Asset{name: String, mime: String, base64: Blob}

type Connection is Data:
  Connection{id: String, name: String, subtitle: String, origin: String}

type Config is Data:
  Config{name: String, bundle: String, version: String, minimum_os: String, origin: String, submit_label: String, camera_reason: String, microphone_reason: String, speech_reason: String, dependencies: List<&2, Dependency>, assets: List<&2, Asset>, connections: List<&2, Connection>}
