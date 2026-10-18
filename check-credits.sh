#!/usr/bin/env bash
set -euo pipefail

ENDPOINT="https://openrouter.ai/api/v1/credits"
BODY_FILE="$(mktemp)"
trap 'rm -f "$BODY_FILE"; unset KEY' EXIT

printf "OpenRouter management API key: "
read -rs KEY
printf "\n\n"

STATUS="$(
  curl -sS -o "$BODY_FILE" -w "%{http_code}" \
    "$ENDPOINT" \
    -H "Authorization: Bearer $KEY" \
    -H "Accept: application/json"
)" || {
  printf "Request failed. Check your network connection.\n" >&2
  exit 1
}

printf "HTTP %s\n\n" "$STATUS"

if command -v jq >/dev/null 2>&1; then
  if [ "$STATUS" = "200" ]; then
    jq -r '
      "Total credits: $\(.data.total_credits)",
      "Total usage:   $\(.data.total_usage)",
      "Remaining:     $\((.data.total_credits - .data.total_usage) * 100 | round / 100)"
    ' "$BODY_FILE"
  else
    jq . "$BODY_FILE" 2>/dev/null || cat "$BODY_FILE"
  fi
else
  cat "$BODY_FILE"
fi

printf "\n"

case "$STATUS" in
  200)
    exit 0
    ;;
  401)
    printf "Hint: the management key is invalid or expired.\n" >&2
    ;;
  403)
    printf "Hint: create a Management API key at https://openrouter.ai/settings/management-keys\n" >&2
    ;;
esac

exit 1
