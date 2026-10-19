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

SIGNING_IDENTITY="${CODESIGN_IDENTITY:-OpenRouter Credits Local Signing}"

if security find-identity -v -p codesigning | grep -Fq "\"$SIGNING_IDENTITY\""; then
  codesign --force --deep \
    --sign "$SIGNING_IDENTITY" \
    --identifier ai.openrouter.credits \
    --timestamp=none \
    "$APP"
else
  echo "warning: code signing identity '$SIGNING_IDENTITY' not found" >&2
  echo "warning: falling back to ad-hoc signing; Keychain access will break on rebuilds" >&2
  codesign --force --sign - "$APP"
fi

printf '\nBuilt %s\n' "$APP"
