#!/usr/bin/env sh
# Canonical hash of the contracts/ tree (dev-plan §5.4). The same script runs
# in both repos; CI in stacflow-cloud fails when its mirrored tree hashes
# differently from this repo's.
set -eu
cd "$(dirname "$0")/.."

if command -v sha256sum >/dev/null 2>&1; then
  SHA="sha256sum"
else
  SHA="shasum -a 256"
fi

# Relative paths, sorted bytewise, per-file hash then a hash of the hash list —
# deterministic across machines and filesystems.
LC_ALL=C find contracts -type f ! -name '.DS_Store' -print | LC_ALL=C sort | while IFS= read -r f; do
  $SHA "$f"
done | $SHA | cut -d' ' -f1
