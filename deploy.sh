#!/usr/bin/env bash
# Publishes index.html to the gh-pages branch of the given remote (default: origin).
set -euo pipefail

remote="${1:-origin}"
root="$(cd "$(dirname "$0")" && pwd)"
url="$(git -C "$root" remote get-url "$remote")"
revision="$(git -C "$root" rev-parse --short HEAD 2>/dev/null || echo 'uncommitted')"

site="$(mktemp -d)"
trap 'rm -rf "$site"' EXIT

cp "$root/index.html" "$site/"
touch "$site/.nojekyll"

cd "$site"
git init -q -b gh-pages
git add -A
git commit -q -m "Deploy $revision ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
# Force push: gh-pages holds only the latest build, its history is not worth keeping.
git push -q -f "$url" gh-pages

echo "Deployed $revision to $remote/gh-pages"
