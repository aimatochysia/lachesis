#!/usr/bin/env sh
# Packages extensions into dist/<name>.aseprite-extension (a zip each).
# Usage: ./scripts/build.sh [name ...]   (no names = every extension)
set -e
cd "$(dirname "$0")/.."
root=$(pwd)
mkdir -p dist

if [ "$#" -eq 0 ]; then
  for d in extensions/*/; do
    [ -f "$d/package.json" ] && set -- "$@" "$(basename "$d")"
  done
fi
[ "$#" -eq 0 ] && { echo "No extensions found under extensions/"; exit 1; }

for name in "$@"; do
  dir="extensions/$name"
  [ -f "$dir/package.json" ] || { echo "Unknown extension: $name"; exit 1; }
  out="$root/dist/$name.aseprite-extension"
  rm -f "$out"
  (cd "$dir" && zip -r -q "$out" package.json src README.md)
  echo "Built dist/$name.aseprite-extension"
done
