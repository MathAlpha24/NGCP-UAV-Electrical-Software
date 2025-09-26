#!/usr/bin/env bash
set -euo pipefail

# Default URL (can be overridden by passing a URL as first argument)
URL=${1:-http://0.0.0.0:8080}

# Try to open with firefox, otherwise fallback to xdg-open (Linux) or open (macOS)
if command -v firefox >/dev/null 2>&1; then
  # open in a new window (backgrounded)
  firefox --new-window "$URL" & disown
  echo "Opened $URL in Firefox."
  exit 0
fi

if command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$URL" >/dev/null 2>&1 &
  echo "Firefox not found — opened $URL with xdg-open."
  exit 0
fi

if command -v open >/dev/null 2>&1; then
  # macOS fallback
  open "$URL"
  echo "Firefox not found — opened $URL with open."
  exit 0
fi

echo "No browser launcher found. Please install Firefox or ensure xdg-open/open are available." >&2
exit 2
