# Open Dot

Dot, an assistant app written in F, running on your own Codex or Claude subscription.

- `f.bend`: the UI, `UI = f(state)`.
- `state.bend`: the state.
- `copy.bend`: the text, per language.
- `main.bend`: a preview that prints both screens.

Needs the F fork of Bend checked out next to this repo (`../f`, github.com/PedroAVJ/f).

```sh
bun ../f/bend2/main.ts main.bend
```
