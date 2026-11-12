#!/usr/bin/env sh
# Packages the extension into dist/lachesis.aseprite-extension (a zip).
set -e
cd "$(dirname "$0")/.."
mkdir -p dist
rm -f dist/lachesis.aseprite-extension
zip -r -q dist/lachesis.aseprite-extension package.json src README.md
echo "Built dist/lachesis.aseprite-extension"
