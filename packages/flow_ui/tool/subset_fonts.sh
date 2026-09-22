#!/usr/bin/env bash
#
# Rebuilds packages/flow_ui/fonts/ from a Google Fonts download.
#
#   pip install fonttools
#   tool/subset_fonts.sh ~/Downloads/Google_Sans,Google_Sans_Code
#
# Google Sans ships as a Latin subset: the full cuts are ~1.95 MB each, most
# of it scripts a chat UI gets from the platform face anyway. Google Sans Code
# is copied whole — it is already small, and the coverage a subset would drop
# (box drawing, arrows, technical symbols) is what a code face is for.
#
# The static cuts, not the variable TTFs: Flutter maps FontWeight to the
# nearest declared weight, so a weight axis would not be interpolated. The
# non-suffixed set, not the _17pt one — opsz runs 17-18 with a default of 18,
# so these are the default instance.

set -euo pipefail

SRC="${1:-}"
if [[ -z "$SRC" || ! -d "$SRC/Google_Sans/static" ]]; then
  echo "usage: $0 <path to the Google_Sans,Google_Sans_Code download>" >&2
  exit 1
fi

OUT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/fonts"
mkdir -p "$OUT"

# Google Fonts' latin, latin-ext and vietnamese ranges, plus the combining
# marks those need decomposed, and the symbols flow_ui draws itself — the
# nested list bullets in flow_markdown.dart are U+25E6 and U+25AA, which sit
# outside every Latin range.
RANGES="U+0000-00FF,U+0100-024F,U+0259,U+0300-036F,U+1E00-1EFF"
RANGES="$RANGES,U+2000-206F,U+2070-209F,U+20A0-20CF,U+2100-218F,U+2190-21FF"
RANGES="$RANGES,U+2212,U+2215,U+25A0-25FF,U+2713-2714,U+FB00-FB04,U+FEFF,U+FFFD"

SANS=(Regular Italic Medium MediumItalic SemiBold SemiBoldItalic Bold BoldItalic)
MONO=(
  Light LightItalic Regular Italic Medium MediumItalic
  SemiBold SemiBoldItalic Bold BoldItalic ExtraBold ExtraBoldItalic
)

for cut in "${SANS[@]}"; do
  # --name-IDs='*' keeps the copyright, trademark and licence records, which
  # pyftsubset drops by default and the OFL requires us to carry.
  pyftsubset "$SRC/Google_Sans/static/GoogleSans-$cut.ttf" \
    --output-file="$OUT/GoogleSans-$cut.ttf" \
    --unicodes="$RANGES" \
    --name-IDs='*' \
    --notdef-outline \
    --recalc-timestamp=0
done

for cut in "${MONO[@]}"; do
  cp "$SRC/Google_Sans_Code/static/GoogleSansCode-$cut.ttf" "$OUT/"
done

cp "$SRC/Google_Sans/OFL.txt" "$OUT/OFL.txt"
cp "$SRC/Google_Sans_Code/OFL.txt" "$OUT/OFL-GoogleSansCode.txt"

ls -l "$OUT"
du -sh "$OUT"
