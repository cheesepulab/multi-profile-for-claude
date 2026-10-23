#!/bin/bash
# Builds a release: the signed app, a zip for GitHub Releases and the Homebrew cask.
# It publishes nothing; it prints the commands to run next.
# Usage: scripts/release.sh 0.1.0
set -euo pipefail

cd "$(dirname "$0")/.."
if [ $# -ne 1 ]; then
    echo "usage: scripts/release.sh <version>   (for example 0.1.0)" >&2
    exit 2
fi
export VERSION="$1"
source scripts/config.sh
[ -f scripts/config.local.sh ] && source scripts/config.local.sh

case "$COPYRIGHT_NAME" in
    ""|"YOUR NAME") echo "warning: set COPYRIGHT_NAME in scripts/config.sh." >&2 ;;
esac

scripts/build.sh

ZIP="dist/Multi-Profile-for-Claude-${VERSION}.zip"
CASK="dist/${CASK_TOKEN}.rb"

echo "==> Zipping"
rm -f "$ZIP"
ditto -c -k --keepParent "dist/${APP_NAME}.app" "$ZIP"
SHA256="$(shasum -a 256 "$ZIP" | awk '{print $1}')"

echo "==> Writing cask"
sed -e "s|@CASK_TOKEN@|${CASK_TOKEN}|g" \
    -e "s|@VERSION@|${VERSION}|g" \
    -e "s|@SHA256@|${SHA256}|g" \
    -e "s|@GITHUB_USER@|${GITHUB_USER}|g" \
    -e "s|@REPO_NAME@|${REPO_NAME}|g" \
    -e "s|@BUNDLE_ID@|${BUNDLE_ID}|g" \
    packaging/homebrew/${CASK_TOKEN}.rb.template > "$CASK"

cat <<EOF

Release ${VERSION} is ready:
  ${ZIP}
  sha256 ${SHA256}
  ${CASK}

Next steps (nothing has been uploaded):
  1. git tag v${VERSION} && git push origin v${VERSION}
  2. gh release create v${VERSION} "${ZIP}" --repo ${GITHUB_USER}/${REPO_NAME} --title "${VERSION}" --generate-notes
  3. Copy ${CASK} to Casks/${CASK_TOKEN}.rb in ${GITHUB_USER}/homebrew-${TAP_NAME}, then:
       brew style --fix Casks/${CASK_TOKEN}.rb
       git commit -am "${CASK_TOKEN} ${VERSION}" && git push
       brew audit --cask --online ${GITHUB_USER}/${TAP_NAME}/${CASK_TOKEN}
  4. Install it like a user would:
       brew install --cask ${GITHUB_USER}/${TAP_NAME}/${CASK_TOKEN}
EOF
