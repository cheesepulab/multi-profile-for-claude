import AppKit
import SwiftUI

struct Profile: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var colorHex: String
    /// Fixed when the profile is created; names the data folder and bundle ID.
    var slug: String
    var commandEnabled: Bool
    /// The terminal command, for example `claude-work`. Nil while the command is off.
    var commandName: String?
    /// Claude version the profile app was last built from.
    var builtClaudeVersion: String?
    /// Saved when the profile is created, so the app always finds its own profile apps,
    /// even when it runs with a different bundle ID prefix (for example from Xcode).
    var storedBundleID: String? = nil

    enum CodingKeys: String, CodingKey {
        case id, name, colorHex, slug, commandEnabled, commandName, builtClaudeVersion
        case storedBundleID = "bundleID"
    }

    /// The profile app's bundle ID. Profiles saved before this was stored fall back to the
    /// current prefix until `ProfileStore.withBundleIDs` fills it in.
    var bundleID: String { storedBundleID ?? Self.bundleID(for: slug) }

    static func bundleID(for slug: String) -> String { "\(AppInfo.bundleIDPrefix).profile.\(slug)" }

    var letter: String {
        guard let first = name.trimmingCharacters(in: .whitespacesAndNewlines).first else { return "?" }
        return String(first).uppercased()
    }

    var displayName: String { "Claude \(name)" }

    var appURL: URL {
        let safeName = displayName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return Paths.profileAppsDirectory.appendingPathComponent("\(safeName).app", isDirectory: true)
    }

    var dataDirectory: URL { Paths.profilesDataDirectory.appendingPathComponent(slug, isDirectory: true) }
    var desktopDataDirectory: URL { dataDirectory.appendingPathComponent("Desktop", isDirectory: true) }
    var claudeCodeDirectory: URL { dataDirectory.appendingPathComponent("ClaudeCode", isDirectory: true) }

    var defaultCommandName: String { "claude-\(slug)" }

    var color: Color { Color(hex: colorHex) }
    var nsColor: NSColor { NSColor(hex: colorHex) }

    func needsRebuild(currentClaudeVersion: String?) -> Bool {
        guard let current = currentClaudeVersion else { return false }
        return builtClaudeVersion != current
    }
}

enum Slug {
    /// "Client – Acme" becomes "client-acme"; "Công việc" becomes "cong-viec".
    static func make(from name: String) -> String {
        let folded = name
            .replacingOccurrences(of: "đ", with: "d")
            .replacingOccurrences(of: "Đ", with: "D")
            .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        var slug = ""
        var lastWasDash = false
        for scalar in folded.unicodeScalars {
            if ("a"..."z").contains(scalar) || ("0"..."9").contains(scalar) {
                slug.unicodeScalars.append(scalar)
                lastWasDash = false
            } else if !lastWasDash && !slug.isEmpty {
                slug.append("-")
                lastWasDash = true
            }
        }
        while slug.hasSuffix("-") { slug.removeLast() }
        return slug.isEmpty ? "profile" : String(slug.prefix(40))
    }

    static func unique(_ base: String, taken: Set<String>) -> String {
        guard taken.contains(base) else { return base }
        var n = 2
        while taken.contains("\(base)-\(n)") { n += 1 }
        return "\(base)-\(n)"
    }
}

/// Profile colors. White letters on each of them meet a 4.5:1 contrast ratio.
enum ProfilePalette {
    struct Swatch: Identifiable, Hashable {
        let name: String
        let hex: String
        var id: String { hex }
    }

    static let swatches: [Swatch] = [
        Swatch(name: "Blue", hex: "#2563EB"),
        Swatch(name: "Orange", hex: "#B45309"),
        Swatch(name: "Green", hex: "#15803D"),
        Swatch(name: "Purple", hex: "#7C3AED"),
        Swatch(name: "Pink", hex: "#BE185D"),
        Swatch(name: "Teal", hex: "#0F766E"),
        Swatch(name: "Red", hex: "#C42B1C"),
        Swatch(name: "Graphite", hex: "#52525B"),
    ]

    static let defaultProfileHex = "#52525B"

    /// The first color not used yet, so new profiles are easy to tell apart.
    static func suggestedHex(excluding used: [String]) -> String {
        swatches.first { !used.contains($0.hex) }?.hex ?? swatches[0].hex
    }
}

extension NSColor {
    convenience init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&value)
        self.init(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    init(hex: String) { self.init(nsColor: NSColor(hex: hex)) }
}
