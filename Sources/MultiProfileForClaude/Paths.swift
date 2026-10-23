import AppKit

enum Paths {
    static let claudeBundleID = "com.anthropic.claudefordesktop"

    static var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    /// Settings and per-profile data: ~/Library/Application Support/MultiProfileForClaude
    static var supportDirectory: URL {
        home.appendingPathComponent("Library/Application Support/MultiProfileForClaude", isDirectory: true)
    }

    static var profilesDataDirectory: URL {
        supportDirectory.appendingPathComponent("Profiles", isDirectory: true)
    }

    /// Where profile apps are created: ~/Applications/Claude Profiles
    static var profileAppsDirectory: URL {
        home.appendingPathComponent("Applications/Claude Profiles", isDirectory: true)
    }

    /// Where terminal commands are created: ~/.local/bin
    static var commandDirectory: URL {
        home.appendingPathComponent(".local/bin", isDirectory: true)
    }

    /// The user's own Claude desktop app. It is only ever read, never changed.
    static func claudeApp() -> URL? {
        let candidates = [
            URL(fileURLWithPath: "/Applications/Claude.app"),
            home.appendingPathComponent("Applications/Claude.app"),
        ]
        for url in candidates where Bundle(url: url)?.bundleIdentifier == claudeBundleID {
            return url
        }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: claudeBundleID)
    }

    static func claudeVersion() -> String? {
        guard let url = claudeApp() else { return nil }
        return infoValue(url, "CFBundleShortVersionString")
    }

    /// Reads Info.plist straight from disk so the value is current after Claude updates itself.
    static func infoValue(_ appURL: URL, _ key: String) -> String? {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let info = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return info[key] as? String
    }

    /// True only for paths this app is allowed to create or delete apps in.
    static func isManagedAppLocation(_ url: URL) -> Bool {
        let parent = url.standardizedFileURL.deletingLastPathComponent().path
        return parent == profileAppsDirectory.standardizedFileURL.path && url.pathExtension == "app"
    }

    /// Shows a path with the home folder written as ~.
    static func abbreviated(_ url: URL) -> String {
        (url.path as NSString).abbreviatingWithTildeInPath
    }
}
