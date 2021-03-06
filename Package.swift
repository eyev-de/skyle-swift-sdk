// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SkyleSwiftSDK",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "SkyleSwiftSDK",
            targets: ["SkyleSwiftSDK"]),
    ],
    dependencies: [
        .package(url: "https://github.com/grpc/grpc-swift.git", from: "1.0.0-alpha.17"),
        .package(name: "NetUtils", url: "https://github.com/svdo/swift-netutils.git", from: "4.1.0"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "SkyleSwiftSDK",
            dependencies: ["Alamofire", .product(name: "GRPC", package: "grpc-swift"), "NetUtils"]),
        .testTarget(
            name: "SkyleSwiftSDKTests",
            dependencies: ["SkyleSwiftSDK"],
            swiftSettings: [SwiftSetting.define("Test")]),
    ]
)
