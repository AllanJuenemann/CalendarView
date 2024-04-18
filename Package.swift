// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "CalendarView",
	platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "CalendarView",
            targets: ["CalendarView"]),
    ],
    targets: [
        .target(
            name: "CalendarView",
            resources: [.process("PrivacyInfo.xcprivacy")]),
    ]
)
