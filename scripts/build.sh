#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-Debug}"
DERIVED_DATA="$ROOT/.build"

cd "$ROOT"

xcodebuild \
  -project OpenRouterCredits.xcodeproj \
  -scheme OpenRouterCredits \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

APP="$DERIVED_DATA/Build/Products/$CONFIGURATION/OpenRouterCredits.app"

# Ad-hoc signing keeps local Keychain and notification behaviour predictable
# for a build that is not signed with a developer identity.
if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$APP"
fi

printf '\nBuilt %s\n' "$APP"
