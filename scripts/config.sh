# Project settings shared by the build and release scripts.
# Personal, machine-specific settings (such as SIGN_IDENTITY) go in scripts/config.local.sh,
# which is not committed. See scripts/config.local.sh.example.

APP_NAME="Multi Profile for Claude"
VERSION="${VERSION:-0.1.1}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"

REPO_OWNER="cheesepulab"             # GitHub owner of this repo and its releases
REPO_NAME="multi-profile-for-claude"
TAP_OWNER="cheesepulab"             # users install from $TAP_OWNER/$TAP_NAME (repo: $TAP_OWNER/homebrew-$TAP_NAME)
TAP_NAME="tap"
CASK_TOKEN="multi-profile-for-claude"

COPYRIGHT_NAME="Nguyen Manh Duc"

# Donations by bank transfer. The VietQR code for this account is Resources/donate-qr.png.
DONATE_BANK="TPBank"
DONATE_ACCOUNT_NAME="NGUYEN MANH DUC"
DONATE_ACCOUNT_NUMBER="0175 5161 701"

# Changing it makes macOS treat the app as a new one. Profiles keep working (each stores its
# own bundle ID), but app settings reset once. Keep LEGACY_BUNDLE_IDS so uninstall finds old builds.
BUNDLE_ID="io.github.cheesepulab.multiprofileforclaude"
LEGACY_BUNDLE_IDS="io.github.manhduc-nguyen.multiprofileforclaude"
REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}"
DONATE_URL="${REPO_URL}/blob/main/DONATE.md"

# Leave empty for ad-hoc signing. Set it in scripts/config.local.sh to sign with your
# free "Apple Development" certificate instead.
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
