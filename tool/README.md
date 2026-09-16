# tool/

Workspace tooling. Run everything from the repo root.

| Script | What it does |
|---|---|
| `contracts_gen.dart` | Generates `packages/stacflow/lib/src/generated/` from `contracts/`. `dart run tool/contracts_gen.dart`, then `dart format packages/stacflow/lib/src/generated`. Deterministic; CI regenerates and fails on drift. |
| `contracts_hash.sh` | Canonical sha256 of `contracts/`. `./tool/contracts_hash.sh > contracts.lock` after any contracts change; CI fails when the lock is stale. |
| `sync_contracts.sh` | Mirrors `contracts/` and the hash script into the sibling `../stacflow-cloud` checkout and cross-checks both locks. Commit the result in that repo. |
