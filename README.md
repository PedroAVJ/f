# Open Dot

Dot, an assistant app written in F, running on your own Codex or Claude subscription.

- `system.bend`: what's released and deployed where (V): the code on GitHub (MIT), and on this Mac the web app, on Tailscale port 9453.
- `ui.bend`: `f(state) -> UI`, picks the screen.
- `state.bend`, `update.bend`, `copy.bend`: the state and where it starts, what each input does to it, and the text per language.
- `screens/`, `components/`: what `f` is made of.

Needs the F fork of Bend checked out next to this repo (`../f`, github.com/PedroAVJ/f).

```sh
bun ../f/bend2/main.ts system diff      # compare system.bend with the world, print the steps; change nothing (also with no verb)
bun ../f/bend2/main.ts system build     # build every app into dist/
bun ../f/bend2/main.ts system release   # push the code
bun ../f/bend2/main.ts system deploy    # ship what dist/ holds: launch and serve (blocked until built from the current sources)
```

`build` makes the web app (git-ignored `dist/web`, needs Emscripten): it renders `ui.bend`'s `f` from
`state.bend`'s `initial()`, and each click or keystroke goes through `update.bend`'s `update`;
`deploy` serves it from the launch agent com.pedro.open-dot.web on 127.0.0.1:4640 (V derives the label and the port), and Tailscale serves
that at https://pedros-mac-mini.tail90fb4c.ts.net:9453 (tailnet only).
