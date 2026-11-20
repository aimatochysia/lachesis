#!/usr/bin/env sh
# Prints release notes in Markdown: optional "What's new" text, then one
# section per extension from extensions/<name>/RELEASE.md (what it does and
# its in-app menu), with the name of its download.
# Usage: ./scripts/release-notes.sh <tag> [what's new text]
set -e
cd "$(dirname "$0")/.."
tag="$1"
notes="$2"
[ -n "$tag" ] || { echo "Usage: $0 <tag> [notes]" >&2; exit 1; }

if [ -n "$notes" ]; then
  printf '## What'"'"'s new\n\n%s\n\n' "$notes"
fi

# Icons are linked at the commit the notes are built from, so notes rewritten
# for an older release still find them.
icon_ref="${GITHUB_SHA:-$tag}"

printf '## Extensions in this release\n\n'
printf 'All need Aseprite 1.3 or newer and work on Windows, macOS and Linux. Double-click a downloaded `.aseprite-extension` file, or add it in **Edit > Preferences > Extensions**. Commands have no default shortcut; bind one in **Edit > Keyboard Shortcuts**.\n\n'

for d in extensions/*/; do
  [ -f "$d/package.json" ] || continue
  name=$(basename "$d")
  title=$(jq -r '.displayName // .name' "$d/package.json")
  printf '### %s (`%s`)\n\n' "$title" "$name"
  if [ -f "$d/icon.png" ]; then
    printf '<img src="https://raw.githubusercontent.com/%s/%s/extensions/%s/icon.png" alt="" width="64">\n\n' \
      "${GITHUB_REPOSITORY:-aimatochysia/lachesis}" "$icon_ref" "$name"
  fi
  if [ -f "$d/RELEASE.md" ]; then
    cat "$d/RELEASE.md"
    printf '\n'
  else
    jq -r '.description' "$d/package.json"
    printf '\n'
  fi
  printf 'Download: `%s-%s.aseprite-extension` · [README](https://github.com/%s/blob/%s/extensions/%s/README.md)\n\n' \
    "$name" "$tag" "${GITHUB_REPOSITORY:-aimatochysia/lachesis}" "$tag" "$name"
done
