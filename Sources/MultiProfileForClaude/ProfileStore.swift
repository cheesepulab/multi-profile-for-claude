import Foundation

/// Saves the profile list to ~/Library/Application Support/MultiProfileForClaude/profiles.json.
struct ProfileStore {
    private struct File: Codable {
        var version = 1
        var profiles: [Profile]
    }

    var url: URL { Paths.supportDirectory.appendingPathComponent("profiles.json") }

    func load() -> [Profile] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode(File.self, from: data))?.profiles ?? []
    }

    func save(_ profiles: [Profile]) throws {
        try FileManager.default.createDirectory(at: Paths.supportDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(File(profiles: profiles)).write(to: url, options: .atomic)
    }

    /// Fills in the bundle ID of profiles saved before it was stored. The profile app on disk
    /// is the source of truth; without one, the ID is made from the current prefix.
    static func withBundleIDs(_ profiles: [Profile]) -> (profiles: [Profile], changed: Bool) {
        var changed = false
        let filled = profiles.map { profile -> Profile in
            guard profile.storedBundleID == nil else { return profile }
            var updated = profile
            updated.storedBundleID = Paths.infoValue(profile.appURL, "CFBundleIdentifier")
                ?? Profile.bundleID(for: profile.slug)
            changed = true
            return updated
        }
        return (filled, changed)
    }
}
