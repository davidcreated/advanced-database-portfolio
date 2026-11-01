#!/bin/zsh
# Builds the LMS documentation PDF from documentation.md.
# Run from anywhere: final-documentation/build.sh
set -e
HERE=${0:A:h}
NAME=Folorunsho-Roberts_David-Paul_2026-A-MIT-0268
OUT=$HERE/../$NAME/${NAME}_Documentation.pdf
CHROME=$(ls ~/.cache/puppeteer/chrome-headless-shell/*/chrome-headless-shell-mac-arm64/chrome-headless-shell | head -1)
HTML=$HERE/documentation.html

{
  echo '<!doctype html><html lang="en"><head><meta charset="utf-8">'
  echo "<title>${NAME} Documentation</title>"
  echo '<link rel="stylesheet" href="style.css"></head><body>'
  npx -y marked@4.3.0 --gfm -i $HERE/documentation.md
  echo '</body></html>'
} > $HTML

mkdir -p ${OUT:h}
$CHROME --headless --disable-gpu --no-pdf-header-footer --allow-file-access-from-files \
        --print-to-pdf=$OUT file://$HTML 2> /dev/null
rm -f $HTML
echo "built ${OUT:t} ($(du -h $OUT | cut -f1 | tr -d ' '))"
