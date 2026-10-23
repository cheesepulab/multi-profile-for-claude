import SwiftUI

struct NewProfileSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    enum Phase {
        case form
        case building(ProfileAppBuilder.Step)
        case done(Profile)
        case failed(String)
    }

    @State private var name = ""
    @State private var colorHex = ProfilePalette.swatches[0].hex
    @State private var commandEnabled = true
    @State private var phase: Phase = .form

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var previewProfile: Profile {
        let slug = Slug.unique(Slug.make(from: trimmedName), taken: Set(model.profiles.map(\.slug)))
        return Profile(id: UUID(), name: trimmedName.isEmpty ? "Profile" : trimmedName, colorHex: colorHex,
                       slug: slug, commandEnabled: commandEnabled, commandName: nil, builtClaudeVersion: nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            switch phase {
            case .form: form
            case .building(let step): building(step)
            case .done(let profile): done(profile)
            case .failed(let message): failed(message)
            }
        }
        .padding(24)
        .frame(width: 520)
        .onAppear {
            colorHex = ProfilePalette.suggestedHex(excluding: model.profiles.map(\.colorHex))
        }
    }

    // MARK: Form

    private var form: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("New Profile").font(.title3.weight(.semibold))
                Text("Each profile is its own Claude app, with its own sign-in, chats and settings.")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                ProfileIconPreview(icon: model.claudeIcon, letter: previewProfile.letter,
                                   color: Color(hex: colorHex), size: 72)
                VStack(alignment: .leading, spacing: 2) {
                    Text(previewProfile.displayName).fontWeight(.semibold)
                    Text("Appears in the Dock, Spotlight and Launchpad")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Name").fontWeight(.semibold)
                TextField("e.g. Work", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(create)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Color").fontWeight(.semibold)
                ColorSwatchPicker(selectedHex: colorHex) { colorHex = $0 }
            }

            Toggle(isOn: $commandEnabled) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Also create a terminal command").fontWeight(.medium)
                    (Text("Type ") + Text(model.commands.suggestedName(for: previewProfile)).font(.system(.caption, design: .monospaced))
                        + Text(" in Terminal to use Claude Code with this profile's account."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.checkbox)

            Text("The copy shares files with your Claude app on disk, so it uses almost no extra space. Your original Claude app is not changed.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !model.isClaudeInstalled {
                NoticeBox(kind: .warning) {
                    Text("Install the Claude desktop app in /Applications first.")
                }
            }

            Divider()
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create Profile", action: create)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedName.isEmpty || !model.isClaudeInstalled)
            }
        }
    }

    private func create() {
        guard !trimmedName.isEmpty, model.isClaudeInstalled else { return }
        phase = .building(.copy)
        let name = trimmedName
        let hex = colorHex
        let withCommand = commandEnabled
        Task {
            do {
                let profile = try await model.createProfile(name: name, colorHex: hex, commandEnabled: withCommand) { step in
                    phase = .building(step)
                }
                phase = .done(profile)
            } catch {
                phase = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
        }
    }

    // MARK: Progress

    private func building(_ current: ProfileAppBuilder.Step) -> some View {
        let steps = ProfileAppBuilder.Step.allCases.filter { $0 != .command || commandEnabled }
        return VStack(alignment: .leading, spacing: 18) {
            Text("Creating \(previewProfile.displayName)…").font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 12) {
                ForEach(steps) { step in
                    HStack(spacing: 12) {
                        Group {
                            if step.rawValue < current.rawValue {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    .accessibilityLabel("Done")
                            } else if step == current {
                                ProgressView().controlSize(.small)
                                    .accessibilityLabel("In progress")
                            } else {
                                Image(systemName: "circle").foregroundStyle(.tertiary)
                                    .accessibilityLabel("Waiting")
                            }
                        }
                        .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step == .command ? "\(step.title) \(model.commands.suggestedName(for: previewProfile))" : step.title)
                                .fontWeight(.medium)
                                .foregroundStyle(step.rawValue > current.rawValue ? .secondary : .primary)
                            Text(step.detail).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func done(_ profile: Profile) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 36))
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("\(profile.displayName) is ready").font(.title3.weight(.semibold))
                Text("Find it in the Dock, Spotlight, Launchpad or the \(AppInfo.name) menu. Next, sign in with the account you want to use for this profile.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let command = profile.commandName {
                HStack(spacing: 10) {
                    Image(systemName: "terminal").foregroundStyle(.secondary)
                    (Text("In Terminal, type ") + Text(command).font(.system(.body, design: .monospaced)).bold()
                        + Text(" to use Claude Code with this profile."))
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.12)))
            }
            Divider()
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                Button("Open and Sign In") {
                    dismiss()
                    Task { await model.beginSignIn(profile) }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func failed(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Couldn't create the profile").font(.title3.weight(.semibold))
            Text(message)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            HStack {
                Spacer()
                Button("Close") { dismiss() }
                Button("Try Again") { phase = .form }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }
}
