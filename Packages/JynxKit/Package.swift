// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "JynxKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "JynxKit", targets: ["JynxKit"])],
    targets: [
        .target(name: "JynxKit"),
        .testTarget(name: "JynxKitTests", dependencies: ["JynxKit"], resources: [.copy("Fixtures")]),
    ]
)
