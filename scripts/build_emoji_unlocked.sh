#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
    if [ -x "${HOME}/Documents/Dev-portal/flutter/bin/flutter" ]; then
        export PATH="${HOME}/Documents/Dev-portal/flutter/bin:${PATH}"
    else
        echo "Error: Flutter is not on PATH and the local Flutter SDK was not found." >&2
        exit 1
    fi
fi

BUILD_ROOT="${PWD}/build/emoji-unlocked"
OUTPUT_DIR="${PWD}/build/releases"
VERSION="$(sed -n 's/^version: *\([0-9][^+ ]*\).*/\1/p' pubspec.yaml | head -n 1)"

if [ -z "${VERSION}" ]; then
    echo "Error: could not read the Omoji version from pubspec.yaml." >&2
    exit 1
fi

echo "Building Omoji with emoji selection unlocked and premium features gated..."
flutter build linux --release \
    --dart-define=OMOJI_DEVELOPER_BUILD=false \
    --dart-define=OMOJI_EMOJIS_UNLOCKED=true

FLUTTER_BUNDLE="${PWD}/build/linux/x64/release/bundle"
if [ ! -x "${FLUTTER_BUNDLE}/omoji" ]; then
    echo "Error: expected Omoji bundle was not created at ${FLUTTER_BUNDLE}." >&2
    exit 1
fi

BUNDLE_DIR="${BUILD_ROOT}/bundle"
mkdir -p "${BUNDLE_DIR}"
cp -r "${FLUTTER_BUNDLE}/." "${BUNDLE_DIR}/"
mkdir -p "${BUNDLE_DIR}/lib/scripts" "${BUNDLE_DIR}/lib/data" "${OUTPUT_DIR}"
cp scripts/emoji_prediction_daemon.py scripts/omoji_paste.py "${BUNDLE_DIR}/lib/scripts/"
cp -r lib/data/. "${BUNDLE_DIR}/lib/data/"

ARCHIVE="${OUTPUT_DIR}/omoji-${VERSION}-emoji-unlocked-linux-x64.tar.gz"
tar -czf "${ARCHIVE}" -C "${BUNDLE_DIR}" .

echo "Emoji-unlocked build created: ${ARCHIVE}"
echo "Unpacked bundle: ${BUNDLE_DIR}"
