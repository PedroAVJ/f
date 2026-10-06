# Dot Apple provisioning

The HyperTUI Apple page calls this local JSON program. Run `node main.js` and send one object on stdin: `{"name":"apple_signing_status","arguments":{}}`. It returns one JSON object on stdout. `--schemas` prints the four exact tool schemas,.

The page sequence is status → prepare → provision → operation status. Preparation returns a random operation ID. Provisioning accepts only that ID, runs asynchronously, and never installs or launches an app. Repeating the same submit does not launch another process. Terminal operations require a new preparation before another attempt.

Scope is fixed to `com.pedroavj.opendot.ios`, `com.pedroavj.opendot.ios.share`, and `group.com.pedroavj.opendot`. No tool accepts a credential, account, arbitrary command, path, app identifier, or group identifier. Credentials resolve only inside the process from the existing private key and local environment/configuration. Tokens and raw Apple response/error bodies are never returned or logged. Operation records are private local files; public results carry only opaque IDs and sanitized state.

## Current verified boundary

On 2026-10-06, 336 cached provisioning profiles were inspected: none grants the required App Group to both Dot targets. One usable Apple Development identity is available. The existing private key is present, but its team issuer was not found in bounded local signing/configuration sources. A read-only request to Apple's certificates API using individual-key token claims returned HTTP 401. No Apple account mutation or provisioning build was performed.

Apple's public App Store Connect OpenAPI 4.5.1 has no App Group creation or association path. The wrapper does not invent one. Its authenticated branch uses Apple's `xcodebuild -allowProvisioningUpdates` and fixed local project with the existing API key; this avoids Xcode UI sign-in. The installed tool's help documents creation/update of profiles, app IDs, and certificates, **not proof that this account/key can create or associate the requested App Group**. Successful authentication alone is therefore insufficient to claim completion. That branch remains unverified until the required profiles are actually issued and read back.

The CLI internally requires Apple's authentication-key flags; these are not HyperTUI schemas, page URIs, action arguments, or results. Raw command output is discarded. Provisioning has a five-minute limit, one build job, and a 3,800 MiB process-group RSS guard.

`shareSigningReady` checks local explicit development profiles, App Group, push entitlement for Dot, expiry, and an available signing identity. Physical-device coverage is intentionally reported unverified and must be checked for the selected iPhone before signing/installing the actual app. The small provisioning project is never installed. The actual share-enabled Dot build must not be installed until the compound-upload backend is live and verified.

Sources: [Apple API](https://developer.apple.com/documentation/appstoreconnectapi/), [registering App Groups](https://developer.apple.com/help/account/identifiers/register-an-app-group), installed `xcodebuild -help`.

Tests: `node --test test.js` checks operation scope, duplicate submission, path/scope rejection, authentication-before-mutation, sanitized errors, and terminal-operation retry behavior. These tests do not claim successful Apple provisioning.
