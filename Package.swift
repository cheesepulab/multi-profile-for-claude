// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "MultiProfileForClaude",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MultiProfileForClaude",
            path: "Sources/MultiProfileForClaude"
        ),
        .executableTarget(
            name: "ProfileLauncher",
            path: "Sources/ProfileLauncher"
        ),
        .testTarget(
            name: "MultiProfileForClaudeTests",
            dependencies: ["MultiProfileForClaude"],
            path: "Tests/MultiProfileForClaudeTests"
        ),
    ]
)
