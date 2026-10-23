// ProfileLauncher is installed as the main executable of every profile app.
// It starts the real Claude binary that sits next to it and points it at the
// profile's own data folder, so each profile keeps its own sign-in and chats.

import Foundation

let dataDirectoryKey = "MPFCDataDirectory"

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("ProfileLauncher: \(message)\n".utf8))
    exit(1)
}

let bundle = Bundle.main
guard let dataDirectory = bundle.object(forInfoDictionaryKey: dataDirectoryKey) as? String,
      !dataDirectory.isEmpty
else {
    fail("\(dataDirectoryKey) is missing from Info.plist")
}

let expandedDataDirectory = (dataDirectory as NSString).expandingTildeInPath
try? FileManager.default.createDirectory(
    atPath: expandedDataDirectory,
    withIntermediateDirectories: true
)

let claudeBinary = bundle.bundleURL
    .appendingPathComponent("Contents/MacOS/Claude")
    .path

var arguments = [claudeBinary, "--user-data-dir=\(expandedDataDirectory)"]
arguments += CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("--user-data-dir=") }

let cArguments = arguments.map { strdup($0) } + [nil]
execv(claudeBinary, cArguments)
fail("could not start \(claudeBinary): \(String(cString: strerror(errno)))")
