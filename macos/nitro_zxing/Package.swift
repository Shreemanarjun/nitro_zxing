// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "nitro_zxing",
  platforms: [.macOS(.v10_15)],
  products: [
    .library(name: "nitro-zxing", targets: ["nitro_zxing"])
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework"),
  ],
  targets: [
    .target(
      name: "NitroZxingCpp",
      path: "Sources/NitroZxingCpp",
      publicHeadersPath: "include",
      cxxSettings: [
        .headerSearchPath("include"),
        .unsafeFlags(["-std=c++17"])
      ]
    ),
    .target(
      name: "nitro_zxing",
      dependencies: [
        "NitroZxingCpp",
        .product(name: "FlutterFramework", package: "FlutterFramework"),
      ],
      path: "Sources/NitroZxing"
    )
  ]
)
