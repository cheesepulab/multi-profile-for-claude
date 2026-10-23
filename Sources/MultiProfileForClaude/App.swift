import SwiftUI

enum WindowID {
    static let manage = "manage"
    static let about = "about"
}

@main
struct MultiProfileForClaudeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environmentObject(model)
        } label: {
            MenuBarLabel()
                .environmentObject(model)
        }
        .menuBarExtraStyle(.window)

        Window("Profiles", id: WindowID.manage) {
            ManageWindow()
                .environmentObject(model)
                .onAppear { WindowActivation.windowDidOpen() }
        }
        .defaultSize(width: 980, height: 720)
        .commands { AppCommands(model: model) }

        Window("About \(AppInfo.name)", id: WindowID.about) {
            AboutView()
                .environmentObject(model)
                .onAppear { WindowActivation.windowDidOpen() }
        }
        .windowResizability(.contentSize)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Appearance.saved.apply()
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { _ in
            DispatchQueue.main.async { WindowActivation.updatePolicy() }
        }
    }

    /// Opening the app again while it runs (Finder, Spotlight, Launchpad) shows the Profiles window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        WindowOpener.open(WindowID.manage)
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let model = AppModel.shared
        guard model.signInRouter.isActive else { return .terminateNow }
        // Give claude:// links back to the original Claude app before quitting.
        Task {
            await model.finishSignIn()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}

/// Opens SwiftUI windows from outside a view, such as the app delegate. The menu bar label,
/// which is always on screen, hands over its `openWindow` action when it appears.
@MainActor
enum WindowOpener {
    static var action: OpenWindowAction?
    static var didOpenAtLaunch = false

    static func open(_ id: String) {
        guard let action else { return }
        action(id: id)
        WindowActivation.windowDidOpen()
    }
}

/// The app lives in the menu bar. It only shows a Dock icon while one of its windows is open.
enum WindowActivation {
    @MainActor
    static func windowDidOpen() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    static func updatePolicy() {
        let hasWindow = NSApp.windows.contains { $0.isVisible && $0.styleMask.contains(.titled) }
        if !hasWindow { NSApp.setActivationPolicy(.accessory) }
    }
}

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "appearance"

    static var saved: Appearance {
        Appearance(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .system
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    @MainActor
    func apply() {
        switch self {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

struct AppCommands: Commands {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About \(AppInfo.name)") { openWindow(id: WindowID.about) }
        }
        CommandGroup(replacing: .newItem) {
            Button("New Profile…") {
                openWindow(id: WindowID.manage)
                model.showNewProfile = true
            }
            .keyboardShortcut("n")
        }
        CommandMenu("Profiles") {
            Button("Rebuild All") { Task { await model.rebuildAll() } }
                .disabled(model.profilesNeedingRebuild.isEmpty)
            Divider()
            Button("Remove All Profiles…") {
                openWindow(id: WindowID.manage)
                model.showRemoveAll = true
            }
            .disabled(model.profiles.isEmpty)
        }
    }
}
