import SwiftUI

struct ProfileDetailView: View {
    @EnvironmentObject private var model: AppModel
    let profile: Profile

    @State private var pendingAction: PendingAction?
    @State private var showRename = false
    @State private var newName = ""
    @State private var showDelete = false
    @State private var copied = false

    /// Actions that need the profile app to quit first.
    enum PendingAction: Identifiable {
        case rebuild, rename(String), delete(deleteData: Bool)
        var id: String {
            switch self {
            case .rebuild: return "rebuild"
            case .rename: return "rename"
            case .delete: return "delete"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if model.needsRebuild(profile) { rebuildBanner }
                header
                colorSection
                actionsSection
                commandSection
                detailsSection
                deleteSection
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .disabled(model.isBusy(profile))
        .overlay(alignment: .top) {
            if model.isBusy(profile) {
                ProgressView("Working on \(profile.displayName)…")
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 12)
            }
        }
        .alert("Rename Profile", isPresented: $showRename) {
            TextField("Name", text: $newName)
            Button("Rename") { run(.rename(newName)) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The profile app is rebuilt with the new name. Its sign-in, chats and terminal command stay the same.")
        }
        .confirmationDialog("Delete \(profile.name)?", isPresented: $showDelete, titleVisibility: .visible) {
            Button("Delete Profile App Only", role: .destructive) { run(.delete(deleteData: false)) }
            Button("Delete App, Chats and Sign-in", role: .destructive) { run(.delete(deleteData: true)) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deleting only the app keeps its data folder, so you can create the profile again later.")
        }
        .alert(item: $pendingAction) { action in
            Alert(
                title: Text("Quit \(profile.displayName)?"),
                message: Text("\(profile.displayName) is running. It has to quit before it can be changed."),
                primaryButton: .default(Text("Quit and Continue")) { perform(action) },
                secondaryButton: .cancel()
            )
        }
    }

    // MARK: Sections

    private var rebuildBanner: some View {
        NoticeBox(kind: .warning) {
            HStack(alignment: .center, spacing: 12) {
                Text("Claude was updated to \(model.claudeVersion ?? "a new version"). \(profile.name) still runs \(profile.builtClaudeVersion ?? "an older version") — rebuild it to get the update. Its sign-in and chats are kept.")
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button("Rebuild") { run(.rebuild) }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 20) {
            ProfileIconPreview(icon: model.claudeIcon, letter: profile.letter, color: profile.color)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(profile.name).font(.system(size: 26, weight: .semibold))
                    Button("Rename…") {
                        newName = profile.name
                        showRename = true
                    }
                    .buttonStyle(.link)
                }
                Text("\(profile.displayName).app").foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    StatusChip(text: model.isRunning(profile) ? "Running" : "Not running",
                               dot: model.isRunning(profile) ? .green : .gray)
                    StatusChip(text: "Claude \(profile.builtClaudeVersion ?? "?")")
                    if model.needsRebuild(profile) {
                        StatusChip(text: "Needs rebuild", tint: .orange)
                    } else {
                        StatusChip(text: "Up to date", tint: .green)
                    }
                }
            }
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading("Color")
            ColorSwatchPicker(selectedHex: profile.colorHex) { hex in
                Task { await model.setColor(profile, hex: hex) }
            }
            Text("The Dock icon updates the next time \(profile.displayName) starts.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading("Actions")
            HStack(spacing: 8) {
                Button("Open") { model.open(profile) }
                    .buttonStyle(.borderedProminent)
                Button("Sign In…") { Task { await model.beginSignIn(profile) } }
                Button("Rebuild") { run(.rebuild) }
                Button("Show Data Folder") { model.revealDataFolder(profile) }
            }
            .controlSize(.large)
            Text("Profile apps support email and Google sign-in. Passkeys, security keys and Microsoft single sign-on only work in your original Claude app.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var commandSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading("Terminal command")
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: Binding(
                    get: { profile.commandEnabled },
                    set: { model.setCommandEnabled(profile, $0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use Claude Code with this profile in Terminal").fontWeight(.medium)
                        Text("Its own Claude Code sign-in, settings and history.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                if profile.commandEnabled, let name = profile.commandName {
                    HStack(spacing: 8) {
                        Text(name)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 7).fill(Color.secondary.opacity(0.12)))
                        Button(copied ? "Copied" : "Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(name, forType: .string)
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                        }
                        Button {
                            model.openTerminal(for: profile)
                        } label: {
                            Label("Open in Terminal", systemImage: "terminal")
                        }
                    }
                    if model.commandsOnPath {
                        Text("Installed in ~/.local/bin. The first time you run \(name), Claude Code asks you to sign in — use this profile's account. Anything after the command works like normal claude, for example \(name) -c.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        NoticeBox(kind: .warning) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("~/.local/bin isn't on your PATH yet, so Terminal won't find \(name). Add this line to ~/.zshrc, then open a new Terminal window:")
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(CLICommandInstaller.pathLine)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.secondary.opacity(0.25)))
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeading("Details")
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                detailRow("App", Paths.abbreviated(profile.appURL))
                detailRow("App data", Paths.abbreviated(profile.desktopDataDirectory))
                detailRow("Claude Code data", Paths.abbreviated(profile.claudeCodeDirectory))
                GridRow {
                    Text("Sign-in links").foregroundStyle(.secondary)
                    Text("Open your original Claude app, except during Sign In…")
                }
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            HStack(spacing: 12) {
                Button("Delete Profile…", role: .destructive) { showDelete = true }
                Text("Removes the profile app. You'll be asked whether to also delete its chats and sign-in.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Running actions

    /// Asks to quit the profile app first when it's running.
    private func run(_ action: PendingAction) {
        if model.isRunning(profile) {
            pendingAction = action
        } else {
            perform(action)
        }
    }

    private func perform(_ action: PendingAction) {
        Task {
            guard await model.quitIfRunning(profile) else {
                model.errorMessage = "\(profile.displayName) didn't quit. Quit it yourself and try again."
                return
            }
            switch action {
            case .rebuild: await model.rebuild(profile)
            case .rename(let name): await model.rename(profile, to: name)
            case .delete(let deleteData): await model.delete(profile, deleteData: deleteData)
            }
        }
    }
}

struct DefaultDetailView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .center, spacing: 20) {
                    ProfileIconPreview(icon: model.claudeIcon)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Default").font(.system(size: 26, weight: .semibold))
                        Text("Claude.app · original").foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            StatusChip(text: model.isDefaultRunning ? "Running" : "Not running",
                                       dot: model.isDefaultRunning ? .green : .gray)
                            StatusChip(text: "Claude \(model.claudeVersion ?? "not installed")")
                            StatusChip(text: "Updates automatically", tint: .green)
                        }
                    }
                }

                if model.isClaudeInstalled {
                    NoticeBox {
                        Text("This is your original Claude app. \(AppInfo.name) never changes it or its data, so it keeps its own signature, automatic updates and every sign-in option.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    NoticeBox(kind: .warning) {
                        Text("Claude isn't installed. Download the Claude desktop app, move it to /Applications, then come back to create profiles.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 8) {
                    Button("Open") { model.openDefault() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!model.isClaudeInstalled)
                    Button("New Profile…") { model.showNewProfile = true }
                }
                .controlSize(.large)

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeading("Terminal command")
                    Text("Your normal claude command uses this profile's account. \(AppInfo.name) doesn't change it.")
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeading("Details")
                    Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                        GridRow {
                            Text("App").foregroundStyle(.secondary)
                            Text(Paths.claudeApp().map(Paths.abbreviated) ?? "Not installed")
                                .font(.system(.callout, design: .monospaced))
                        }
                        GridRow {
                            Text("App data").foregroundStyle(.secondary)
                            Text("~/Library/Application Support/Claude").font(.system(.callout, design: .monospaced))
                        }
                        GridRow {
                            Text("Claude Code data").foregroundStyle(.secondary)
                            Text("~/.claude").font(.system(.callout, design: .monospaced))
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
