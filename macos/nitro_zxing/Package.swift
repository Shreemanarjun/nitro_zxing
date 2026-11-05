// swift-tools-version: 5.9
import PackageDescription

// C++ only (ffiPlugin, no pluginClass): same zxing-cpp + bridge layout as
// ios/nitro_zxing/Package.swift, minus the Swift plugin target.
let package = Package(
    name: "nitro_zxing",
    platforms: [.macOS(.v10_15)],
    products: [
        .library(name: "nitro-zxing", targets: ["NitroZxingCpp"]),
    ],
    dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework"),
  ],
  targets: [
        // zxing-cpp core (readers), symlinked from the vendored ../../src/zxing-cpp.
        // ZXingCoreConfig/Version.h replaces the header CMake would generate.
        .target(
            name: "ZXingCore",
            path: "Sources/ZXingCore",
            // nitro_zxing.bridge.g.swift: `nitrogen link` copies the Swift bridge
            // into every Sources/* dir, this symlinked one included.
            exclude: ["libzint", "ZXingC.cpp", "ZXingCpp.cpp", "nitro_zxing.bridge.g.swift"],
            publicHeadersPath: ".",
            cxxSettings: [
                .headerSearchPath("../ZXingCoreConfig"),
                .define("ZXING_INTERNAL"),
            ]
        ),
        .target(
            name: "NitroZxingCpp",
            dependencies: [
              "ZXingCore",
              .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            path: "Sources/NitroZxingCpp",
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("../ZXingCoreConfig"),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx20
)
