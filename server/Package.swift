// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "server",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "Joshinkan", targets: ["Joshinkan"]),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser.git", .upToNextMajor(from: "1.0.0"))
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
    .systemLibrary(
      name: "libcurl",
      pkgConfig: "curl",
      providers: [
        .apt(["libcurl4-openssl-dev"]),
        .brew(["curl"])
      ]
    ),
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .executableTarget(
      name: "Joshinkan",
      dependencies: [
        .target(name: "libfcgi"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .target(name: "libcurl")
      ],
      // path: "Sources",
      swiftSettings: [
        .enableUpcomingFeature("BareSlashRegexLiterals")
      ]
    ),
//    .executableTarget(
//      name: "joshinkand",
//      dependencies: [.target(name: "libjoshinkan")]
//    ),
    .testTarget(
      name: "JoshinkanTests",
      dependencies: [
        .target(name: "Joshinkan")
      ],
      path: "Tests",
      resources: [
        .process("adult-registration.request"),
        .process("registration-no-privacy.request"),
        .process("child-registration.request"),
        .process("children-registration.request"),
        .process("print-env.request")
      ],
      swiftSettings: [
        .enableUpcomingFeature("BareSlashRegexLiterals")
      ]
    )
  ]
)
