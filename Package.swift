// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "MCPManager",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "MCPManager",
            path: "Sources/MCPManager",
            linkerSettings: [
                .linkedFramework("Security")
            ]
        )
    ]
)
