#!/bin/zsh
#
# run.sh: Build (Debug) and launch Edith.app.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

zsh Scripts/build.sh

APP="build/DerivedData/Build/Products/Debug/Edith.app"
echo "==> Launching $APP"
open "$APP"
