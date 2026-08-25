#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
BUILD_DIR="${SCRIPT_DIR}/build"
OUTPUT_DIR="${1:-${SCRIPT_DIR}/dist}"

mkdir -p "${BUILD_DIR}" "${OUTPUT_DIR}"

cd "${SCRIPT_DIR}"
TARGET_APP="${OUTPUT_DIR}/VimScroll.app"
TARGET_ZIP="${OUTPUT_DIR}/VimScroll-macOS.zip"
X86_BUILD_DIR="${BUILD_DIR}/SwiftBuild-x86_64"
ARM_BUILD_DIR="${BUILD_DIR}/SwiftBuild-arm64"

swift build -c release --scratch-path "${X86_BUILD_DIR}" --triple x86_64-apple-macosx13.0
swift build -c release --scratch-path "${ARM_BUILD_DIR}" --triple arm64-apple-macosx13.0

rm -rf "${TARGET_APP}"
rm -f "${TARGET_ZIP}"
mkdir -p "${TARGET_APP}/Contents/MacOS" "${TARGET_APP}/Contents/Resources"
lipo -create \
  "${X86_BUILD_DIR}/x86_64-apple-macosx/release/VimScroll" \
  "${ARM_BUILD_DIR}/arm64-apple-macosx/release/VimScroll" \
  -output "${TARGET_APP}/Contents/MacOS/VimScroll"
ditto "${SCRIPT_DIR}/VimScroll/Info.plist" "${TARGET_APP}/Contents/Info.plist"
codesign --force --deep --sign - "${TARGET_APP}"
ditto -c -k --sequesterRsrc --keepParent "${TARGET_APP}" "${TARGET_ZIP}"

echo "Built: ${TARGET_APP}"
echo "Archive: ${TARGET_ZIP}"
