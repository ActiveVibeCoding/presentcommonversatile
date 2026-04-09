// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VibeDrive",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .executable(name: "VibeDrive", targets: ["VibeDrive"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "VibeDrive",
            dependencies: [],
            path: "Sources"
        )
    ]
)
