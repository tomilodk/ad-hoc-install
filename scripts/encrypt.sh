#!/usr/bin/env bash
set -euo pipefail

# Encrypt publish-inner.sh → publish.enc
# Usage: ./scripts/encrypt.sh <shared-secret>
#
# Run this after editing publish-inner.sh (e.g., rotating R2 credentials).
# Commit the updated publish.enc — never commit publish-inner.sh.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INNER="${SCRIPT_DIR}/publish-inner.sh"
OUTPUT="${SCRIPT_DIR}/publish.enc"

[ -z "${1:-}" ] && { echo "Usage: $0 <shared-secret>"; exit 1; }
[ ! -f "$INNER" ] && { echo "Error: ${INNER} not found"; exit 1; }

openssl enc -aes-256-cbc -pbkdf2 -salt -in "$INNER" -out "$OUTPUT" -pass "pass:${1}"

echo "Encrypted: ${OUTPUT}"
echo "Test decryption:"
echo "  openssl enc -aes-256-cbc -pbkdf2 -d -in ${OUTPUT} -pass pass:YOUR_KEY | head -5"
