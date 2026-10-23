import AppKit

/// Turns a copy of the user's Claude app into a separate profile app.
///
/// 1. Clone Claude.app into ~/Applications/Claude Profiles (an APFS clone, so it
///    shares disk blocks with the original and uses almost no extra space).
/// 2. Give the copy its own bundle ID, display name and icon, and make
///    ProfileLauncher its main executable so it always starts with the profile's
///    own data folder.
/// 3. Sign the copy ad-hoc (see Codesign).
///
/// The original Claude.app is only ever read.
struct ProfileAppBuilder {
    enum Step: Int, CaseIterable, Identifiable {
        case copy, nameAndIcon, sign, dataFolder, command

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .copy: return "Copy Claude.app"
            case .nameAndIcon: return "Set name and icon"
            case .sign: return "Sign the copy for this Mac"
            case .dataFolder: return "Create a private data folder"
            case .command: return "Create terminal command"
            }
        }

        var detail: String {
            switch self {
            case .copy: return "A space-saving copy of your installed Claude"
            case .nameAndIcon: return "Its own name, color and letter badge"
            case .sign: return "So macOS lets it open"
            case .dataFolder: return "Its own sign-in, chats and settings"
            case .command: return "Claude Code with its own sign-in, in ~/.local/bin"
            }
        }
    }

    enum BuildError: LocalizedError {
        case claudeNotFound
        case launcherNotFound
        case unsafeLocation(URL)

        var errorDescription: String? {
            switch self {
            case .claudeNotFound:
                return "Claude isn't installed. Install the Claude desktop app in /Applications first."
            case .launcherNotFound:
                return "ProfileLauncher is missing from this app. Reinstall Multi Profile for Claude."
            case .unsafeLocation(let url):
                return "Refusing to change \(url.path): it is outside ~/Applications/Claude Profiles."
            }
        }
    }

    static let lsregister = "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"

    /// Defaults to the launcher bundled with this app.
    var launcherURL: URL? = ProfileAppBuilder.bundledLauncher()

    /// Packaged app: Contents/Helpers/ProfileLauncher. During `swift run`: next to the executable.
    static func bundledLauncher() -> URL? {
        let packaged = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/ProfileLauncher")
        if FileManager.default.isExecutableFile(atPath: packaged.path) { return packaged }
        if let sibling = Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("ProfileLauncher"),
           FileManager.default.isExecutableFile(atPath: sibling.path) {
            return sibling
        }
        return nil
    }

    /// Creates (or recreates) the profile app and returns the Claude version it was built from.
    /// `oldAppURL` is removed first when a rename moves the app.
    func build(
        _ profile: Profile,
        baseIcon: NSImage,
        replacing oldAppURL: URL? = nil,
        progress: (Step) -> Void
    ) throws -> String {
        let fm = FileManager.default
        guard let source = Paths.claudeApp() else { throw BuildError.claudeNotFound }
        guard let launcher = launcherURL else { throw BuildError.launcherNotFound }
        let version = Paths.infoValue(source, "CFBundleShortVersionString") ?? "unknown"
        let target = profile.appURL
        guard Paths.isManagedAppLocation(target) else { throw BuildError.unsafeLocation(target) }

        progress(.copy)
        if let oldAppURL, oldAppURL.standardizedFileURL != target.standardizedFileURL,
           Paths.isManagedAppLocation(oldAppURL), fm.fileExists(atPath: oldAppURL.path) {
            try fm.removeItem(at: oldAppURL)
        }
        if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
        try fm.createDirectory(at: Paths.profileAppsDirectory, withIntermediateDirectories: true)
        do {
            try Shell.run("/bin/cp", ["-c", "-R", source.path, target.path])
        } catch {
            // Not on APFS (or cloning failed): fall back to a normal copy.
            try? fm.removeItem(at: target)
            try Shell.run("/usr/bin/ditto", [source.path, target.path])
        }
        _ = try? Shell.capture("/usr/bin/xattr", ["-dr", "com.apple.quarantine", target.path])

        progress(.nameAndIcon)
        try rewriteInfoPlist(of: target, for: profile)
        let launcherDestination = target.appendingPathComponent("Contents/MacOS/ProfileLauncher")
        try? fm.removeItem(at: launcherDestination)
        try fm.copyItem(at: launcher, to: launcherDestination)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: launcherDestination.path)
        try writeIcon(for: profile, baseIcon: baseIcon, in: target)

        progress(.sign)
        try sign(target, profile: profile)

        progress(.dataFolder)
        try fm.createDirectory(at: profile.desktopDataDirectory, withIntermediateDirectories: true)
        register(target)

        return version
    }

    /// Redraws the icon after a color change without copying the app again.
    func updateIcon(_ profile: Profile, baseIcon: NSImage) throws {
        let target = profile.appURL
        guard Paths.isManagedAppLocation(target) else { throw BuildError.unsafeLocation(target) }
        try writeIcon(for: profile, baseIcon: baseIcon, in: target)
        let entitlements = try Codesign.portableEntitlements(of: target.appendingPathComponent("Contents/MacOS/Claude"))
        defer { entitlements.map { try? FileManager.default.removeItem(at: $0) } }
        try Codesign.signAdHoc(target, identifier: profile.bundleID, entitlements: entitlements)
        try Codesign.verify(target)
        register(target)
    }

    // MARK: Steps

    private func rewriteInfoPlist(of app: URL, for profile: Profile) throws {
        let plistURL = app.appendingPathComponent("Contents/Info.plist")
        let data = try Data(contentsOf: plistURL)
        guard var info = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw CocoaError(.propertyListReadCorrupt)
        }
        info["CFBundleIdentifier"] = profile.bundleID
        info["CFBundleDisplayName"] = profile.displayName
        info["CFBundleExecutable"] = "ProfileLauncher"
        info["CFBundleIconFile"] = "profile.icns"
        // Otherwise macOS keeps showing the original icon from the asset catalog.
        info.removeValue(forKey: "CFBundleIconName")
        // CFBundleName stays as is: Electron uses it to find its helper apps.
        info[ProfileInfoKey.dataDirectory] = profile.desktopDataDirectory.path
        info[ProfileInfoKey.profileID] = profile.id.uuidString
        info[ProfileInfoKey.managedBy] = AppInfo.name
        let output = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try output.write(to: plistURL, options: .atomic)
    }

    private func writeIcon(for profile: Profile, baseIcon: NSImage, in app: URL) throws {
        let destination = app.appendingPathComponent("Contents/Resources/profile.icns")
        try IconRenderer.writeProfileIcns(base: baseIcon, color: profile.nsColor, letter: profile.letter, to: destination)
    }

    private func sign(_ app: URL, profile: Profile) throws {
        let claudeBinary = app.appendingPathComponent("Contents/MacOS/Claude")
        let entitlements = try Codesign.portableEntitlements(of: claudeBinary)
        defer { entitlements.map { try? FileManager.default.removeItem(at: $0) } }

        // Inside out: the real binary first, then the bundle (which signs ProfileLauncher as its
        // main executable). The helper apps and frameworks keep their original signatures.
        try Codesign.signAdHoc(claudeBinary, identifier: profile.bundleID, entitlements: entitlements)
        try Codesign.signAdHoc(app, identifier: profile.bundleID, entitlements: entitlements)
        try Codesign.verify(app)
    }

    /// Tells Launch Services about the new app so the Dock and Spotlight pick up its name and icon.
    private func register(_ app: URL) {
        _ = try? Shell.capture(Self.lsregister, ["-f", app.path])
        _ = try? Shell.capture("/usr/bin/touch", [app.path])
    }
}
