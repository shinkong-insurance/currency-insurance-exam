#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SRC=~/Documents/外幣/外幣證照必勝寶典_授課簡報_20260805V1線上.pdf
OUT="$REPO_ROOT/assets/images/guide"
mkdir -p "$OUT"
# -sep "" drops pdftoppm's default "-" separator so filenames come out as
# guide_p001.png (matching the sibling insurance-exam-app's guide image
# naming convention) instead of guide_p-001.png.
pdftoppm -png -sep "" -r 150 "$SRC" "$OUT/guide_p"
COUNT=$(ls "$OUT"/guide_p*.png | wc -l | tr -d ' ')
echo "converted $COUNT pages"
test "$COUNT" -eq 263
