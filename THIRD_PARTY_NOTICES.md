# Third-party notices

This repository is licensed under Apache-2.0 (`LICENSE`). F, the library it
pins as the separate [f-platform](https://github.com/PedroAVJ/f-platform)
submodule in `bend2/std/F/`, is MIT licensed: each of F's trees keeps its full
copyright and permission notice in the `LICENSE` beside it, and a copy of a
module carries the `LICENSE` of its directory, or of the nearest directory
above it that has one.

- `bend2/std/F/LICENSE` (MIT, Pedro Antonio Villanueva Juarez) covers
  `ui/` and `dot/`.
- `bend2/std/F/deployment/` derives from
  [PedroAVJ/n](https://github.com/PedroAVJ/n) at `1e5e64d`; its MIT license
  is retained in `deployment/LICENSE`, and `deployment/PROVENANCE.md` tells
  the adaptation.
- `bend2/std/F/ai/LICENSE` (MIT, Gabriel Gouvea, with native AI code by
  Near contributors) covers `ai/`, but for `ai/ai-sdk.bend`, whose license
  (MIT, Near contributors) is `ai/AI_SDK_LICENSE`.
- `ai/wire_json.bend` adapts a standalone MIT JSON parser, as
  `ai/PROVENANCE.md` tells. Its complete notice is retained in
  `ai/WIRE_JSON_LICENSE`, which must accompany any distribution that
  contains the parser.
- `bend2/std/F/ai/native-host/LICENSE` (MIT, Pedro Antonio Villanueva
  Juarez) covers `host.bend` and its effect sources `effects.js`,
  `bytes.js` and `multipart.js`.
- `tests/f/source.bend` and `tests/f/planner.bend` adapt F's deployment
  tests (`bend2/std/F/deployment/LICENSE`).

F's modules were copied from near-bend's `packages/function` and grouped:
its root modules are `ui/`; `stdlib/ai/bend/` and `stdlib/ai/ai-sdk.bend`
are `ai/`, whose `AI_SDK_LICENSE` is `stdlib/ai/LICENSE`; `stdlib/dot/bend/`
is `dot/`; `deployment/bend/` is `deployment/`.
Provider READMEs, additional tests and JS hosts beyond the native-host sources
listed above remain in near-bend. The AI README cites the official provider
sources recorded in `ai/PROVENANCE.md`. No rights
in private application assets or customer material are granted; those
materials are not part of F.
