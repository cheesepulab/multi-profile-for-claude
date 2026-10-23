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

osascript -e "tell application id \"${BUNDLE_ID}\" to quit" >/dev/null 2>&1 || true

for app in "/Applications/${APP_NAME}.app" "$HOME/Applications/${APP_NAME}.app"; do
    if [ -d "$app" ] && [ "$(defaults read "$app/Contents/Info" CFBundleIdentifier 2>/dev/null)" = "$BUNDLE_ID" ]; then
        rm -rf "$app" && echo "Removed $app"
    fi
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
defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
echo "Done. Your original Claude app was not changed."
