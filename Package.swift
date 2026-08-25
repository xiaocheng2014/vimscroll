// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VimScroll",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "VimScroll", targets: ["VimScroll"])
    ],
    targets: [
        .executableTarget(
            name: "VimScroll",
            path: "VimScroll",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "VimScrollTests",
            dependencies: ["VimScroll"],
            path: "VimScrollTests"
        )
    ]
)
