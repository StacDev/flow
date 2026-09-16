# tool/

Workspace tooling. Run everything from the repo root.

| Script | What it does |
|---|---|
| `contracts_gen.dart` | Generates `packages/stacflow/lib/src/generated/` from `contracts/`. `dart run tool/contracts_gen.dart`, then `dart format packages/stacflow/lib/src/generated`. Deterministic; CI regenerates and fails on drift. |
