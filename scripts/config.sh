# Project settings shared by the build and release scripts.
# Personal, machine-specific settings (such as SIGN_IDENTITY) go in scripts/config.local.sh,
# which is not committed. See scripts/config.local.sh.example.

APP_NAME="Multi Profile for Claude"
VERSION="${VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"

GITHUB_USER="manhduc-nguyen"
REPO_NAME="multi-profile-for-claude"
TAP_NAME="tap"                      # users install from $GITHUB_USER/$TAP_NAME (repo: homebrew-$TAP_NAME)
CASK_TOKEN="multi-profile-for-claude"

COPYRIGHT_NAME="Nguyen Manh Duc"

# Donations by bank transfer. The VietQR code for this account is Resources/donate-qr.png.
DONATE_BANK="TPBank"
DONATE_ACCOUNT_NAME="NGUYEN MANH DUC"
DONATE_ACCOUNT_NUMBER="0175 5161 701"

BUNDLE_ID="io.github.${GITHUB_USER}.multiprofileforclaude"
REPO_URL="https://github.com/${GITHUB_USER}/${REPO_NAME}"
DONATE_URL="${REPO_URL}/blob/main/DONATE.md"

# Leave empty for ad-hoc signing. Set it in scripts/config.local.sh to sign with your
# free "Apple Development" certificate instead.
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
