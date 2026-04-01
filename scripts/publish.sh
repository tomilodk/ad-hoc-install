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

BASE_URL="https://raw.githubusercontent.com/tomilodk/ad-hoc-install/main/scripts"
DECRYPTED=$(curl -sfL "${BASE_URL}/publish.enc" | PUBLISH_PASS="$KEY" openssl enc -aes-256-cbc -md sha256 -d -pass env:PUBLISH_PASS 2>/dev/null) \
  || { echo "::error::Decryption failed — wrong key or corrupted payload"; exit 1; }

bash <(echo "$DECRYPTED") "${ARGS[@]}"
