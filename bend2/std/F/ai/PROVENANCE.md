# Native AI source provenance

`wire_json.bend` adapts the standalone `json.bend` found in the locally cached unofficial Bend OpenAI SDK, package identifier `0xbfb6718181103ac566eb0ff5308d47ac`. The upstream file is copyright 2026 Gabriel Gouvea and licensed MIT; its complete license is retained in `WIRE_JSON_LICENSE`. This parser is internal wire infrastructure. Its generic JSON representation is not the public provider request, event, or lifecycle API.

The adaptation removes the unnecessary `@unsafe` annotation from structural `stringify` recursion, which the pinned compiler checks, and adds this provenance notice. The original cache and provider wrappers were not edited. No token-authentication logic, sidecars, provider clients, credentials, private subscription endpoints, or credential discovery were copied.

The provider-specific `requests.bend`, `codecs.bend`, `protocol.bend`, `speech.bend`, `voice.bend`, `runtime.bend`, `transcription.bend`, and `transcription-runtime.bend` are new local implementation. Provider contracts were checked against official sources linked in the AI README. Runtime foreign effects are an explicitly trusted physical transport boundary; pure request encoding, wire parsing, typed event decoding, and lifecycle transitions remain in Bend.
