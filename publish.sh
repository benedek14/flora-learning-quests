#!/bin/zsh
# Rebuilds the public game page and pushes it to GitHub Pages.
# The iPad app downloads the newest version the next time Flora opens it (about 1 minute after pushing).
# Usage: ./publish.sh "what changed"
set -e
cd "$(dirname "$0")"
./build-site.sh
git add -A
git commit -m "${1:-Update game}" || { echo "Nothing changed."; exit 0; }
git push
echo "Published. The iPad app picks it up on its next launch."
