# Open Dot

Dot is an installable phone app backed by the Codex harness on your Mac mini.
The phone UI is compiled from Bend using [PedroAVJ/f](https://github.com/PedroAVJ/f).
It keeps the existing dark conversation components, glass header and pill composer.
Bend owns the UI state, layout, JSON decoding and commands. The browser supplies
input, HTTPS requests and rendering; the Mac runs the authenticated official
Codex app-server with persistent threads.

Open the private Tailscale address in Safari, then choose Share → Add to Home
Screen → Open as Web App. Tailscale must be connected on the phone. This is a
Safari home-screen app; it does not require TestFlight or an Apple submission.
The Mac mini must stay on and connected. Conversations are saved on the Mac;
an accepted turn continues when the phone app closes. The menu opens previous
threads, creates a new conversation, shows full history and stops a running turn.

Install Bun, Tailscale and the Codex CLI on the Mac, sign into Codex,
and keep the fork beside this repository at `../f`. Build and deploy with the fork:

```sh
cd harness && bun install --frozen-lockfile && cd ..
bun ../f/bend2/main.ts system build
bun ../f/bend2/main.ts system deploy
```

`system.bend` runs the mobile build and deployment adapters through the fork's
Process effect. Build compiles `mobile.bend` to JavaScript with the fork and
packages `dist/mobile`. Its worker adapter supplies the browser host effects.
Deploy installs `com.pedroavj.opendot.harness` as a user LaunchAgent and exposes
loopback port 19453 through Tailscale HTTPS port 9453. It prints the phone URL.
Only the configured Tailscale owner can use the remote service. Provider
credentials stay with Codex on the Mac; they are never sent to the phone.
Session files live in `~/Library/Application Support/OpenDot` and logs in
`~/Library/Logs/OpenDot`.

Codex uses the available default model from its model catalog, workspace-write sandbox and automatic
approval review. Interactive requests this client cannot display are declined
and reported in the conversation menu. Calls, files and dictation are not
connected yet. Claude is not connected in this mobile version.

Run the client and harness checks:

```sh
bun ../f/bend2/main.ts tests mobile
cd harness && bun run typecheck && bun test
```

The small browser adapter adds viewport/refresh events to the fork's generated
shell and keeps draft storage in sync with Bend's rendered input. It does not
implement a second UI or alter the fork's source files.

## Earlier macOS milestone

The previous native macOS app is retained under `macos_system.bend`; the mobile
deployment is now the default. Its release script remains a separate manual action.

Dot's native macOS milestone was written in F using the adjacent Bend2 fork
(`../f`, github.com/PedroAVJ/f). Bend owns application state, layout, tokens,
and interaction. AppKit supplies the window and text input; CoreGraphics and
CoreText paint the existing conversation components. No browser is required.

The app uses the accepted dark conversation UI: glass header controls,
chat bubbles and the pill composer. It opens in a 1000 × 760 desktop window
and redraws the layout when resized, with a centered conversation column,
a compact header and centered dialogs. The minimum content size is 640 × 560.
The earlier standalone connection and
stacked-input screens have been removed. `ui.bend` owns state;
`components/conversation.bend` composes the fork's Header, Conversation,
Bubble, Composer, and sheet components.

The original workflow
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

`--debug` starts LLDB and `--logs` streams the app's logs. The old V declaration
is available explicitly:

```sh
bun ../f/bend2/main.ts macos_system diff
bun ../f/bend2/main.ts macos_system build
bun ../f/bend2/main.ts macos_system deploy
```

`macos_system.bend` declares only `Application.MacOS{"ui"}`. Build produces
`dist/mac.macos/Dot.app`; deploy verifies the signed bundle and its source
stamp, installs it as `~/Applications/Dot.app`, and opens it. No web target
or Tailscale service is launched by this declaration. Releases remain an
explicit separate action.

GitHub downloads need a Developer ID Application certificate and Apple
notarization. The local build's Apple Development signature is for development
and Gatekeeper blocks it when downloaded. The release script signs with a
secure timestamp and hardened runtime, submits to Apple, staples the ticket,
and requires Gatekeeper acceptance before packaging or publishing:

```sh
./script/release_macos.sh --tag v1.0.0-preview.2 \
  --identity 'Developer ID Application: YOUR NAME (TEAM_ID)' \
  --notary-profile YOUR_KEYCHAIN_PROFILE --publish
```

The script builds committed snapshots of both repositories; local fork edits
are excluded. Open Dot must have a clean checkout and both commits must match
their remote main branches when publishing. Notarization credentials stay in Keychain;
configure a profile with `xcrun notarytool store-credentials`. Without
`--publish`, the script saves the verified ZIP, checksum and Apple receipts
under `dist/`.

Use `--keychain /absolute/path/to/signing.keychain-db` when the signing
identity is in a separate, unlocked build keychain. The script temporarily
includes it in the signing search list and restores the original list after
signing, including on failure. The notarization profile stays in the default
Keychain.

Run the state/geometry regression, including draft retention and control
bounds at narrow and wide window sizes, with:

```sh
bun ../f/bend2/main.ts tests state
```
