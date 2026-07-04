#!/bin/bash
# Stop hook: runs npm run build:main if src/ has uncommitted changes.
# Exit 2 blocks Claude from stopping so it can fix build errors.

cd "$(git rev-parse --show-toplevel)" || exit 0

if git diff --name-only HEAD 2>/dev/null | grep -q '^src/'; then
  echo "[stop-build-check] src/ changes detected — running build:main"
  if ! npm run build:main; then
    echo "[stop-build-check] Build failed — fix errors before finishing."
    exit 2
  fi
  echo "[stop-build-check] Build passed."
fi
