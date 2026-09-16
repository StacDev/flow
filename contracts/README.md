# contracts/ — the single source of truth

The StacFlow wire contract is authored **here** and only here. TypeScript
(gateway) and Dart (SDK + console client) types are generated from these
files — never hand-written. A bot PR mirrors this tree into
`StacDev/stacflow-cloud`; CI on both repos fails when the canonical hashes
differ (`tool/contracts_hash.sh`).

| File | What it defines |
|---|---|
| `sse-events.schema.json` | The SSE streaming protocol v1: seven events, framing rules, ordering invariants |
| `rest-api.openapi.yaml` | The `/v1` REST surface (OpenAPI 3.1) |
| `error-codes.json` | The frozen machine-readable error-code registry + failure-class attribution |
| `a2ui/` | Vendored A2UI v0.9.x schemas (generative UI payloads; consumed from M2) |

**Status: v1-draft.** Field names freeze at the M1 exit — after all three
provider conformance suites and the console playground consume the protocol.
After the freeze, evolution is **additive only**: new event names, new optional
fields, new error codes. Decoders never throw on unknown events or fields.
