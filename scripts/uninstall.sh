#!/bin/bash
# Removes Multi Profile for Claude, its profile apps and the terminal commands it created.
# Usage: scripts/uninstall.sh          keep profile data (chats and sign-ins)
#        scripts/uninstall.sh --data   also delete profile data
#
# Never touches the original Claude app or its data, and only removes terminal
# commands that carry the "Created by Multi Profile for Claude" marker.
set -euo pipefail

cd "$(dirname "$0")/.."
source scripts/config.sh

DELETE_DATA=false
[ "${1:-}" = "--data" ] && DELETE_DATA=true

MARKER="# Created by Multi Profile for Claude"
SUPPORT="$HOME/Library/Application Support/MultiProfileForClaude"
PROFILE_APPS="$HOME/Applications/Claude Profiles"

# The current bundle ID and the ones older builds used.
ALL_BUNDLE_IDS="$BUNDLE_ID ${LEGACY_BUNDLE_IDS:-}"

for id in $ALL_BUNDLE_IDS; do
    osascript -e "tell application id \"${id}\" to quit" >/dev/null 2>&1 || true
done

for app in "/Applications/${APP_NAME}.app" "$HOME/Applications/${APP_NAME}.app"; do
    [ -d "$app" ] || continue
    app_id="$(defaults read "$app/Contents/Info" CFBundleIdentifier 2>/dev/null || true)"
    for id in $ALL_BUNDLE_IDS; do
        if [ "$app_id" = "$id" ]; then
            rm -rf "$app" && echo "Removed $app"
        fi
    done
done

if [ -d "$PROFILE_APPS" ]; then
    for app in "$PROFILE_APPS"/*.app; do
        [ -d "$app" ] || continue
        if defaults read "$app/Contents/Info" MPFCManagedBy >/dev/null 2>&1; then
            rm -rf "$app" && echo "Removed $app"
        fi
    done
    rmdir "$PROFILE_APPS" 2>/dev/null || true
fi

if [ -d "$HOME/.local/bin" ]; then
    for cmd in "$HOME"/.local/bin/claude-*; do
        [ -f "$cmd" ] || continue
        if grep -qF "$MARKER" "$cmd"; then
            rm -f "$cmd" && echo "Removed $cmd"
        fi
    done
fi

if $DELETE_DATA; then
    rm -rf "$SUPPORT" && echo "Removed $SUPPORT"
else
    echo "Kept profile data in $SUPPORT (run with --data to delete it)."
fi
for id in $ALL_BUNDLE_IDS; do
    defaults delete "$id" >/dev/null 2>&1 || true
done
echo "Done. Your original Claude app was not changed."
