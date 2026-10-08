// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "liquid_shell_ios",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "liquid-shell-ios", targets: ["liquid_shell_ios"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "liquid_shell_ios",
            dependencies: [],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
