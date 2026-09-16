#!/usr/bin/env sh
# Mirror contracts/ (and the lock) into the local stacflow-cloud checkout.
# This is the manual stand-in for the mirror-bot PR flow; the bot needs a
# cross-repo PAT and is wired once that secret exists (see phase-1-plan A3).
set -eu
cd "$(dirname "$0")/.."
DEST="../stacflow-cloud"
[ -d "$DEST/.git" ] || { echo "error: $DEST is not a git checkout" >&2; exit 1; }

rm -rf "$DEST/contracts"
cp -R contracts "$DEST/contracts"
mkdir -p "$DEST/tool"
cp tool/contracts_hash.sh "$DEST/tool/contracts_hash.sh"
./tool/contracts_hash.sh > contracts.lock
( cd "$DEST" && ./tool/contracts_hash.sh > contracts.lock )
if [ "$(cat contracts.lock)" = "$(cat "$DEST/contracts.lock")" ]; then
  echo "synced: $(cat contracts.lock)"
else
  echo "error: hashes diverge after sync" >&2
  exit 1
fi
