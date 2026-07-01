#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:-1.2.0}"
BUILD="${BUILD:-120}"
TAG="${TAG:-v${VERSION}}"
REPOSITORY="${GITHUB_REPOSITORY:-hhcme/desk_tips}"
SPARKLE_ACCOUNT="${SPARKLE_ACCOUNT:-com.desktips.app}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-${DEVELOPER_ID_APPLICATION:-}}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-${APPLE_TEAM_ID:-}}"
REQUIRE_RELEASE_SIGNING="${REQUIRE_RELEASE_SIGNING:-${GITHUB_ACTIONS:-false}}"
NOTARIZE="${NOTARIZE:-auto}"
DERIVED_DATA="${DERIVED_DATA:-${ROOT_DIR}/build/DerivedData}"
DIST_DIR="${DIST_DIR:-${ROOT_DIR}/dist}"
DMG_ROOT="${DIST_DIR}/dmgroot"
APPCAST_SOURCE_DIR="${DIST_DIR}/appcast-input"
DMG_NAME="DeskTips-${VERSION}-macOS.dmg"
DMG_PATH="${DIST_DIR}/${DMG_NAME}"
APP_PATH="${DERIVED_DATA}/Build/Products/Release/DeskTips.app"
SPARKLE_BIN="${DERIVED_DATA}/SourcePackages/artifacts/sparkle/Sparkle/bin"
RELEASE_NOTES_SOURCE="${ROOT_DIR}/release-notes/${VERSION}.md"
RELEASE_NOTES_TARGET="${DIST_DIR}/DeskTips-${VERSION}-macOS.md"

mkdir -p "${DIST_DIR}"

sign_bundle() {
  local path="$1"
  [[ -e "${path}" ]] || return 0

  codesign \
    --force \
    --timestamp \
    --options runtime \
    --sign "${SIGNING_IDENTITY}" \
    --preserve-metadata=identifier,entitlements,flags \
    "${path}"
}

resign_release_app() {
  local sparkle_framework="${APP_PATH}/Contents/Frameworks/Sparkle.framework"
  local sparkle_current="${sparkle_framework}/Versions/Current"

  sign_bundle "${sparkle_current}/Autoupdate"
  sign_bundle "${sparkle_current}/Updater.app"
  sign_bundle "${sparkle_current}/XPCServices/Downloader.xpc"
  sign_bundle "${sparkle_current}/XPCServices/Installer.xpc"
  sign_bundle "${sparkle_framework}"
  sign_bundle "${APP_PATH}"
}

if [[ "${REQUIRE_RELEASE_SIGNING}" == "true" && -z "${SIGNING_IDENTITY}" ]]; then
  echo "Developer ID signing identity is required for Sparkle release updates." >&2
  exit 1
fi

if [[ "${REQUIRE_RELEASE_SIGNING}" == "true" ]]; then
  for required_var in APPLE_ID APPLE_APP_SPECIFIC_PASSWORD APPLE_TEAM_ID; do
    if [[ -z "${!required_var:-}" ]]; then
      echo "${required_var} is required for notarized Sparkle release updates." >&2
      exit 1
    fi
  done
fi

build_args=(
  xcodebuild
  -project "${ROOT_DIR}/DeskTips.xcodeproj"
  -scheme DeskTips
  -configuration Release
  -derivedDataPath "${DERIVED_DATA}"
  MARKETING_VERSION="${VERSION}"
  CURRENT_PROJECT_VERSION="${BUILD}"
)

if [[ -n "${SIGNING_IDENTITY}" ]]; then
  build_args+=(
    CODE_SIGN_STYLE=Manual
    CODE_SIGN_IDENTITY="${SIGNING_IDENTITY}"
    AD_HOC_CODE_SIGNING_ALLOWED=NO
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO
    OTHER_CODE_SIGN_FLAGS=--timestamp
  )

  if [[ -n "${DEVELOPMENT_TEAM}" ]]; then
    build_args+=(DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}")
  fi
else
  echo "Warning: building without Developer ID signing. The DMG can be used for local testing, but Sparkle auto-install will not be reliable." >&2
fi

"${build_args[@]}" build

if [[ -n "${SIGNING_IDENTITY}" ]]; then
  resign_release_app
fi

codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

