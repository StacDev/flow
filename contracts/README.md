# contracts/

The stacflow wire contract: the event stream a transport produces for one
model segment, and the error codes it can carry. `tool/contracts_gen.dart`
generates `packages/stacflow/lib/src/generated/` from these files. The
generated directory is never hand-edited; CI regenerates it and fails on
drift.

| File | What it defines |
|---|---|
| `sse-events.schema.json` | The SSE streaming protocol: six events, framing rules, ordering invariants |
| `error-codes.json` | The error-code registry with failure-class attribution |

Evolution is additive: new event names, new optional fields, new error
codes. Decoders never throw on unknown events or fields.
