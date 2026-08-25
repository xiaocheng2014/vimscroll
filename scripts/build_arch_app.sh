#!/bin/zsh
set -euo pipefail

ARCH="${1:?Usage: build_arch_app.sh <x86_64|arm64> <output-dir> [version] [build-number]}"
OUTPUT_DIR="${2:?Usage: build_arch_app.sh <x86_64|arm64> <output-dir> [version] [build-number]}"
VERSION="${3:-1.2.0}"
BUILD_NUMBER="${4:-1}"

SCRIPT_DIR="${0:A:h}"
ROOT_DIR="${SCRIPT_DIR:h}"
BUILD_DIR="${ROOT_DIR}/build/release-${ARCH}"

case "${ARCH}" in
  x86_64)
    PACKAGE_NAME="VimScroll-macOS-Intel.zip"
    ;;
  arm64)
    PACKAGE_NAME="VimScroll-macOS-Apple-Silicon.zip"
    ;;
  *)
    echo "Unsupported architecture: ${ARCH}" >&2
    exit 1
    ;;
esac

if [[ ! "${VERSION}" =~ '^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.-]+)?$' ]]; then
  echo "Invalid version: ${VERSION}" >&2
  exit 1
fi

if [[ ! "${BUILD_NUMBER}" =~ '^[0-9]+$' ]]; then
  echo "Invalid build number: ${BUILD_NUMBER}" >&2
  exit 1
fi

TARGET_APP="${OUTPUT_DIR}/VimScroll.app"
TARGET_ZIP="${OUTPUT_DIR}/${PACKAGE_NAME}"
TRIPLE="${ARCH}-apple-macosx13.0"

mkdir -p "${OUTPUT_DIR}" "${TARGET_APP}/Contents/MacOS" "${TARGET_APP}/Contents/Resources"

cd "${ROOT_DIR}"
swift build -c release --scratch-path "${BUILD_DIR}" --triple "${TRIPLE}"

ditto \
  "${BUILD_DIR}/${ARCH}-apple-macosx/release/VimScroll" \
  "${TARGET_APP}/Contents/MacOS/VimScroll"
ditto "${ROOT_DIR}/VimScroll/Info.plist" "${TARGET_APP}/Contents/Info.plist"

plutil -replace CFBundleShortVersionString -string "${VERSION}" "${TARGET_APP}/Contents/Info.plist"
plutil -replace CFBundleVersion -string "${BUILD_NUMBER}" "${TARGET_APP}/Contents/Info.plist"

codesign --force --deep --sign - "${TARGET_APP}"
codesign --verify --deep --strict "${TARGET_APP}"

BUILT_ARCHS="$(lipo -archs "${TARGET_APP}/Contents/MacOS/VimScroll")"
if [[ "${BUILT_ARCHS}" != "${ARCH}" ]]; then
  echo "Unexpected binary architecture: ${BUILT_ARCHS}" >&2
  exit 1
fi

ditto -c -k --sequesterRsrc --keepParent "${TARGET_APP}" "${TARGET_ZIP}"
unzip -tqq "${TARGET_ZIP}"

echo "Built ${TARGET_ZIP} (${ARCH}, version ${VERSION}, build ${BUILD_NUMBER})"
