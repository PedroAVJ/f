# Open Dot

Dot is a native iPhone app backed by the harness on your Mac mini.
The app is compiled from Bend using [PedroAVJ/f](https://github.com/PedroAVJ/f).
It keeps the existing dark conversation components, glass header and pill composer.
Bend owns UI state, layout, JSON decoding and commands. UIKit supplies native
text input and HTTPS requests; the fork's CoreGraphics painter draws the UI.
The Mac connects to the authenticated Codex app-server and Claude Code.
Dot keeps one ongoing conversation; the header uses the original Near avatar.

The phone connects to the private Tailscale harness. Tailscale must be connected,
and the Mac mini must stay on. Your ongoing conversation is saved on the Mac; an accepted turn continues when
the app closes. The menu searches the conversation and stops a running turn.
Search opens the matching message in place.

Keep the fork beside this repository at `../f`. The Mac needs Bun, Tailscale,
the Codex CLI, Claude Code and Xcode with iOS SDKs. Sign into both providers, then build and deploy:

```sh
cd harness && bun install --frozen-lockfile && cd ..
bun ../f/bend2/main.ts system build
bun ../f/bend2/main.ts system deploy
```

Build produces `dist/ios-simulator/Dot.app`, `dist/ios-device/Dot.app` and
`dist/ios-device/Dot.ipa`. It compiles `ios.bend` through the fork's C compiler,
links the fork's UIKit host and unchanged painter, and signs locally using an
existing development identity and provisioning profile. It freezes the sources
and records their hashes in each target's `build.json`. It does not register
devices or upload to Apple. The development IPA installs only on devices already
registered in its embedded profile; downloading it does not install it.

For a simulator build without a signing profile:

```sh
bun script/build_ios.ts simulator
xcrun simctl install booted dist/ios-simulator/Dot.app
xcrun simctl launch booted com.pedroavj.opendot.ios
```

For a connected registered iPhone, use its identifier from `xcrun devicectl list devices`:

```sh
xcrun devicectl device install app --device DEVICE_ID dist/ios-device/Dot.app
xcrun devicectl device process launch --device DEVICE_ID com.pedroavj.opendot.ios
```

Deploy installs `com.pedroavj.opendot.harness` as a user LaunchAgent and exposes
loopback port 19453 through Tailscale HTTPS port 9453. Only the configured
Tailscale owner can use it. Provider credentials stay on the Mac.
Session files live in `~/Library/Application Support/OpenDot` and logs in
`~/Library/Logs/OpenDot`. The signed IPA is available privately at
`/downloads/Dot.ipa` on the harness address.

Codex uses the available default model from its model catalog and automatic
approval review. The owner-configured Mac runtime has full filesystem access,
including adjacent repositories. Open Dot answers tool-access approval requests
affirmatively for the current request or turn, including Computer Use app access.
It does not store global permission grants.

The microphone records a retained M4A voice message. You can play it, send it,
or retry speech recognition without rerecording it. Recognition supplies text
context to the subscription backends; the original audio remains available for
playback. The call button uses iPhone speech recognition and speech output in
the same conversation. Calls run while Dot is in the foreground; backgrounding
ends the call. The plus button picks a photo, previews it in the conversation,
and sends the actual image with its caption when you tap Send. Images and audio
stay private behind the same Tailscale authorization as the conversation.

The harness has both provider transports connected. Mobile routing currently
uses the stored provider, which defaults to Codex; there is no provider selector.
Automatic routing between the two providers has not been defined yet.

Run the shared client and harness checks:

```sh
bun ../f/bend2/main.ts tests mobile
cd harness && bun run typecheck && bun test
```

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
