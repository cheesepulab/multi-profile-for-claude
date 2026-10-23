import Foundation

/// Runs command-line tools such as `codesign`, `cp` and `iconutil`.
enum Shell {
    struct Result {
        let status: Int32
        let stdout: Data
        let stderr: Data

        var output: String { String(decoding: stdout, as: UTF8.self) }
        var errorOutput: String { String(decoding: stderr, as: UTF8.self) }
    }

    struct CommandError: LocalizedError {
        let command: String
        let result: Result

        var errorDescription: String? {
            let detail = result.errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(command) failed (exit \(result.status))" + (detail.isEmpty ? "" : ": \(detail)")
        }
    }

    /// Runs `executable` and waits for it. Throws when it exits non-zero.
    @discardableResult
    static func run(
        _ executable: String,
        _ arguments: [String],
        environment: [String: String]? = nil,
        timeout: TimeInterval? = nil
    ) throws -> Result {
        let result = try capture(executable, arguments, environment: environment, timeout: timeout)
        guard result.status == 0 else {
            let name = (executable as NSString).lastPathComponent
            throw CommandError(command: name, result: result)
        }
        return result
    }

    /// Runs `executable` and returns its result without checking the exit status.
    static func capture(
        _ executable: String,
        _ arguments: [String],
        environment: [String: String]? = nil,
        timeout: TimeInterval? = nil
    ) throws -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let environment {
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        }
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        process.standardInput = FileHandle.nullDevice

        // Read both pipes while the process runs so a chatty tool can't fill a pipe and stall.
        var outData = Data()
        var errData = Data()
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        DispatchQueue.global().async {
            errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        try process.run()
        if let timeout {
            let deadline = Date().addingTimeInterval(timeout)
            while process.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
            if process.isRunning { process.terminate() }
        }
        process.waitUntilExit()
        group.wait()
        return Result(status: process.terminationStatus, stdout: outData, stderr: errData)
    }
}
