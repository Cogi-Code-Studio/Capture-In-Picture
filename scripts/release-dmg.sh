#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Build, notarize, and optionally upload a DMG for Capture In Picture.

Usage:
  ./scripts/release-dmg.sh [options]

Options:
  --tag <tag>           Existing GitHub release tag to upload to, for example v1.0.0
  --version <version>   Version string used in the DMG filename. Defaults to the tag without a leading "v",
                        or the project's MARKETING_VERSION when no tag is provided.
  --identity <name>     Developer ID Application identity to use for code signing.
  --output-dir <path>   Directory for final artifacts. Defaults to ./dist
  --skip-notarize       Build and sign the DMG but skip notarization and stapling.
  --upload              Upload the generated DMG and .sha256 file to the existing GitHub release tag.
  -h, --help            Show this help message.

Environment:
  APP_STORE_CONNECT_KEY_ID
  APP_STORE_CONNECT_ISSUER_ID
  APP_STORE_CONNECT_PRIVATE_KEY
    Raw multiline contents of the AuthKey_XXXXXX.p8 file.

  APP_STORE_CONNECT_PRIVATE_KEY_FILE
    Path to the AuthKey_XXXXXX.p8 file. Preferred locally if you already have the file on disk.

  DEVELOPER_ID_IDENTITY
    Optional override when more than one "Developer ID Application" certificate exists in Keychain Access.

Examples:
  ./scripts/release-dmg.sh --version 1.0.0
  ./scripts/release-dmg.sh --tag v1.0.0 --upload
  APP_STORE_CONNECT_PRIVATE_KEY_FILE=~/Keys/AuthKey_ABCD123456.p8 ./scripts/release-dmg.sh --tag v1.0.0
EOF
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

resolve_project_version() {
  sed -n 's/.*MARKETING_VERSION = \([^;]*\);/\1/p' "$ROOT_DIR/CaptureInPicture.xcodeproj/project.pbxproj" | head -n 1
}

resolve_developer_id_identity() {
  security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p' \
    | head -n 1
}

cleanup() {
  if [[ -n "${TEMP_DIR:-}" && -d "${TEMP_DIR}" ]]; then
    rm -rf "${TEMP_DIR}"
  fi

  if [[ "${API_KEY_PATH_IS_TEMP:-0}" == "1" && -n "${API_KEY_PATH:-}" && -f "${API_KEY_PATH}" ]]; then
    rm -f "${API_KEY_PATH}"
  fi
}

trap cleanup EXIT

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/CaptureInPicture.xcodeproj}"
SCHEME="${SCHEME:-CaptureInPicture}"
APP_NAME="${APP_NAME:-CaptureInPicture}"
APP_DISPLAY_NAME="${APP_DISPLAY_NAME:-Capture In Picture}"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-$ROOT_DIR/.github/exportOptions/developer-id.plist}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/dist}"
NOTARY_MAX_ATTEMPTS="${NOTARY_MAX_ATTEMPTS:-60}"
NOTARY_POLL_SECONDS="${NOTARY_POLL_SECONDS:-30}"

