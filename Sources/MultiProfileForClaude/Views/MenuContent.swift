import SwiftUI

/// Menu bar icon: the letter and color of the Claude profile that was last in front.
struct MenuBarLabel: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        icon.onAppear {
            WindowOpener.action = openWindow
            // With no profiles yet, show the Profiles window so people see where to start.
            if model.profiles.isEmpty && !WindowOpener.didOpenAtLaunch {
                WindowOpener.didOpenAtLaunch = true
                WindowOpener.open(WindowID.manage)
            }
        }
    }

    @ViewBuilder
    private var icon: some View {
        if let profile = model.frontProfile {
            Image(nsImage: IconRenderer.menuBarImage(color: profile.nsColor, letter: profile.letter))
                .accessibilityLabel("\(AppInfo.name), \(profile.name) in front")
        } else if model.isDefaultInFront {
            Image(nsImage: IconRenderer.menuBarImage(color: NSColor(hex: ProfilePalette.defaultProfileHex), letter: "D"))
                .accessibilityLabel("\(AppInfo.name), Default in front")
        } else {
            Image(systemName: "person.2.circle")
                .accessibilityLabel(AppInfo.name)
        }
    }
}

struct MenuContent: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Claude profiles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.top, 4)
                .padding(.bottom, 2)

            MenuProfileRow(
                name: "Default",
                subtitle: model.isDefaultInFront ? "In front" : "Your original Claude app",
                letter: "D",
                color: Color(hex: ProfilePalette.defaultProfileHex),
                isRunning: model.isDefaultRunning,
                isFront: model.isDefaultInFront,
                terminalHelp: "Open Claude Code in Terminal (claude)",
                open: { model.openDefault() },
                openTerminal: { model.openTerminal(for: nil) }
            )

            ForEach(model.profiles) { profile in
                let isFront = model.frontProfile?.id == profile.id
                MenuProfileRow(
                    name: profile.name,
                    subtitle: subtitle(for: profile, isFront: isFront),
                    letter: profile.letter,
                    color: profile.color,
                    isRunning: model.isRunning(profile),
                    isFront: isFront,
                    terminalHelp: profile.commandName.map { "Open Claude Code in Terminal as \(profile.name) (\($0))" },
                    open: { model.open(profile) },
                    openTerminal: profile.commandName == nil ? nil : { model.openTerminal(for: profile) }
                )
            }

            if !model.profilesNeedingRebuild.isEmpty {
                updateBanner
            }

            Divider().padding(.vertical, 4)
            MenuActionRow(title: "New Profile…", shortcut: "⌘N") {
                showManageWindow()
                model.showNewProfile = true
            }
            MenuActionRow(title: "Manage Profiles…", shortcut: "⌘,") { showManageWindow() }
            Divider().padding(.vertical, 4)
            MenuActionRow(title: "About and Donate…") {
                openWindow(id: WindowID.about)
                WindowActivation.windowDidOpen()
            }
            MenuActionRow(title: "Quit \(AppInfo.name)", shortcut: "⌘Q") { NSApp.terminate(nil) }
        }
        .padding(6)
        .frame(width: 352)
        .onAppear {
            model.refreshClaudeVersion()
            model.refreshRunningApps()
        }
    }

    private var updateBanner: some View {
        let count = model.profilesNeedingRebuild.count
        return HStack(spacing: 10) {
            Text("Claude was updated. \(count) \(count == 1 ? "profile needs" : "profiles need") a rebuild.")
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Rebuild") { Task { await model.rebuildAll() } }
                .controlSize(.small)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.orange.opacity(0.4)))
        .padding(.horizontal, 4)
        .padding(.top, 6)
    }

    private func subtitle(for profile: Profile, isFront: Bool) -> String {
        if model.isBusy(profile) { return "Working…" }
        if isFront { return "In front" }
        if model.needsRebuild(profile) { return "Needs rebuild" }
        return "Profile"
    }

    private func showManageWindow() {
        openWindow(id: WindowID.manage)
        WindowActivation.windowDidOpen()
    }
}

private struct MenuProfileRow: View {
    let name: String
    let subtitle: String
    let letter: String
    let color: Color
    let isRunning: Bool
    let isFront: Bool
    let terminalHelp: String?
    let open: () -> Void
    let openTerminal: (() -> Void)?

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 2) {
            Button(action: open) {
                HStack(spacing: 10) {
                    LetterBadge(letter: letter, color: color)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(name).fontWeight(.medium)
                        Text(subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    if isRunning {
                        HStack(spacing: 5) {
                            Circle().fill(Color.green).frame(width: 7, height: 7)
                            Text("Running")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isFront ? Color.accentColor.opacity(0.14) : (isHovering ? Color.primary.opacity(0.07) : .clear))
            )
            .onHover { isHovering = $0 }
            .accessibilityLabel("\(name)\(isRunning ? ", running" : "")\(isFront ? ", in front" : "")")

            if let openTerminal, let terminalHelp {
                Button(action: openTerminal) {
                    Image(systemName: "terminal")
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(terminalHelp)
                .accessibilityLabel(terminalHelp)
            } else {
                Color.clear.frame(width: 40, height: 40)
            }
        }
    }
}

private struct MenuActionRow: View {
    let title: String
    var shortcut: String?
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                if let shortcut { Text(shortcut).foregroundStyle(.secondary) }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(RoundedRectangle(cornerRadius: 6).fill(isHovering ? Color.primary.opacity(0.07) : .clear))
        .onHover { isHovering = $0 }
    }
}
