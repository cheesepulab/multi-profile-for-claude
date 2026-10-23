import SwiftUI

struct ManageWindow: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.system.rawValue
    @State private var deleteDataOnRemoveAll = false

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
        } detail: {
            detail
                .frame(minWidth: 560, minHeight: 430)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Rebuild All") { Task { await model.rebuildAll() } }
                    .disabled(model.profilesNeedingRebuild.isEmpty)
                    .help("Rebuild profiles that still use an older version of Claude")
                Button {
                    model.showNewProfile = true
                } label: {
                    Label("New Profile", systemImage: "plus")
                }
                .help("Create a new profile")
            }
        }
        .navigationTitle("Profiles")
        .sheet(isPresented: $model.showNewProfile) {
            NewProfileSheet().environmentObject(model)
        }
        .background(
            EmptyView().sheet(isPresented: signInSheetBinding) {
                if let id = model.signInProfileID, let profile = model.profile(id) {
                    SignInAssistantView(profile: profile).environmentObject(model)
                }
            }
        )
        .alert("Something went wrong", isPresented: errorBinding) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .confirmationDialog("Remove all profiles?", isPresented: $model.showRemoveAll, titleVisibility: .visible) {
            Button("Remove Profile Apps and Commands", role: .destructive) {
                Task { await model.removeAllProfiles(deleteData: false) }
            }
            Button("Remove Everything, Including Chats and Sign-ins", role: .destructive) {
                Task { await model.removeAllProfiles(deleteData: true) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This quits and deletes every profile app and its terminal command. Your original Claude app and its data are not touched.")
        }
        .onAppear {
            model.refreshClaudeVersion()
            model.refreshRunningApps()
            model.refreshPathStatus()
        }
    }

    // MARK: Sidebar

    // The footer sits below the list in a plain stack: as a safeAreaInset on a sidebar List,
    // macOS lays the list out under the title bar and drops the footer in windowed mode.
    private var sidebar: some View {
        VStack(spacing: 0) {
            profileList
            Divider()
            sidebarFooter
        }
    }

    private var profileList: some View {
        List(selection: $model.selection) {
            Section("Profiles") {
                SidebarRow(
                    name: "Default",
                    status: model.isDefaultRunning ? "Running" : "Not running",
                    statusIsWarning: false,
                    letter: "D",
                    color: Color(hex: ProfilePalette.defaultProfileHex)
                )
                .tag(SidebarItem.defaultApp)

                ForEach(model.profiles) { profile in
                    SidebarRow(
                        name: profile.name,
                        status: status(of: profile),
                        statusIsWarning: model.needsRebuild(profile),
                        letter: profile.letter,
                        color: profile.color
                    )
                    .tag(SidebarItem.profile(profile.id))
                }
            }
        }
        .listStyle(.sidebar)
    }

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Appearance")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Picker("Appearance", selection: $appearance) {
                ForEach(Appearance.allCases) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: appearance) { newValue in
                (Appearance(rawValue: newValue) ?? .system).apply()
            }
            // No fixedSize here: when macOS asks the sidebar for its smallest size, a fixed-size
            // text wraps one letter per line and the window can no longer be made shorter.
            Text("Profile apps live in ~/Applications/Claude Profiles.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func status(of profile: Profile) -> String {
        if model.isBusy(profile) { return "Working…" }
        if model.needsRebuild(profile) { return "Needs rebuild" }
        return model.isRunning(profile) ? "Running" : "Not running"
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        switch model.selection {
        case .profile(let id):
            if let profile = model.profile(id) {
                ProfileDetailView(profile: profile)
            } else {
                DefaultDetailView()
            }
        case .defaultApp, .none:
            DefaultDetailView()
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
    }

    private var signInSheetBinding: Binding<Bool> {
        Binding(get: { model.signInProfileID != nil }, set: { if !$0 { model.signInProfileID = nil } })
    }
}

private struct SidebarRow: View {
    let name: String
    let status: String
    let statusIsWarning: Bool
    let letter: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            LetterBadge(letter: letter, color: color, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).fontWeight(.medium)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(statusIsWarning ? Color.orange : Color.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}
