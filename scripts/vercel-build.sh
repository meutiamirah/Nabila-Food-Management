#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="3.47.4"
FLUTTER_DIR="${HOME}/.cache/flutter-${FLUTTER_VERSION}"
FLUTTER_ARCHIVE="${TMPDIR:-/tmp}/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

if ! command -v flutter >/dev/null 2>&1; then
  mkdir -p "$FLUTTER_DIR"
  curl --fail --location --retry 3 "$FLUTTER_URL" --output "$FLUTTER_ARCHIVE"
  tar -xf "$FLUTTER_ARCHIVE" --strip-components=1 -C "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"
flutter --version
flutter pub get
flutter build web --release

test -f build/web/index.html
