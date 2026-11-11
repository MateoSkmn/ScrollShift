// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ScrollShift",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "ScrollShift", path: "Sources/ScrollShift")
    ]
)
