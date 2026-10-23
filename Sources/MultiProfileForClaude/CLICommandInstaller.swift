import AppKit

/// Creates per-profile terminal commands such as `claude-work`.
///
/// Each command is a small shell script in ~/.local/bin that runs Claude Code with
/// CLAUDE_CONFIG_DIR pointing at the profile's own folder, which gives it a separate
/// sign-in, settings and history. Files are only ever replaced or removed when they
/// carry `marker`, so commands the user wrote themselves are never touched.
struct CLICommandInstaller {
    static let marker = "# Created by Multi Profile for Claude"

    enum CommandError: LocalizedError {
        case nameTaken(String)
        case invalidName(String)

        var errorDescription: String? {
            switch self {
            case .nameTaken(let name):
                return "~/.local/bin/\(name) already exists and wasn't created by Multi Profile for Claude, so it was left alone."
            case .invalidName(let name):
                return "“\(name)” can't be used as a command name."
            }
        }
    }

    func url(for name: String) -> URL { Paths.commandDirectory.appendingPathComponent(name) }

    func isOurs(_ name: String) -> Bool {
        guard let text = try? String(contentsOf: url(for: name), encoding: .utf8) else { return false }
        return text.contains(Self.marker)
    }

    func isAvailable(_ name: String) -> Bool {
        !FileManager.default.fileExists(atPath: url(for: name).path) || isOurs(name)
    }

    /// `claude-work`, or `claude-work-2` when `claude-work` belongs to something else.
    func suggestedName(for profile: Profile) -> String {
        let base = profile.defaultCommandName
        if isAvailable(base) { return base }
        var n = 2
        while !isAvailable("\(base)-\(n)") { n += 1 }
        return "\(base)-\(n)"
    }

    func script(for profile: Profile) -> String {
        let label = profile.name.replacingOccurrences(of: "\"", with: "'").replacingOccurrences(of: "\n", with: " ")
        let configPath = profile.claudeCodeDirectory.path.replacingOccurrences(of: Paths.home.path, with: "$HOME")
        return """
        #!/bin/sh
        \(Self.marker) for the "\(label)" profile.
        export CLAUDE_CONFIG_DIR="\(configPath)"
        exec claude "$@"

        """
    }

    func install(_ profile: Profile, as name: String) throws {
        guard isValid(name) else { throw CommandError.invalidName(name) }
        guard isAvailable(name) else { throw CommandError.nameTaken(name) }
        let fm = FileManager.default
        try fm.createDirectory(at: Paths.commandDirectory, withIntermediateDirectories: true)
        try fm.createDirectory(at: profile.claudeCodeDirectory, withIntermediateDirectories: true)
        let destination = url(for: name)
        try Data(script(for: profile).utf8).write(to: destination, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination.path)
    }

    /// Removes the command only if this app created it.
    func remove(_ name: String) {
        guard isOurs(name) else { return }
        try? FileManager.default.removeItem(at: url(for: name))
    }

    func isValid(_ name: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-_.")
        return !name.isEmpty && name != "claude" && !name.hasPrefix("-") && !name.hasPrefix(".")
            && name.unicodeScalars.allSatisfy(allowed.contains)
    }

    // MARK: PATH

    /// Whether ~/.local/bin is on the PATH of the user's login shell. Apps opened from the
    /// Dock don't inherit that PATH, so ask the shell directly.
    func commandDirectoryIsOnPath() -> Bool {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        guard let result = try? Shell.capture(shell, ["-ilc", "printf '__MPFC__%s__MPFC__' \"$PATH\""], timeout: 5) else {
            return true
        }
        let output = result.output
        guard let start = output.range(of: "__MPFC__"),
              let end = output.range(of: "__MPFC__", range: start.upperBound..<output.endIndex)
        else { return true }
        let entries = output[start.upperBound..<end.lowerBound].split(separator: ":").map {
            ($0 as NSString).expandingTildeInPath
        }
        let target = Paths.commandDirectory.path
        return entries.contains { URL(fileURLWithPath: $0).standardizedFileURL.path == target }
    }

    static var pathLine: String { "export PATH=\"$HOME/.local/bin:$PATH\"" }

    // MARK: Terminal

    /// Opens Terminal and runs `command` there. macOS asks once for permission to control Terminal.
    func openInTerminal(_ command: String) throws {
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let source = """
        tell application "Terminal"
            activate
            do script "\(escaped)"
        end tell
        """
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "Terminal could not be opened."
            throw NSError(domain: "MultiProfileForClaude", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    /// The shell command that runs a profile's command, using its full path so it works
    /// even before ~/.local/bin is on PATH.
    func terminalCommand(for name: String) -> String {
        "'\(url(for: name).path.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
