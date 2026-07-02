// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DOACBorderApp",
    platforms: [.macOS(.v13)],
    dependencies: [
        // Pinned to 0.24.0: 0.25.0+ adds a #Preview macro in SVGView.swift that
        // requires the PreviewsMacros plugin, which only ships with Xcode.app
        // (not the Command Line Tools toolchain), so `swift build` fails on 0.25+.
        .package(url: "https://github.com/swhitty/SwiftDraw.git", exact: "0.24.0")
    ],
    targets: [
        .executableTarget(
            name: "DOACBorderApp",
            dependencies: ["SwiftDraw"]
        ),
        .testTarget(
            name: "DOACBorderAppTests",
            dependencies: ["DOACBorderApp"]
        )
    ]
)
