// swift-tools-version: 6.1
// This is a Skip (https://skip.dev) package.
import PackageDescription

let package = Package(
    name: "orthodoxkorea-app",
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "OrthodoxKorea", type: .dynamic, targets: ["OrthodoxKorea"]),
    ],
    dependencies: [
        .package(url: "https://source.skip.tools/skip.git", from: "1.8.4"),
        .package(url: "https://source.skip.tools/skip-fuse-ui.git", from: "1.14.3"),
        .package(url: "https://source.skip.tools/skip-web.git", from: "0.9.1"),
        .package(url: "https://github.com/OneSignal/OneSignal-XCFramework.git", from: "5.5.0")
    ],
    targets: [
        .target(name: "OrthodoxKorea", dependencies: [
            .product(name: "SkipFuseUI", package: "skip-fuse-ui"),
            .product(name: "SkipWeb", package: "skip-web"),
            .product(name: "OneSignalFramework", package: "OneSignal-XCFramework",
                     condition: .when(platforms: [.iOS, .macOS]))
        ], resources: [.process("Resources")], plugins: [.plugin(name: "skipstone", package: "skip")]),
    ]
)
