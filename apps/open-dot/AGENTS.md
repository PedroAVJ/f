# Open Dot

This is the canonical Open Dot application package in F. The shared conversation
UI, native/web clients and reusable personal-agent adapters belong here. Keep
Bend as the application core and native/browser adapters limited to platform IO.
Do not edit `bend2/bend.ts` to make application changes compile.

Build from this directory. The compiler lives at `../../bend2`; native release
snapshots must preserve `f/apps/open-dot` beside `f/bend2`. `package.json` owns
Dot's version. Release tags start with `dot-v`; they do not version the compiler.
Keep the app's MIT license, bundle identifiers, input persistence keys, pending
request IDs and on-disk session formats unchanged during source moves.

Sabor a Cielo is a separate deployable backend/plugin: inventory rules,
permissions, access-link authentication and data remain in its own repository.
It imports this same Dot shell. TradeInCode stays separate. One app listing
multiple dots is the product direction, not permission to invent or ship a new
selector while migrating source ownership.

Do not replace an active runtime checkout, restart a live worker/front, rewrite
LaunchAgents, move personal state, install a phone build or deploy Sabor just to
apply source changes. Those are separate release actions. In particular, keep
`~/Library/Application Support/OpenDot` and its front/worker state distinct.
The retained old Open Dot checkout may still serve the running services; it is
not the canonical development source and must not receive independent features.

Read README.md for build/test commands and runtime migration boundaries. Use
synthetic fixtures for tests and verify the actual shared UI when changing it.
