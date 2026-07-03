#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BOOK_SLUG="compatibility-for-single-christians"
DIST_DIR="$ROOT/dist"
COMBINED_MD="$DIST_DIR/$BOOK_SLUG.md"
HTML_OUT="$DIST_DIR/$BOOK_SLUG.html"
DOCX_OUT="$DIST_DIR/$BOOK_SLUG.docx"
EPUB_OUT="$DIST_DIR/$BOOK_SLUG.epub"
PDF_OUT="$DIST_DIR/$BOOK_SLUG.pdf"
ZIP_OUT="$DIST_DIR/$BOOK_SLUG-artifacts.zip"
CHECKSUMS_OUT="$DIST_DIR/SHA256SUMS.txt"

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 127
  fi
}

require pandoc
require python3
require sha256sum

rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

{
  echo "---"
  echo "title: Сумісність для одиноких християн"
  echo "subtitle: Біблійно-пастирська книга про мудрість стосунків"
  echo "author: Before We Build"
  echo "lang: uk-UA"
  echo "---"
  echo
  for file in manuscript/*.md appendices/*.md; do
    echo
    echo "<!-- source: $file -->"
    echo
    cat "$file"
    echo
  done
} > "$COMBINED_MD"

COMMON_ARGS=(
  --from markdown+smart
  --metadata-file metadata.yaml
  --toc
  --toc-depth=2
)

pandoc "${COMMON_ARGS[@]}" --standalone \
  --css assets/book.css \
  -o "$HTML_OUT" "$COMBINED_MD"

pandoc "${COMMON_ARGS[@]}" \
  -o "$DOCX_OUT" "$COMBINED_MD"

pandoc "${COMMON_ARGS[@]}" \
  --epub-title-page=false \
  -o "$EPUB_OUT" "$COMBINED_MD"

# PDF needs a Unicode-capable engine for Ukrainian Cyrillic.
pandoc "${COMMON_ARGS[@]}" \
  --pdf-engine=xelatex \
  -V mainfont="DejaVu Serif" \
  -V sansfont="DejaVu Sans" \
  -V monofont="DejaVu Sans Mono" \
  -V geometry:margin=1in \
  -o "$PDF_OUT" "$COMBINED_MD"

(
  cd "$DIST_DIR"
  sha256sum "$BOOK_SLUG.md" "$BOOK_SLUG.html" "$BOOK_SLUG.docx" "$BOOK_SLUG.epub" "$BOOK_SLUG.pdf" > "$(basename "$CHECKSUMS_OUT")"
)

python3 - <<'PY'
from pathlib import Path
import zipfile
slug = 'compatibility-for-single-christians'
dist = Path('dist')
files = [
    dist / f'{slug}.md',
    dist / f'{slug}.html',
    dist / f'{slug}.docx',
    dist / f'{slug}.epub',
    dist / f'{slug}.pdf',
    dist / 'SHA256SUMS.txt',
]
with zipfile.ZipFile(dist / f'{slug}-artifacts.zip', 'w', compression=zipfile.ZIP_DEFLATED) as z:
    for file in files:
        z.write(file, arcname=file.name)
PY

printf 'Built artifacts:\n'
find "$DIST_DIR" -maxdepth 1 -type f -printf '%f\t%s bytes\n' | sort
