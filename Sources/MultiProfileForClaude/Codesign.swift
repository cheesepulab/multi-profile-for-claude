import Foundation

/// Ad-hoc signing for profile apps.
///
/// Changing a profile app's Info.plist breaks the original signature, so the copy is
/// signed again "ad-hoc" (valid on this Mac only). Entitlements that only work under
/// the original developer's own signature must be left out, or macOS refuses to start
/// the app. All other entitlements (camera, microphone, JIT, virtualization…) are kept.
enum Codesign {
    static let tool = "/usr/bin/codesign"

    static func isRestricted(_ key: String) -> Bool {
        key == "keychain-access-groups"
            || key == "application-identifier"
            || key == "com.apple.application-identifier"
            || key.hasPrefix("com.apple.developer.")
    }

    /// Writes the binary's entitlements, minus restricted ones, to a temporary plist.
    static func portableEntitlements(of binary: URL) throws -> URL? {
        let result = try Shell.capture(tool, ["-d", "--entitlements", "-", "--xml", binary.path])
        guard result.status == 0, !result.stdout.isEmpty,
              let plist = try? PropertyListSerialization.propertyList(from: result.stdout, format: nil),
              let entitlements = plist as? [String: Any]
        else { return nil }

        let kept = entitlements.filter { !isRestricted($0.key) }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mpfc-entitlements-\(UUID().uuidString).plist")
        let data = try PropertyListSerialization.data(fromPropertyList: kept, format: .xml, options: 0)
        try data.write(to: url)
        return url
    }

    static func signAdHoc(_ url: URL, identifier: String, entitlements: URL?) throws {
        var arguments = ["--force", "--sign", "-", "--identifier", identifier]
        if let entitlements { arguments += ["--entitlements", entitlements.path] }
        arguments.append(url.path)
        try Shell.run(tool, arguments)
    }

    static func verify(_ url: URL) throws {
        try Shell.run(tool, ["--verify", "--deep", "--strict", url.path])
    }
}
