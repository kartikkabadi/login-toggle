// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LoginToggle",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "LoginToggleCore", path: "Sources/LoginToggleCore"),
        .executableTarget(name: "LoginToggle", dependencies: ["LoginToggleCore"], path: "Sources/LoginToggle"),
        .testTarget(name: "LoginToggleTests", dependencies: ["LoginToggleCore"], path: "Tests/LoginToggleTests")
    ]
)
