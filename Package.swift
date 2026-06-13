// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MdView",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        // Pure-Foundation markdown parsing core. No SwiftUI / AppKit so it is
        // fully unit-testable (and portable).
        .target(
            name: "MarkdownKit",
            path: "Sources/MarkdownKit"
        ),
        // The SwiftUI app. Imports MarkdownKit for parsing.
        .executableTarget(
            name: "MdView",
            dependencies: ["MarkdownKit"],
            path: "Sources/MdView"
        ),
        .testTarget(
            name: "MarkdownKitTests",
            dependencies: ["MarkdownKit"],
            path: "Tests/MarkdownKitTests"
        ),
    ]
)
