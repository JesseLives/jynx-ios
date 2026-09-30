// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SalesKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "SalesKit", targets: ["SalesKit"])],
    targets: [
        .target(name: "SalesKit"),
        .testTarget(name: "SalesKitTests", dependencies: ["SalesKit"]),
    ]
)
