// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "Tabs",
  platforms: [.macOS(.v13)],
  products: [
    .library(name: "Tabs", targets: ["Tabs"]),
  ],
  dependencies: [
    .package(url: "https://github.com/qvacua/material-icons", from: "0.2.0"),
    .package(url: "https://github.com/PureLayout/PureLayout", from: "3.1.9"),
  ],
  targets: [
    .target(
      name: "Tabs",
      dependencies: [
        "PureLayout",
        .product(name: "MaterialIcons", package: "material-icons"),
      ]
    ),
  ]
)
