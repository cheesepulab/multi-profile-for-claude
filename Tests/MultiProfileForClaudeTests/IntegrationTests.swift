import AppKit
import XCTest
@testable import MultiProfileForClaude

/// Builds a real profile app from the installed Claude app, starts it, checks it, then removes it.
///
/// Opt-in, because it needs Claude installed and writes to ~/Applications/Claude Profiles,
/// ~/.local/bin and ~/Library/Application Support/MultiProfileForClaude:
///
///     MPFC_INTEGRATION=1 swift test --filter IntegrationTests
@MainActor
final class IntegrationTests: XCTestCase {
    private var profile = Profile(
        id: UUID(), name: "Selftest", colorHex: "#0F766E", slug: "mpfc-selftest",
        commandEnabled: true, commandName: nil, builtClaudeVersion: nil
    )
    private let commands = CLICommandInstaller()

    override func setUp() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["MPFC_INTEGRATION"] == "1",
                          "Set MPFC_INTEGRATION=1 to run the integration test")
        try XCTSkipUnless(Paths.claudeApp() != nil, "Claude is not installed")
    }

    override func tearDown() async throws {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: profile.bundleID)
        apps.forEach { $0.forceTerminate() }
        // Wait for it to exit so it can't write to its data folder after that is deleted.
        for _ in 0..<40 where !apps.allSatisfy(\.isTerminated) {
            try await Task.sleep(nanoseconds: 250_000_000)
        }
        try await Task.sleep(nanoseconds: 500_000_000)
        if let name = profile.commandName { commands.remove(name) }
        if Paths.isManagedAppLocation(profile.appURL) { try? FileManager.default.removeItem(at: profile.appURL) }
        try? FileManager.default.removeItem(at: profile.dataDirectory)
        _ = try? Shell.capture(ProfileAppBuilder.lsregister, ["-u", profile.appURL.path])
    }

    func testCreateStartAndRemoveProfile() async throws {
        let claude = try XCTUnwrap(Paths.claudeApp())
        let originalInfo = try XCTUnwrap(NSDictionary(contentsOf: claude.appendingPathComponent("Contents/Info.plist")))

        // Build
        var builder = ProfileAppBuilder()
        builder.launcherURL = try XCTUnwrap(builtLauncher(), "ProfileLauncher was not built")
        var steps: [ProfileAppBuilder.Step] = []
        let version = try builder.build(profile, baseIcon: NSWorkspace.shared.icon(forFile: claude.path)) { steps.append($0) }
        profile.builtClaudeVersion = version
        XCTAssertEqual(steps, [.copy, .nameAndIcon, .sign, .dataFolder])
        XCTAssertEqual(version, Paths.claudeVersion())

        // Signature, Info.plist and entitlements
        try Codesign.verify(profile.appURL)
        let info = try XCTUnwrap(NSDictionary(contentsOf: profile.appURL.appendingPathComponent("Contents/Info.plist")))
        XCTAssertEqual(info["CFBundleIdentifier"] as? String, profile.bundleID)
        XCTAssertEqual(info["CFBundleDisplayName"] as? String, "Claude Selftest")
        XCTAssertEqual(info["CFBundleName"] as? String, originalInfo["CFBundleName"] as? String)
        XCTAssertEqual(info["CFBundleExecutable"] as? String, "ProfileLauncher")
        XCTAssertEqual(info["CFBundleIconFile"] as? String, "profile.icns")
        XCTAssertNil(info["CFBundleIconName"])
        XCTAssertEqual(info[ProfileInfoKey.dataDirectory] as? String, profile.desktopDataDirectory.path)
        XCTAssertEqual(info["ElectronAsarIntegrity"] as? NSDictionary, originalInfo["ElectronAsarIntegrity"] as? NSDictionary)
        XCTAssertTrue(FileManager.default.fileExists(atPath: profile.appURL.appendingPathComponent("Contents/Resources/profile.icns").path))
        let entitlements = try Shell.run(Codesign.tool, ["-d", "--entitlements", "-", "--xml",
                                                         profile.appURL.appendingPathComponent("Contents/MacOS/Claude").path]).output
        XCTAssertFalse(entitlements.contains("keychain-access-groups"))
        XCTAssertFalse(entitlements.contains("team-identifier"))

        // The original app is untouched.
        XCTAssertEqual(Bundle(url: claude)?.bundleIdentifier, Paths.claudeBundleID)
        try Codesign.verify(claude)

        // Terminal command
        let name = commands.suggestedName(for: profile)
        try commands.install(profile, as: name)
        profile.commandName = name
        XCTAssertTrue(commands.isOurs(name))
        let attributes = try FileManager.default.attributesOfItem(atPath: commands.url(for: name).path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o755)
        let claudeCode = try Shell.capture("/bin/sh", ["-lc", "\(commands.terminalCommand(for: name)) --version"], timeout: 60)
        XCTAssertEqual(claudeCode.status, 0, claudeCode.errorOutput)
        XCTAssertTrue(claudeCode.output.contains("Claude Code"), claudeCode.output)

        // Start the profile app and check it runs as its own app with its own data folder.
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        let app = try await NSWorkspace.shared.openApplication(at: profile.appURL, configuration: configuration)
        XCTAssertEqual(app.bundleIdentifier, profile.bundleID)
        var dataFiles: [String] = []
        for _ in 0..<60 {
            dataFiles = (try? FileManager.default.contentsOfDirectory(atPath: profile.desktopDataDirectory.path)) ?? []
            if dataFiles.count > 3 { break }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        XCTAssertGreaterThan(dataFiles.count, 3, "the profile app did not write to its own data folder")
        XCTAssertFalse(app.isTerminated, "the profile app quit right after starting")
        let processes = try Shell.capture("/bin/ps", ["-p", "\(app.processIdentifier)", "-o", "command="]).output
        XCTAssertTrue(processes.contains("Contents/MacOS/Claude --user-data-dir=\(profile.desktopDataDirectory.path)"), processes)

        // Sign-in links go to the profile while signing in, then back to the original app.
        let router = SignInRouter()
        try await router.begin(profile)
        XCTAssertEqual(SignInRouter.currentHandler()?.standardizedFileURL.path, profile.appURL.standardizedFileURL.path)
        await router.finish()
        XCTAssertEqual(SignInRouter.currentHandler()?.standardizedFileURL.path, claude.standardizedFileURL.path)
    }

    /// The ProfileLauncher binary from this build (next to the test bundle).
    private func builtLauncher() -> URL? {
        let products = Bundle(for: Self.self).bundleURL.deletingLastPathComponent()
        let url = products.appendingPathComponent("ProfileLauncher")
        return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
    }
}
