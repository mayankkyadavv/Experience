// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ExperienceCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "ExperienceCore", targets: ["ExperienceCore"])],
    targets: [
        .target(name: "ExperienceCore"),
        .testTarget(
            name: "ExperienceCoreTests",
            dependencies: ["ExperienceCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
