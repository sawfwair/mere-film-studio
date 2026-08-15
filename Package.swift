// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MereFilmStudio",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "FilmStudioCore", targets: ["FilmStudioCore"]),
    ],
    targets: [
        .target(
            name: "FilmStudioCore",
            path: "Sources/FilmStudioCore"
        ),
        .testTarget(
            name: "FilmStudioCoreTests",
            dependencies: ["FilmStudioCore"],
            path: "Tests/FilmStudioCoreTests"
        ),
    ]
)
