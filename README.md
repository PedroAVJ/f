# Open Dot

Dot's native macOS milestone, written in F using the adjacent Bend2 fork
(`../f`, github.com/PedroAVJ/f). Bend owns application state, layout, tokens,
and interaction. AppKit supplies the window and text input; CoreGraphics and
CoreText paint the existing conversation components. No browser is required.

The app uses the accepted dark conversation UI: glass header controls,
chat bubbles and the pill composer. The earlier standalone connection and
stacked-input screens have been removed. `ui.bend` owns state;
`components/conversation.bend` composes the fork's Header, Conversation,
Bubble, Composer, and sheet components.

This completes the original native-app milestone. The original workflow
deferred the Codex/Claude subscription transport: sends append your message
and the placeholder reply `…`. The menu selects a provider; it does not
authenticate. Calls, attachments and dictation show their availability
notice. Conversation state is local to the current run, and Send clears the
controlled draft. No credentials or private artwork are bundled.
Very long messages use a preview in the compact thread; the menu's
"Ver conversación" opens the complete, scrollable conversation.

Requires Bun and Xcode Command Line Tools. Build, install and launch:

```sh
./script/build_and_run.sh --verify
```

The Codex Run action uses that script. `--debug` starts LLDB and `--logs`
streams the app's logs. V is the build/deployment source of truth:

```sh
bun ../f/bend2/main.ts system diff
bun ../f/bend2/main.ts system build
bun ../f/bend2/main.ts system deploy
```

`system.bend` declares only `Application.MacOS{"ui"}`. Build produces
`dist/mac.macos/Dot.app`; deploy verifies the signed bundle and its source
stamp, installs it as `~/Applications/Dot.app`, and opens it. No web target
or Tailscale service is launched by this declaration. Releases remain an
explicit separate action.

Run the state/geometry regression with:

```sh
bun ../f/bend2/main.ts tests state
```
