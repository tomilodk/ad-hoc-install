#!/usr/bin/env bash
set -euo pipefail

# Publish a build to the ad-hoc install system.
# Downloads the encrypted payload, decrypts it with the shared key, and runs it.
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/tomilodk/ad-hoc-install/main/scripts/publish.sh | bash -s -- \
#     --key "$PUBLISH_KEY" \
#     --app kurvo --title Kurvo --version 1.0.378 --bundle-id app.kurvo.prod \
#     --commit abc1234 --message "feat: something" --file ./build.ipa
#
# Required env:
#   GH_TOKEN — GitHub token with actions:write on tomilodk/ad-hoc-install

KEY="${PUBLISH_KEY:-}"
ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --key) KEY="$2"; shift 2;;
    *) ARGS+=("$1"); shift;;
  esac
done

[ -z "$KEY" ] && { echo "::error::--key argument or PUBLISH_KEY env var is required"; exit 1; }

echo "DEBUG: KEY length=${#KEY}"
echo "DEBUG: KEY value='${KEY}'"
echo "DEBUG: openssl=$(which openssl) ($(openssl version))"

BASE_URL="https://raw.githubusercontent.com/tomilodk/ad-hoc-install/main/scripts"

echo "DEBUG: Downloading publish.enc..."
curl -sfL "${BASE_URL}/publish.enc" -o /tmp/publish_debug.enc
echo "DEBUG: publish.enc size=$(wc -c < /tmp/publish_debug.enc)"

echo "DEBUG: Attempting decrypt with pass:..."
openssl enc -aes-256-cbc -md sha256 -d -pass "pass:${KEY}" -in /tmp/publish_debug.enc > /tmp/publish_debug_out.sh 2>&1 \
  && echo "DEBUG: Decrypt SUCCESS ($(wc -c < /tmp/publish_debug_out.sh) bytes)" \
  || echo "DEBUG: Decrypt FAILED: $(cat /tmp/publish_debug_out.sh)"

DECRYPTED=$(cat /tmp/publish_debug.enc | openssl enc -aes-256-cbc -md sha256 -d -pass "pass:${KEY}" 2>/dev/null) \
  || { echo "::error::Decryption failed — wrong key or corrupted payload"; exit 1; }
rm -f /tmp/publish_debug.enc /tmp/publish_debug_out.sh

bash <(echo "$DECRYPTED") "${ARGS[@]}"
