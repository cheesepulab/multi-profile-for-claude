# Multi Profile for Claude

**English** · [Tiếng Việt](README.vi.md)

Run several Claude accounts side by side on your Mac — work, personal, a client — each in its own app with its own sign-in, chats and settings. Optionally get a terminal command per profile, such as `claude-work`, that runs Claude Code with that profile's account.

[![Donate via VietQR](https://img.shields.io/badge/Donate-VietQR-2563EB)](DONATE.md)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)
![License: MIT](https://img.shields.io/badge/license-MIT-green)

[![Multi Profile for Claude intro video: click to watch on YouTube](https://img.youtube.com/vi/W8z22g18PC8/maxresdefault.jpg)](https://www.youtube.com/watch?v=W8z22g18PC8)

▶ [Watch the 30-second intro on YouTube](https://www.youtube.com/watch?v=W8z22g18PC8)

## Features

- **One app per account.** Each profile is its own Mac app (`Claude Work`, `Claude Personal`…) with its own Dock icon, Cmd-Tab entry, Spotlight result and colored letter badge. Open as many at once as you like.
- **Your original Claude stays as it is.** It becomes the "Default" profile and is never changed.
- **Terminal commands.** `claude-work` starts Claude Code signed in to your Work account; plain `claude` keeps using your Default account. Every `claude` option works, e.g. `claude-work -c`.
- **Menu bar switcher.** See which profiles are running, bring one to the front, or open its Claude Code in Terminal.
- **Guided sign-in** that sends the browser's sign-in link to the right profile.
- **Light and dark mode**, following macOS or set by hand.
- **Private.** No account, no analytics, no network requests. Everything stays on your Mac.

## Install

Requires macOS 13 Ventura or later and the [Claude desktop app](https://claude.ai/download) in `/Applications`.

### Homebrew (recommended)

```bash
brew install --cask manhduc-nguyen/tap/multi-profile-for-claude
```

The app isn't notarized by Apple (it's a free project), so the cask clears the download quarantine flag after installing. You can read [the cask](https://github.com/manhduc-nguyen/homebrew-tap/blob/main/Casks/multi-profile-for-claude.rb) before installing.

### Download

1. Download the latest `Multi-Profile-for-Claude-<version>.zip` from [Releases](https://github.com/manhduc-nguyen/multi-profile-for-claude/releases) and move the app to `/Applications`.
2. Because the app isn't notarized, macOS blocks the first launch. Either run
   ```bash
   xattr -dr com.apple.quarantine "/Applications/Multi Profile for Claude.app"
   ```
   or try to open it once, then go to **System Settings → Privacy & Security** and click **Open Anyway**.

### Build from source

Needs Xcode 16 or later (or its command line tools with Swift 6).

```bash
git clone https://github.com/manhduc-nguyen/multi-profile-for-claude.git
cd multi-profile-for-claude
scripts/install.sh
```

`install.sh` builds the app and copies it to `~/Applications`. Apps you build yourself aren't quarantined, so they open without a warning.

## Getting started

1. Click the profiles icon in the menu bar and choose **New Profile…**.
2. Enter a name (for example "Work"), pick a color and keep **Also create a terminal command** checked.
3. Choose **Open and Sign In**. While the sign-in assistant is open, sign-in links from your browser go to the new profile.
   - If your browser is already signed in to claude.ai with a different account, sign out there first or use a private window.
   - macOS asks once whether the profile may use "Claude Safe Storage". Enter your Mac password and choose **Always Allow**.
4. In Terminal, run `claude-work` and sign in to Claude Code with the same account.

## How it works

- A profile app is an APFS clone of your installed `Claude.app` in `~/Applications/Claude Profiles`, so it uses almost no extra disk space.
- The copy gets its own bundle ID, display name and icon, and a tiny launcher (`ProfileLauncher`) that starts Claude with `--user-data-dir` pointing at the profile's folder in `~/Library/Application Support/MultiProfileForClaude/Profiles/<name>/Desktop`.
- Because the copy is modified, it's re-signed ad-hoc for your Mac. Entitlements that only work under the original developer's signature are left out.
- Terminal commands are small scripts in `~/.local/bin` that set `CLAUDE_CONFIG_DIR` to `…/Profiles/<name>/ClaudeCode` and run `claude` — the multiple-accounts setup described in Claude Code's own documentation.
- During **Sign In…**, the profile becomes the handler for `claude://` links. Links go back to your original Claude app when you finish, after 10 minutes, or when the app quits.

## Good to know

- **Sign-in options in profile apps:** email and Google sign-in work. Passkeys, hardware security keys and Microsoft single sign-on rely on the original app's signature, so use those in your Default profile.
- **After Claude updates itself,** profiles keep running the older copy until you rebuild them. The menu shows a **Rebuild** banner; your sign-ins and chats are kept.
- **Keychain prompt after a rebuild:** because each rebuild produces a new ad-hoc signature, macOS may ask for "Claude Safe Storage" access again.
- **`~/.local/bin` on PATH:** Claude Code's installer usually adds it. If Terminal says `command not found`, add `export PATH="$HOME/.local/bin:$PATH"` to `~/.zshrc`.

## Uninstall

- With Homebrew: `brew uninstall --cask multi-profile-for-claude` (add `--zap` to also delete profile apps and their data).
- Without Homebrew, from a clone of this repo: `scripts/uninstall.sh` (add `--data` to also delete profile data).
- From the app: **Profiles → Remove All Profiles…** removes every profile app and terminal command it created.

Terminal commands are only removed if they contain the line `# Created by Multi Profile for Claude`, so your own scripts are never touched.

## Development

```bash
swift build                     # debug build
swift test                      # unit tests
MPFC_INTEGRATION=1 swift test --filter IntegrationTests   # builds, starts and removes a real test profile
scripts/build.sh                # dist/Multi Profile for Claude.app (universal)
scripts/release.sh 0.1.0        # zip + Homebrew cask in dist/, prints the publish commands
```

Project settings (GitHub user, donation details, bundle ID) live in `scripts/config.sh`. Releases are signed ad-hoc by default. To sign with your free Personal Team "Apple Development" certificate instead, run `scripts/signing-identities.sh` to see each certificate's real team, then copy `scripts/config.local.sh.example` to `scripts/config.local.sh` and fill in `SIGN_IDENTITY` and `SIGN_TEAM_ID`. The build checks the signed app's team and stops on a mismatch.

## Support

Multi Profile for Claude is free. If it saves you some account juggling, you can **[support it with a donation](DONATE.md)**. Bug reports and pull requests are welcome too.

## License

[MIT](LICENSE)

---

Not affiliated with or endorsed by Anthropic. Claude is a trademark of Anthropic, PBC.
