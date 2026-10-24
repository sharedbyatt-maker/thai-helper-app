#!/usr/bin/env bash
# Cloudflare Pages: root directory is the repo root; output flutter_app/build/web.
set -euo pipefail
cd "$(dirname "$0")/.."
export FLUTTER_SUPPRESS_ANALYTICS=true
export DART_SUPPRESS_ANALYTICS=true
BAHTZAY_FLUTTER_VERSION=3.47.7
BAHTZAY_FLUTTER_DIR="${TMPDIR:-/tmp}/bahtzay-flutter-${BAHTZAY_FLUTTER_VERSION}"
if ! command -v flutter >/dev/null 2>&1; then
  if [ ! -x "$BAHTZAY_FLUTTER_DIR/bin/flutter" ]; then
    git clone --depth 1 --branch "$BAHTZAY_FLUTTER_VERSION" https://github.com/flutter/flutter.git "$BAHTZAY_FLUTTER_DIR"
  fi
  export PATH="$BAHTZAY_FLUTTER_DIR/bin:$PATH"
fi
BAHTZAY_BUILD_URL="${PUBLIC_APP_URL:-${CF_PAGES_URL:-}}"
if [ -z "$BAHTZAY_BUILD_URL" ]; then
  echo 'PUBLIC_APP_URL or Cloudflare CF_PAGES_URL is required.' >&2
  exit 1
fi
BAHTZAY_API="${RATES_API:-https://bahtzay-rates.muddyhinny2048.chatgpt.site}"
python3 scripts/fetch_fonts.py
node --test tests/push_browser.test.cjs tests/branding.test.cjs
(
  cd flutter_app
  flutter pub get
  flutter analyze
  flutter test
  flutter build web --release --no-web-resources-cdn --base-href / --dart-define="RATES_API=$BAHTZAY_API" --dart-define="PUBLIC_APP_URL=$BAHTZAY_BUILD_URL"
)
node scripts/prepare_web_push.mjs flutter_app/build/web
node scripts/stamp_cloudflare_metadata.mjs flutter_app/build/web "$BAHTZAY_BUILD_URL"
