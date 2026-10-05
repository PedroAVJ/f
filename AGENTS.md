# AGENTS

Bend is a dependently typed, affine language that checks in one linear
bidirectional pass and runs massively parallel on CPU threads and GPUs.
bend2/bend.ts is the language (parser, theory, checker) and is human-written:
do not edit it. bend2/comp.ts is the one compiler: the C runtime (host and
device from one source), the C emitter and the JS emitter; base.bend is the
prelude; main.ts is the CLI (`bend <words...>` runs a main, nothing else)
and tool.ts the internal tool the gates and V run. Every test is a Bend file
that ends in the `#|` lines its run must print, and the gates run on the mini
cluster.

    bend2/bend.ts       the language: parser, theory, checker
    bend2/comp.ts       the compiler and runtimes (C, Metal, CUDA, JS, Wasm,
                        browser WGSL kernel lowering)
    bend2/main.ts       the CLI, bare: `bend a b` runs ./a/b.bend (else ./a.bend),
                        the rest IO.args; no commands, no flags; imported, the
                        .bend loader for bun and node
    bend2/tool.ts       the internal tool (not the user's CLI): -o <out> (binary,
                        C, JS, .mjs, .web, .bendtt), --check-only, --verdict,
                        --checkup, --publish, link, login, base; V's build,
                        the gates and gen_pins.ts run it
    bend2/safe.ts       tool.ts --verdict and -o <out>.bendtt: the elaborator
                        from a checked book to BendTT text
    bend2/bendtt.lean   BendTT: the kernel, its claims (no checked def has type
                        Empty, live code halts) and their proofs; --verdict
                        builds its CLI once, with Lean v4.34.0
    bend2/base.bend     the base library
    bend2/effs/         IO effect sources per backend; related effects may share
    bend2/std/F/        copied F implementation and internal browser support;
                        from near-bend's packages/function, MIT, each
                        tree's LICENSE beside it (THIRD_PARTY_NOTICES.md).
                        Explicit UI and V imports select bare public bindings.
    bend2/pack/         package.json, tsconfig.json, bun.lock
    bend2/docs/         the papers' Typst sources, the film, gen_pins.ts (the
                        record pins on this Mac), gen_charts.ts (the landing
                        page's and the film's numbers), gen_gifs.ts (the images)
    bench/runtime/      one dir per bench: main.bend and its twins (C, TS, Lean)
    bench/checker/      one dir per bench: main.bend and its rivals
    bench/*/_pin_/      the pins, one file per hardware: apple_m4 the gate's,
                        apple_m4_max the record
    tests/<ns>/         the tests by namespace, with their foreign .c/.js
    gates/test.ts       every test, one shard per live mini, PASS: n / n
    gates/perf.ts       the benches on 48 minis against the pins (--pin writes
                        the medians of three runs)
    gates/repo.ts       the allow list of files and the permanent ttok caps
                        (bend.ts 48k, main.ts 16k, bendtt.lean
                        64k, README 4k, GUIDE 8k); only Taelin changes them
    gates/ping.ts       the installer, the compiled bend, its daily version
                        check and a release, on a localhost hub
    gates/safe.ts       bend2's verdict against BendTT's, per file, on the
                        minis: `tests` or `hub` (a BendHub store, $SAFE_HUB)
    gates/no_base.txt   the tests and benches with their own Nat, Empty...:
                        the gates (and gen_pins.ts) run them with
                        $BEND_NO_BASE, an internal switch; users get Base
    gates/_run.ts       the four gates with --gate
    apps/open-dot/      canonical Open Dot app and shared conversation shell;
                        versioned independently from Bend (its own AGENTS.md)
    demos/              one dir per demo
    guide/              GUIDE.md, and the extras EFFECTS.md, SHADERS.md, F.md,
                        WEB.md
    paper/              BendTT.pdf, BendRT.pdf
    media/              the film and the charts
    .github/            ISSUE_TEMPLATE/bug.yml, the bug report form, and
                        config.yml, which points questions at Discord
    ../bend-lang.com    the site repo (bendlang/bend-lang.com), a sibling
                        checkout: the sites, install.sh, the hub, release.ts
                        (the executables per platform) and the droplet ops;
                        gates/ping.ts and gen_charts.ts read it there (or at
                        $SITE_REPO)
