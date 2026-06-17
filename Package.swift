// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DashBar",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "DashBar",
            path: "Sources/DashBar",
            resources: [
                .process("Web/popover.html"),
                .process("Resources/AppIcon.icns"),
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
