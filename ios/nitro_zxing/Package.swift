// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "nitro_zxing",
    platforms: [.iOS(.v13)],
    products: [
        .library(name: "nitro-zxing", targets: ["nitro_zxing"]),
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
        // C/C++ bridge — SPM requires Swift and C++ in separate targets.
        // nitro headers (nitro.h, dart_api_dl.h …) are copied into include/
        // by `nitrogen link`, so no extra header search path is needed.
        .target(
            name: "NitroZxingCpp",
            dependencies: ["ZXingCore"],
            path: "Sources/NitroZxingCpp",
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("../ZXingCoreConfig"),
            ]
        ),
        // Swift implementation + generated bridge.
        .target(
            name: "nitro_zxing",
            dependencies: [
                "NitroZxingCpp",
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            path: "Sources/NitroZxing"
        ),
    ],
    cxxLanguageStandard: .cxx20
)
