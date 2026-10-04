# Open Dot

Dot, an assistant app written in F, running on your own Codex or Claude subscription.

- `system.bend`: what's released and deployed where (V): the code on GitHub (MIT), and this Mac, a launchd agent serving the web build, on Tailscale.
- `ui.bend`: `f(state) -> UI`, picks the screen.
- `state.bend`, `copy.bend`: the state, and the text per language.
- `screens/`, `components/`: what `f` is made of.
- `apps/`: one file per platform (`web.bend`).

Needs the F fork of Bend checked out next to this repo (`../f`, github.com/PedroAVJ/f).

```sh
bun ../f/bend2/main.ts system check     # observe, then print the plan; change nothing (exit 1 if blocked)
bun ../f/bend2/main.ts system build     # build every artifact
bun ../f/bend2/main.ts system release   # build, then push the code
bun ../f/bend2/main.ts system deploy    # build, then launch and serve
bun ../f/bend2/main.ts system ship      # build, release, deploy
```

`deploy` serves `apps/web.bend`'s page (`dist/web/index.html`, git-ignored) on 127.0.0.1:4640, and
Tailscale serves that at https://pedros-mac-mini.tail90fb4c.ts.net:9453 (tailnet only).
