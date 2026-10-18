#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT/scripts/build.sh" "${1:-Debug}"

APP="$ROOT/.build/Build/Products/${1:-Debug}/OpenRouterCredits.app"

open "$APP"
