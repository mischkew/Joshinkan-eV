// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "server",
    dependencies: [
      //.package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMajor(from: "1.0.0")),
    ],
    targets: [
        .systemLibrary(
          name: "libfcgi",
          pkgConfig: "fcgi",
          providers: [
            .apt(["libfcgi"]),
            .brew(["fcgi"])
          ]
        ),
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "server",
            dependencies: [
              .target(name: "libfcgi")
            ],
            path: "Sources"
        )
    ]
)
