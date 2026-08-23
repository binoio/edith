#!/bin/zsh
#
# build.sh: Build Edith.app.
#
# Usage: Scripts/build.sh [--release]
#   Debug build by default. --release builds the Release configuration
#   (unsigned; Scripts/release.sh handles signing and notarization).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

CONFIGURATION="Debug"
if [[ "${1:-}" == "--release" ]]; then
    CONFIGURATION="Release"
fi

DERIVED_DATA="build/DerivedData"

echo "==> Building Edith ($CONFIGURATION)"
xcodebuild \
    -project Edith.xcodeproj \
    -scheme Edith \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA" \
    -destination 'generic/platform=macOS' \
    build

APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/Edith.app"
echo "==> Built $APP"