TAG=""
VERSION=""
UPLOAD=0
SKIP_NOTARIZE=0
DEVELOPER_ID_IDENTITY="${DEVELOPER_ID_IDENTITY:-}"
API_KEY_PATH=""
API_KEY_PATH_IS_TEMP=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)
      [[ $# -ge 2 ]] || die "--tag requires a value"
      TAG="$2"
      shift 2
      ;;
    --version)
      [[ $# -ge 2 ]] || die "--version requires a value"
      VERSION="$2"
      shift 2
      ;;
    --identity)
      [[ $# -ge 2 ]] || die "--identity requires a value"
      DEVELOPER_ID_IDENTITY="$2"
      shift 2
      ;;
    --output-dir)
      [[ $# -ge 2 ]] || die "--output-dir requires a value"
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --skip-notarize)
      SKIP_NOTARIZE=1
      shift
      ;;
    --upload)
      UPLOAD=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

require_command xcodebuild
require_command codesign
require_command security
require_command hdiutil
require_command xcrun
require_command shasum

[[ -d "$PROJECT_PATH" ]] || die "Project not found at $PROJECT_PATH"
[[ -f "$EXPORT_OPTIONS_PLIST" ]] || die "Export options plist not found at $EXPORT_OPTIONS_PLIST"

if [[ -z "$VERSION" ]]; then
  if [[ -n "$TAG" ]]; then
    VERSION="${TAG#v}"
  else
    VERSION="$(resolve_project_version)"
  fi
fi

[[ -n "$VERSION" ]] || die "Unable to resolve a release version. Pass --version or --tag."

if [[ "$UPLOAD" == "1" ]]; then
  [[ -n "$TAG" ]] || die "--upload requires --tag so the script knows which GitHub release to target."
  require_command gh
fi

if [[ -z "$DEVELOPER_ID_IDENTITY" ]]; then
  DEVELOPER_ID_IDENTITY="$(resolve_developer_id_identity)"
fi

[[ -n "$DEVELOPER_ID_IDENTITY" ]] || die "No Developer ID Application identity found. Export the correct certificate to Keychain Access first."

if [[ "$SKIP_NOTARIZE" == "0" ]]; then
  require_command xcrun

  if [[ -n "${APP_STORE_CONNECT_PRIVATE_KEY_FILE:-}" ]]; then
    [[ -f "${APP_STORE_CONNECT_PRIVATE_KEY_FILE}" ]] || die "APP_STORE_CONNECT_PRIVATE_KEY_FILE does not point to a file."
    API_KEY_PATH="${APP_STORE_CONNECT_PRIVATE_KEY_FILE}"
  elif [[ -n "${APP_STORE_CONNECT_PRIVATE_KEY:-}" ]]; then
    API_KEY_PATH_IS_TEMP=1
    API_KEY_PATH="$(mktemp "${TMPDIR:-/tmp}/capture-in-picture-api-key.XXXXXX.p8")"
    printf '%s' "${APP_STORE_CONNECT_PRIVATE_KEY}" > "$API_KEY_PATH"
  else
    die "Notarization requires APP_STORE_CONNECT_PRIVATE_KEY_FILE or APP_STORE_CONNECT_PRIVATE_KEY."
  fi

  [[ -n "${APP_STORE_CONNECT_KEY_ID:-}" ]] || die "Missing APP_STORE_CONNECT_KEY_ID"
  [[ -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]] || die "Missing APP_STORE_CONNECT_ISSUER_ID"
fi

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/capture-in-picture-release.XXXXXX")"
ARCHIVE_PATH="$TEMP_DIR/${APP_NAME}.xcarchive"
EXPORT_PATH="$TEMP_DIR/export"
DMG_ROOT="$TEMP_DIR/dmg-root"

mkdir -p "$OUTPUT_DIR"

DMG_PATH="$OUTPUT_DIR/${APP_NAME}-${VERSION}.dmg"
CHECKSUM_PATH="${DMG_PATH}.sha256"

rm -f "$DMG_PATH" "$CHECKSUM_PATH"

printf 'Using Developer ID identity: %s\n' "$DEVELOPER_ID_IDENTITY"
printf 'Building version: %s\n' "$VERSION"
printf 'Output directory: %s\n' "$OUTPUT_DIR"

printf '\n==> Archiving app\n'
xcodebuild archive \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$DEVELOPER_ID_IDENTITY"

printf '\n==> Exporting signed app\n'
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
  -exportPath "$EXPORT_PATH"

APP_PATH="$EXPORT_PATH/${APP_NAME}.app"
[[ -d "$APP_PATH" ]] || die "Expected exported app at $APP_PATH"

printf '\n==> Verifying app signature\n'
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

printf '\n==> Creating DMG\n'
mkdir -p "$DMG_ROOT"
cp -R "$APP_PATH" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"

hdiutil create \
  -volname "$APP_DISPLAY_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ "$SKIP_NOTARIZE" == "0" ]]; then
  printf '\n==> Submitting DMG for notarization\n'
  SUBMISSION_JSON="$TEMP_DIR/notary-submit.json"
  STATUS_JSON="$TEMP_DIR/notary-status.json"

  xcrun notarytool submit "$DMG_PATH" \
    --key "$API_KEY_PATH" \
    --key-id "$APP_STORE_CONNECT_KEY_ID" \
    --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
    --output-format json \
    > "$SUBMISSION_JSON"

  cat "$SUBMISSION_JSON"

  SUBMISSION_ID="$(sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$SUBMISSION_JSON" | head -n 1)"
  [[ -n "$SUBMISSION_ID" ]] || die "Could not read notarization submission id."

  printf 'Submission ID: %s\n' "$SUBMISSION_ID"

  ACCEPTED=0
  for attempt in $(seq 1 "$NOTARY_MAX_ATTEMPTS"); do
    xcrun notarytool info "$SUBMISSION_ID" \
      --key "$API_KEY_PATH" \
      --key-id "$APP_STORE_CONNECT_KEY_ID" \
      --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
      --output-format json \
      > "$STATUS_JSON"

    STATUS="$(sed -n 's/.*"status"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$STATUS_JSON" | head -n 1)"
    SUMMARY="$(sed -n 's/.*"statusSummary"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$STATUS_JSON" | head -n 1)"

    printf 'Notarization attempt %s/%s: %s' "$attempt" "$NOTARY_MAX_ATTEMPTS" "${STATUS:-unknown}"
    if [[ -n "$SUMMARY" ]]; then
      printf ' - %s' "$SUMMARY"
    fi
    printf '\n'

    if [[ "$STATUS" == "Accepted" ]]; then
      ACCEPTED=1
      break
    fi

    if [[ "$STATUS" == "Invalid" || "$STATUS" == "Rejected" ]]; then
      printf '\n==> Notarization log\n'
      xcrun notarytool log "$SUBMISSION_ID" \
        --key "$API_KEY_PATH" \
        --key-id "$APP_STORE_CONNECT_KEY_ID" \
        --issuer "$APP_STORE_CONNECT_ISSUER_ID"
      die "Notarization failed with status: $STATUS"
    fi

    sleep "$NOTARY_POLL_SECONDS"
  done

  [[ "$ACCEPTED" == "1" ]] || die "Timed out waiting for notarization. Submission ID: $SUBMISSION_ID"

  printf '\n==> Stapling and validating DMG\n'
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  spctl -a -vv -t open "$DMG_PATH"
else
  printf '\n==> Skipping notarization as requested\n'
fi

printf '\n==> Writing checksum\n'
shasum -a 256 "$DMG_PATH" > "$CHECKSUM_PATH"

if [[ "$UPLOAD" == "1" ]]; then
  printf '\n==> Uploading assets to GitHub release %s\n' "$TAG"
  gh release view "$TAG" >/dev/null
  gh release upload "$TAG" "$DMG_PATH" "$CHECKSUM_PATH" --clobber
fi

printf '\nDone.\n'
printf 'DMG: %s\n' "$DMG_PATH"
printf 'Checksum: %s\n' "$CHECKSUM_PATH"

