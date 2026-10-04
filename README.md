# Open Dot

Dot, an assistant app written in F, running on your own Codex or Claude subscription.

- `system.bend`: the entry point: what's deployed where, and the release checks (V).
- `ui.bend`: `f(state) -> UI`, picks the screen.
- `state.bend`, `copy.bend`: the state, and the text per language.
- `screens/`, `components/`: what `f` is made of.
- `apps/`: one file per platform (`web.bend`).

Needs the F fork of Bend checked out next to this repo (`../f`, github.com/PedroAVJ/f).
