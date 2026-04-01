#!/usr/bin/env bash
set -euo pipefail

# ──── Secrets (baked in, encrypted at rest in publish.enc) ────
export AWS_ACCESS_KEY_ID="{REPLACE_ACCESS_KEY_FOR_R2}"
export AWS_SECRET_ACCESS_KEY="{REPLACE_SECRET_ACCESS_KEY_FOR_R2}"
export AWS_DEFAULT_REGION=auto

# ──── Config ────
R2_ENDPOINT="https://0e9240137487379e22b84ff9e8bd39e7.eu.r2.cloudflarestorage.com"
R2_BUCKET="ad-hoc-install"
INSTALL_REPO="tomilodk/ad-hoc-install"
INSTALL_URL_BASE="https://install.mappso.com"

# ──── Parse args ────
APP="" TITLE="" VERSION="" BUNDLE_ID="" COMMIT="" MESSAGE="" FILE="" REGISTER_URL=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --app)                 APP="$2"; shift 2;;
    --title)               TITLE="$2"; shift 2;;
    --version)             VERSION="$2"; shift 2;;
    --bundle-id)           BUNDLE_ID="$2"; shift 2;;
    --commit)              COMMIT="$2"; shift 2;;
    --message)             MESSAGE="$2"; shift 2;;
    --file)                FILE="$2"; shift 2;;
    --register-device-url) REGISTER_URL="$2"; shift 2;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

# ──── Validate ────
missing=()
[ -z "$APP" ]       && missing+=(--app)
[ -z "$TITLE" ]     && missing+=(--title)
[ -z "$VERSION" ]   && missing+=(--version)
[ -z "$BUNDLE_ID" ] && missing+=(--bundle-id)
[ -z "$COMMIT" ]    && missing+=(--commit)
[ -z "$MESSAGE" ]   && missing+=(--message)
[ -z "$FILE" ]      && missing+=(--file)

if [ ${#missing[@]} -gt 0 ]; then
  echo "::error::Missing required args: ${missing[*]}"
  exit 1
fi

[ ! -f "$FILE" ] && { echo "::error::File not found: $FILE"; exit 1; }

# ──── Upload to R2 ────
EXT="${FILE##*.}"

echo "Uploading ${APP}.${EXT} to R2..."

# Latest — overwrites previous build
aws s3 cp "$FILE" "s3://${R2_BUCKET}/${APP}/${APP}.${EXT}" \
  --endpoint-url "$R2_ENDPOINT" \
  --content-type "application/octet-stream"

# Stash — versioned archive (R2 lifecycle rule auto-deletes old builds)
aws s3 cp "$FILE" "s3://${R2_BUCKET}/stash/${APP}/${VERSION}/${APP}.${EXT}" \
  --endpoint-url "$R2_ENDPOINT" \
  --content-type "application/octet-stream"

echo "::notice::Uploaded to R2: ${APP}/${APP}.${EXT} + stash/${APP}/${VERSION}/"

# ──── Trigger metadata update ────
if [ -z "${GH_TOKEN:-}" ]; then
  echo "::warning::GH_TOKEN not set — IPA uploaded to R2 but manifests not updated"
  exit 0
fi

FIELDS=(
  --field app="$APP"
  --field title="$TITLE"
  --field version="$VERSION"
  --field bundle-id="$BUNDLE_ID"
  --field commit="$COMMIT"
  --field message="$MESSAGE"
)
[ -n "$REGISTER_URL" ] && FIELDS+=(--field register-device-url="$REGISTER_URL")

gh workflow run publish.yml --repo "$INSTALL_REPO" "${FIELDS[@]}"

INSTALL_URL="${INSTALL_URL_BASE}/?app=${APP}"
echo ""
echo "=========================================="
echo "  Publish triggered for ${TITLE}"
echo "=========================================="
echo ""
echo "${INSTALL_URL}"
echo ""

{
  echo "## Install ${TITLE}"
  echo ""
  echo "Open on iPhone: ${INSTALL_URL}"
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"
