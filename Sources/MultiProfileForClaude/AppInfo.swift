import AppKit

/// Values the build script writes into the app's Info.plist (see scripts/config.sh).
enum AppInfo {
    static let name = "Multi Profile for Claude"

    private static func string(_ key: String) -> String? {
        let value = Bundle.main.object(forInfoDictionaryKey: key) as? String
        return (value?.isEmpty ?? true) ? nil : value
    }

    static var version: String { string("CFBundleShortVersionString") ?? "dev" }
    static var build: String { string("CFBundleVersion") ?? "0" }

    // Each value falls back to BuildDefaults (generated from the same config) when the app
    // runs without its packaged Info.plist, for example from Xcode.

    /// Reverse-DNS prefix for this app and the profile apps it creates.
    static var bundleIDPrefix: String { string("MPFCBundleIDPrefix") ?? BuildDefaults.bundleIDPrefix }

    static var repositoryURL: URL? { URL(string: string("MPFCRepositoryURL") ?? BuildDefaults.repositoryURL) }
    static var donateURL: URL? { URL(string: string("MPFCDonateURL") ?? BuildDefaults.donateURL) }

    /// Bank transfer details for donations, shown next to the VietQR code.
    static var donateBank: String? { string("MPFCDonateBank") ?? BuildDefaults.donateBank }
    static var donateAccountName: String? { string("MPFCDonateAccountName") ?? BuildDefaults.donateAccountName }
    static var donateAccountNumber: String? { string("MPFCDonateAccountNumber") ?? BuildDefaults.donateAccountNumber }

    static var donateQRCode: NSImage? {
        Bundle.main.url(forResource: "donate-qr", withExtension: "png").flatMap(NSImage.init(contentsOf:))
    }
}

/// Keys this app adds to each profile app's Info.plist.
enum ProfileInfoKey {
    static let dataDirectory = "MPFCDataDirectory"
    static let profileID = "MPFCProfileID"
    static let managedBy = "MPFCManagedBy"
}
