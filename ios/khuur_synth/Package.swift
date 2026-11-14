// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "khuur_synth",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "khuur-synth", targets: ["khuur_synth"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .binaryTarget(name: "FluidSynth", path: "FluidSynth.xcframework"),
        .target(
            name: "khuur_synth",
            dependencies: [
                "FluidSynth",
                .product(name: "FlutterFramework", package: "FlutterFramework"),
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        ),
    ]
)
