import AppKit
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published private(set) var profiles: [Profile] = []
    @Published private(set) var runningBundleIDs: Set<String> = []
    /// The Claude app (original or profile) that was most recently in front.
    @Published private(set) var lastFrontBundleID: String?
    @Published private(set) var claudeVersion: String?
    @Published private(set) var busyProfileIDs: Set<UUID> = []
    @Published private(set) var commandsOnPath = true

    @Published var showNewProfile = false
    @Published var showRemoveAll = false
    @Published var signInProfileID: UUID?
    @Published var selection: SidebarItem? = .defaultApp
    @Published var errorMessage: String?

    let signInRouter = SignInRouter()
    private let store = ProfileStore()
    private let builder = ProfileAppBuilder()
    let commands = CLICommandInstaller()

    private init() {
        let loaded = ProfileStore.withBundleIDs(store.load())
        profiles = loaded.profiles
        if loaded.changed { try? store.save(profiles) }
        refreshClaudeVersion()
        refreshRunningApps()
        observeWorkspace()
        signInRouter.restoreIfNeeded()
        refreshPathStatus()
    }

    // MARK: Lookups

    func profile(_ id: UUID) -> Profile? { profiles.first { $0.id == id } }

    func isRunning(_ profile: Profile) -> Bool { runningBundleIDs.contains(profile.bundleID) }
    var isDefaultRunning: Bool { runningBundleIDs.contains(Paths.claudeBundleID) }
    func isBusy(_ profile: Profile) -> Bool { busyProfileIDs.contains(profile.id) }
    func needsRebuild(_ profile: Profile) -> Bool { profile.needsRebuild(currentClaudeVersion: claudeVersion) }
    var profilesNeedingRebuild: [Profile] { profiles.filter(needsRebuild) }

    var frontProfile: Profile? { profiles.first { $0.bundleID == lastFrontBundleID } }
    var isDefaultInFront: Bool { lastFrontBundleID == Paths.claudeBundleID }
    var isClaudeInstalled: Bool { Paths.claudeApp() != nil }

    var claudeIcon: NSImage {
        if let url = Paths.claudeApp() { return NSWorkspace.shared.icon(forFile: url.path) }
        return NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
    }

    // MARK: Workspace tracking

    private func observeWorkspace() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refreshRunningApps() }
            }
        }
        center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundleID = app?.bundleIdentifier
            Task { @MainActor in self?.noteActivated(bundleID) }
        }
    }

    private func noteActivated(_ bundleID: String?) {
        guard let bundleID else { return }
        if bundleID == Paths.claudeBundleID || profiles.contains(where: { $0.bundleID == bundleID }) {
            lastFrontBundleID = bundleID
        }
        if bundleID == Paths.claudeBundleID { refreshClaudeVersion() }
    }

    func refreshRunningApps() {
        runningBundleIDs = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        if let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier { noteActivated(front) }
    }

    func refreshClaudeVersion() {
        claudeVersion = Paths.claudeVersion()
    }

    func refreshPathStatus() {
        let commands = commands
        Task.detached {
            let onPath = commands.commandDirectoryIsOnPath()
            await MainActor.run { AppModel.shared.commandsOnPath = onPath }
        }
    }

    // MARK: Opening

    func openDefault() {
        guard let url = Paths.claudeApp() else { return report(ProfileAppBuilder.BuildError.claudeNotFound) }
        bringToFront(url, bundleID: Paths.claudeBundleID)
    }

    func open(_ profile: Profile) {
        guard FileManager.default.fileExists(atPath: profile.appURL.path) else {
            errorMessage = "\(profile.displayName) is missing. Choose Rebuild to create it again."
            return
        }
        bringToFront(profile.appURL, bundleID: profile.bundleID)
    }

    /// Starts the app, or brings it forward if it runs already.
    ///
    /// Always goes through Launch Services: it activates a running app and sends it a reopen
    /// event, so Claude shows its window again even after the window was closed. Calling
    /// `activate()` on the running app instead is ignored on macOS 14 and later when a menu
    /// bar app asks.
    private func bringToFront(_ appURL: URL, bundleID: String) {
        if #available(macOS 14.0, *) {
            NSApp.yieldActivation(toApplicationWithBundleIdentifier: bundleID)
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
            if let error { Task { @MainActor in self.report(error) } }
        }
    }

    func revealDataFolder(_ profile: Profile) {
        try? FileManager.default.createDirectory(at: profile.dataDirectory, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([profile.dataDirectory])
    }

    func openTerminal(for profile: Profile?) {
        do {
            if let profile, let name = profile.commandName {
                try commands.openInTerminal(commands.terminalCommand(for: name))
            } else {
                try commands.openInTerminal("claude")
            }
        } catch {
            report(error)
        }
    }

    // MARK: Creating and changing profiles

    /// Creates a profile and its app. `progress` reports each build step on the main actor.
    func createProfile(
        name: String,
        colorHex: String,
        commandEnabled: Bool,
        progress: @escaping (ProfileAppBuilder.Step) -> Void
    ) async throws -> Profile {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let taken = Set(profiles.map(\.slug))
        let slug = Slug.unique(Slug.make(from: trimmed), taken: taken)
        var profile = Profile(
            id: UUID(),
            name: trimmed,
            colorHex: colorHex,
            slug: slug,
            commandEnabled: commandEnabled,
            commandName: nil,
            builtClaudeVersion: nil,
            storedBundleID: Profile.bundleID(for: slug)
        )
        busyProfileIDs.insert(profile.id)
        defer { busyProfileIDs.remove(profile.id) }

        profile.builtClaudeVersion = try await runBuild(profile, progress: progress)
        if commandEnabled {
            progress(.command)
            let commandName = commands.suggestedName(for: profile)
            try commands.install(profile, as: commandName)
            profile.commandName = commandName
        }
        profiles.append(profile)
        try save()
        selection = .profile(profile.id)
        return profile
    }

    func rebuild(_ profile: Profile) async {
        await perform(on: profile) { model in
            var updated = profile
            updated.builtClaudeVersion = try await model.runBuild(updated, progress: { _ in })
            if let name = updated.commandName, updated.commandEnabled {
                try model.commands.install(updated, as: name)
            }
            model.replace(updated)
        }
    }

    func rebuildAll() async {
        for profile in profilesNeedingRebuild where !isRunning(profile) {
            await rebuild(profile)
        }
    }

    func rename(_ profile: Profile, to newName: String) async {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != profile.name else { return }
        await perform(on: profile) { model in
            var updated = profile
            updated.name = trimmed
            updated.builtClaudeVersion = try await model.runBuild(updated, replacing: profile.appURL, progress: { _ in })
            if let name = updated.commandName, updated.commandEnabled {
                try model.commands.install(updated, as: name)
            }
            model.replace(updated)
        }
    }

    func setColor(_ profile: Profile, hex: String) async {
        guard hex != profile.colorHex else { return }
        var updated = profile
        updated.colorHex = hex
        replace(updated)
        await perform(on: updated) { model in
            let builder = model.builder
            let icon = model.claudeIcon
            try await Task.detached { try builder.updateIcon(updated, baseIcon: icon) }.value
        }
    }

    func setCommandEnabled(_ profile: Profile, _ enabled: Bool) {
        var updated = profile
        do {
            if enabled {
                let name = profile.commandName ?? commands.suggestedName(for: profile)
                try commands.install(profile, as: name)
                updated.commandName = name
            } else if let name = profile.commandName {
                commands.remove(name)
                updated.commandName = nil
            }
            updated.commandEnabled = enabled
            replace(updated)
            refreshPathStatus()
        } catch {
            report(error)
        }
    }

    func delete(_ profile: Profile, deleteData: Bool) async {
        await perform(on: profile) { model in
            let fm = FileManager.default
            if Paths.isManagedAppLocation(profile.appURL), fm.fileExists(atPath: profile.appURL.path) {
                try fm.removeItem(at: profile.appURL)
            }
            if let name = profile.commandName { model.commands.remove(name) }
            if deleteData, fm.fileExists(atPath: profile.dataDirectory.path) {
                try fm.removeItem(at: profile.dataDirectory)
            }
            _ = try? Shell.capture(ProfileAppBuilder.lsregister, ["-u", profile.appURL.path])
            model.profiles.removeAll { $0.id == profile.id }
            if model.selection == .profile(profile.id) { model.selection = .defaultApp }
            try model.save()
        }
    }

    /// Removes every profile app and terminal command, optionally with their data.
    func removeAllProfiles(deleteData: Bool) async {
        for profile in profiles {
            _ = await quitIfRunning(profile)
            await delete(profile, deleteData: deleteData)
        }
        if deleteData { try? FileManager.default.removeItem(at: Paths.profilesDataDirectory) }
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: Paths.profileAppsDirectory.path), contents.isEmpty {
            try? FileManager.default.removeItem(at: Paths.profileAppsDirectory)
        }
    }

    // MARK: Sign-in

    func beginSignIn(_ profile: Profile) async {
        do {
            try await signInRouter.begin(profile)
            signInProfileID = profile.id
            open(profile)
        } catch {
            report(error)
        }
    }

    func finishSignIn() async {
        await signInRouter.finish()
        signInProfileID = nil
    }

    // MARK: Running apps

    /// Asks the profile app to quit, and forces it after a few seconds if it keeps running.
    func quitIfRunning(_ profile: Profile) async -> Bool {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: profile.bundleID)
        guard !apps.isEmpty else { return true }
        apps.forEach { $0.terminate() }
        for _ in 0..<24 where !apps.allSatisfy(\.isTerminated) {
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        if !apps.allSatisfy(\.isTerminated) {
            apps.forEach { $0.forceTerminate() }
            try? await Task.sleep(nanoseconds: 750_000_000)
        }
        refreshRunningApps()
        return apps.allSatisfy(\.isTerminated)
    }

    // MARK: Helpers

    private func runBuild(
        _ profile: Profile,
        replacing oldAppURL: URL? = nil,
        progress: @escaping (ProfileAppBuilder.Step) -> Void
    ) async throws -> String {
        let builder = builder
        let icon = claudeIcon
        let version = try await Task.detached {
            try builder.build(profile, baseIcon: icon, replacing: oldAppURL) { step in
                Task { @MainActor in progress(step) }
            }
        }.value
        refreshClaudeVersion()
        return version
    }

    private func perform(on profile: Profile, _ work: @escaping (AppModel) async throws -> Void) async {
        busyProfileIDs.insert(profile.id)
        defer { busyProfileIDs.remove(profile.id) }
        do {
            try await work(self)
        } catch {
            report(error)
        }
    }

    private func replace(_ profile: Profile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index] = profile
        do { try save() } catch { report(error) }
    }

    private func save() throws { try store.save(profiles) }

    func report(_ error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

enum SidebarItem: Hashable {
    case defaultApp
    case profile(UUID)
}
