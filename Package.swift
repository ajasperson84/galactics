// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StickballTracker",
    platforms: [.iOS(.v17)],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.19.0"),
    ],
    targets: [
        .target(
            name: "StickballTracker",
            dependencies: [
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
            ],
            path: "StickballTracker"
        ),
    ]
)
