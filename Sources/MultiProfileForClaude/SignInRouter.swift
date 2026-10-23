import AppKit

/// Sends `claude://` sign-in links to one profile app for a short time.
///
/// Signing in through the browser ends with a `claude://` link. macOS opens such links in
/// one app only, normally the original Claude app. While a profile signs in, that profile
/// becomes the handler; afterwards (or after 10 minutes) the original app gets it back.
@MainActor
final class SignInRouter: ObservableObject {
    static let scheme = "claude"
    static let duration: TimeInterval = 10 * 60
    private static let pendingRestoreKey = "SignInRouter.pendingRestore"

    @Published private(set) var profileID: UUID?
    @Published private(set) var deadline: Date?
    private var timer: Timer?

    var isActive: Bool { profileID != nil }

    func begin(_ profile: Profile) async throws {
        try await NSWorkspace.shared.setDefaultApplication(at: profile.appURL, toOpenURLsWithScheme: Self.scheme)
        UserDefaults.standard.set(true, forKey: Self.pendingRestoreKey)
        profileID = profile.id
        deadline = Date().addingTimeInterval(Self.duration)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Self.duration, repeats: false) { [weak self] _ in
            Task { @MainActor in await self?.finish() }
        }
    }

    /// Gives `claude://` links back to the original Claude app.
    func finish() async {
        timer?.invalidate()
        timer = nil
        profileID = nil
        deadline = nil
        if let original = Paths.claudeApp() {
            try? await NSWorkspace.shared.setDefaultApplication(at: original, toOpenURLsWithScheme: Self.scheme)
        }
        UserDefaults.standard.removeObject(forKey: Self.pendingRestoreKey)
    }

    /// Fixes the handler if the app quit in the middle of a sign-in last time.
    func restoreIfNeeded() {
        guard UserDefaults.standard.bool(forKey: Self.pendingRestoreKey) else { return }
        Task { await finish() }
    }

    static func currentHandler() -> URL? {
        guard let url = URL(string: "\(scheme)://") else { return nil }
        return NSWorkspace.shared.urlForApplication(toOpen: url)
    }
}