if [[ -n "${SIGNING_IDENTITY}" ]]; then
  if codesign -dv "${APP_PATH}" 2>&1 | grep -q "Signature=adhoc"; then
    echo "Release app is still ad-hoc signed; refusing to publish a Sparkle update." >&2
    exit 1
  fi

  if codesign -d --entitlements :- "${APP_PATH}" 2>/dev/null | plutil -p - | grep -q '"com.apple.security.get-task-allow" => true'; then
    echo "Release app contains get-task-allow; refusing to publish a debug entitlement." >&2
    exit 1
  fi

  for signed_component in \
    "${APP_PATH}/Contents/Frameworks/Sparkle.framework/Versions/Current/Autoupdate" \
    "${APP_PATH}/Contents/Frameworks/Sparkle.framework/Versions/Current/Updater.app" \
    "${APP_PATH}/Contents/Frameworks/Sparkle.framework/Versions/Current/XPCServices/Downloader.xpc" \
    "${APP_PATH}/Contents/Frameworks/Sparkle.framework/Versions/Current/XPCServices/Installer.xpc"; do
    if [[ -e "${signed_component}" ]] && codesign -dv "${signed_component}" 2>&1 | grep -q "Signature=adhoc"; then
      echo "${signed_component} is still ad-hoc signed; refusing to publish a Sparkle update." >&2
      exit 1
    fi
  done
fi

rm -rf "${DMG_ROOT}"
mkdir -p "${DMG_ROOT}"
ditto "${APP_PATH}" "${DMG_ROOT}/DeskTips.app"

hdiutil create \
  -volname DeskTips \
  -srcfolder "${DMG_ROOT}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

if [[ -n "${SIGNING_IDENTITY}" ]]; then
  codesign --force --timestamp --sign "${SIGNING_IDENTITY}" "${DMG_PATH}"
fi

should_notarize=false
case "${NOTARIZE}" in
  true|TRUE|yes|YES|1)
    should_notarize=true
    ;;
  false|FALSE|no|NO|0)
    should_notarize=false
    ;;
  auto)
    if [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" && -n "${APPLE_TEAM_ID:-}" ]]; then
      should_notarize=true
    fi
    ;;
  *)
    echo "Unknown NOTARIZE value: ${NOTARIZE}" >&2
    exit 1
    ;;
esac

if [[ "${should_notarize}" == "true" ]]; then
  if [[ -z "${APPLE_ID:-}" || -z "${APPLE_APP_SPECIFIC_PASSWORD:-}" || -z "${APPLE_TEAM_ID:-}" ]]; then
    echo "APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD and APPLE_TEAM_ID are required for notarization." >&2
    exit 1
  fi

  xcrun notarytool submit "${DMG_PATH}" \
    --apple-id "${APPLE_ID}" \
    --password "${APPLE_APP_SPECIFIC_PASSWORD}" \
    --team-id "${APPLE_TEAM_ID}" \
    --wait

  xcrun stapler staple "${DMG_PATH}"
  xcrun stapler validate "${DMG_PATH}"
fi

if [[ -f "${RELEASE_NOTES_SOURCE}" ]]; then
  cp "${RELEASE_NOTES_SOURCE}" "${RELEASE_NOTES_TARGET}"
fi

if [[ -x "${SPARKLE_BIN}/generate_appcast" ]]; then
  rm -f "${DIST_DIR}/appcast.xml"
  rm -rf "${APPCAST_SOURCE_DIR}"
  mkdir -p "${APPCAST_SOURCE_DIR}"
  cp "${DMG_PATH}" "${APPCAST_SOURCE_DIR}/${DMG_NAME}"
  if [[ -f "${RELEASE_NOTES_TARGET}" ]]; then
    cp "${RELEASE_NOTES_TARGET}" "${APPCAST_SOURCE_DIR}/DeskTips-${VERSION}-macOS.md"
  fi

  appcast_args=(
    --download-url-prefix "https://github.com/${REPOSITORY}/releases/download/${TAG}/"
    --full-release-notes-url "https://github.com/${REPOSITORY}/releases/tag/${TAG}"
    --embed-release-notes
    -o "${DIST_DIR}/appcast.xml"
    "${APPCAST_SOURCE_DIR}"
  )

  if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
    printf "%s" "${SPARKLE_PRIVATE_KEY}" | "${SPARKLE_BIN}/generate_appcast" --ed-key-file - "${appcast_args[@]}"
  else
    "${SPARKLE_BIN}/generate_appcast" --account "${SPARKLE_ACCOUNT}" "${appcast_args[@]}"
  fi
fi

echo "Created ${DMG_PATH}"
echo "Created ${DIST_DIR}/appcast.xml"
