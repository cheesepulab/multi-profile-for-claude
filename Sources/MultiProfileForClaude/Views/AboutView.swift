import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
            VStack(spacing: 4) {
                Text(AppInfo.name).font(.title2.weight(.semibold))
                Text("Version \(AppInfo.version) (\(AppInfo.build))")
                    .foregroundStyle(.secondary)
            }
            Text("Run several Claude accounts side by side, each with its own app, sign-in and terminal command.")
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Free and open source under the MIT License.")
                .font(.callout)
                .foregroundStyle(.secondary)

            if let repo = AppInfo.repositoryURL {
                Link(destination: repo) {
                    Label("Source on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            if let qr = AppInfo.donateQRCode {
                Divider()
                DonateSection(qrCode: qr)
            }

            Divider()
            Text("Not affiliated with or endorsed by Anthropic. Claude is a trademark of Anthropic, PBC.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
        .frame(width: 440)
    }
}

/// A VietQR code and the account it pays into, for donations by bank transfer.
private struct DonateSection: View {
    let qrCode: NSImage
    @State private var copied = false

    var body: some View {
        VStack(spacing: 12) {
            Text("Support this project").font(.headline)
            Text("Scan with any Vietnamese banking app (VietQR, Napas 247), or transfer to the account below.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            // An explicit height: this window sizes itself to its content, where a width-only
            // frame lets the image collapse to zero height.
            Image(nsImage: qrCode)
                .resizable()
                .interpolation(.high)
                .frame(width: 230, height: 230 * qrCode.size.height / max(qrCode.size.width, 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel(accessibilityText)

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                if let bank = AppInfo.donateBank { row("Bank", bank) }
                if let name = AppInfo.donateAccountName { row("Account name", name) }
                if let number = AppInfo.donateAccountNumber {
                    GridRow {
                        Text("Account number").foregroundStyle(.secondary)
                        HStack(spacing: 8) {
                            Text(number)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                            Button(copied ? "Copied" : "Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(number.filter(\.isNumber), forType: .string)
                                copied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value).textSelection(.enabled)
        }
    }

    private var accessibilityText: String {
        let parts = [AppInfo.donateBank, AppInfo.donateAccountName, AppInfo.donateAccountNumber].compactMap { $0 }
        return "VietQR code for a bank transfer: " + parts.joined(separator: ", ")
    }
}
