// swift-tools-version: 5.9
// Swift Package Manager manifest; CocoaPods uses ../foldable_device.podspec.
import PackageDescription

let package = Package(
    name: "foldable_device",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "foldable-device", targets: ["foldable_device"])
    ],
    dependencies: [],
    targets: [
        .target(name: "foldable_device", dependencies: [])
    ]
)
