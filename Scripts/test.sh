#!/bin/zsh
#
# test.sh: Run the Edith test suites.
#
# Usage: Scripts/test.sh [--ui]
#   Runs the EdithTests unit suite by default; --ui also runs EdithUITests
#   (UI tests drive the real app and need a logged-in GUI session).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

ARGS=(-project Edith.xcodeproj -scheme Edith -derivedDataPath build/DerivedData -destination 'platform=macOS')
if [[ "${1:-}" == "--ui" ]]; then
    echo "==> Running unit and UI tests"
    xcodebuild test "${ARGS[@]}"
else
    echo "==> Running unit tests (EdithTests)"
    xcodebuild test "${ARGS[@]}" -only-testing:EdithTests
fi
