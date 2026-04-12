// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TravelTranslator",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "TravelTranslatorCore", targets: ["TravelTranslatorCore"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TravelTranslatorCore",
            path: "TravelTranslator",
            exclude: ["App/TravelTranslatorApp.swift"],
            resources: [.process("Resources")]
        )
    ]
)
