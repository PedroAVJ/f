# Deployment source provenance

The pure Bend deployment sources derive from [PedroAVJ/n](https://github.com/PedroAVJ/n) at commit `1e5e64d`. The upstream MIT copyright and permission notice are retained verbatim in `LICENSE`.

The selected closure contains architecture definitions and proofs, system/release/deployment operations, platform definitions, supporting graph structures and pure planning operations. Application-specific architecture values, editor code and effect drivers are excluded. Plugin operations are limited to version/name validation; manifest serializers and their external JSON dependency are omitted. Planning was changed to block missing package/plugin observations. URL percent decoding uses a local Base-only implementation that rejects invalid UTF-8 and malformed escapes.

The JavaScript planner, CLI, reusable assistant template and synthetic JSON examples are separate implementations. JavaScript planning is not generated from the Bend planner and does not claim full parity. All deployment operations exposed by this release are dry-run only.
