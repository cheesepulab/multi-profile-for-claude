#!/bin/bash
# Builds the app and installs it into ~/Applications, then opens it.
set -euo pipefail

cd "$(dirname "$0")/.."
source scripts/config.sh

APP="dist/${APP_NAME}.app"
DEST="$HOME/Applications/${APP_NAME}.app"

scripts/build.sh

# Quit a running copy first so it can be replaced.
osascript -e "tell application id \"${BUNDLE_ID}\" to quit" >/dev/null 2>&1 || true

mkdir -p "$HOME/Applications"
rm -rf "$DEST"
ditto "$APP" "$DEST"
echo "Installed $DEST"
open "$DEST"
