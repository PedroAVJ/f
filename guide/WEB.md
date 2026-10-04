# Bend web builds

```sh
bun bend2/tool.ts application.bend -o application.web
```

The build emits sequential and shared-memory Wasm, compiler-generated WGSL for
supported kernels, and a generic JavaScript loader and browser adapter.
Application calculations, F layout, token resolution and sprite sampling run
in generated Bend code. JavaScript delivers browser effects and paints the
values it receives.

`bend2/tool.ts` is the fork's internal tool (V's `build` runs it); the `bend`
command only runs programs. Building requires Emscripten (`emcc`, or `BEND_EMCC`). Serve the output over
HTTP on localhost, or HTTPS elsewhere. Its manifest lists generated files;
rebuilds preserve caller-owned assets. The default uses one Wasm worker.
`?workers=4` selects up to eight when COOP/COEP headers enable shared memory;
otherwise the loader selects the sequential build.

## Presentation

The internal scene bridge projects Primitives/Kit trees into HTML/CSS and Canvas.
It supports Text, approved Path drawings, Rounded geometry and full radii;
token fills/strokes, gradients, photos and supplied atlas frames; and
Blur/Shadow with a CSS Glass baseline. Resource URLs and SVG/text attributes
are escaped. Tree dimensions come from Bend's measurement, and draw order
comes from its placed boxes. Canvas receives the measured frame dimensions;
frames above 16,384 pixels on either side or 16,777,216 total pixels are rejected
instead of being clipped. Stroke widths are non-negative decimal strings,
validated before DOM insertion and Canvas painting.

Declared button regions preserve enabled/disabled state. A textbox region is
an input holding the field's whole value over its drawn text; each edit,
focus and blur sends a field event named after the textbox, and each edit is
kept in localStorage under that name, given back as an edit when the textbox
appears empty. HTML buttons use
F's focus order and native keyboard activation; Canvas hit tests send the
same region name to Bend. The retained application tree and state stay in
Wasm; Canvas packets are transient paint values. Replacing HTML and repainting
Canvas keeps the renderer attached to the current root.

UI and V are explicit preludes. The bridge remains internal backend support;
there is no additional Browser prelude. The semantic UI renderer emits
escaped HTML forms, field-edit events and declared buttons. Photo fields select a
file, decode/resize it through browser APIs and upload it to the application's
endpoint. JSON POST replies return to Bend; application state and validation remain
Bend data/functions. The browser adapter bounds requests and responses and releases
listeners and pending effects on stop. UI records use HTML; positioned
Primitives/Kit trees support both HTML and Canvas.

Glass refraction has no new implementation. The positioned-tree renderer keeps its
existing Light-scheme default. Use the application's CSS for semantic UI
presentation.

## CPU and GPU

The initial runtime has 128 MiB linear memory, a 32 MiB corpus and a checked
2 MiB work stack per participating thread. Host messages are bounded to
1 MiB. Unsupported reached foreign effects are rejected during the web build.
Rendering, field/click events, bounded HTTP/upload and supported GPU dispatch use the generic
host adapter. Cancellation and stopping release pending work and listeners.

The existing kernel backend lowers closed `U32 -> U32` functions into WGSL.
It preserves wrapping arithmetic, zero-division/modulus behavior and literal
shifts. Supported existing `!` calls dispatch through the private WebGPU bridge;
ordinary calls and unsupported kernels retain Wasm execution. Marked tasks
evaluated entirely inside CPU workers remain CPU computations.
Rejected kernels and unavailable, failed, lost or cancelled GPU dispatches
retain the same Bend computation for Wasm fallback. No application arithmetic
runs in JavaScript. Recursion, captured state, floating point and arbitrary
ADTs remain CPU computations; no placement or profiling policy is added.

V's existing plan/check records compile and run in Wasm. They do not execute
deployment actions. UI exports the existing data and pure session/stream reducers. Applications
perform authorized persistence through their IO adapters; no extra channel API is
introduced.
