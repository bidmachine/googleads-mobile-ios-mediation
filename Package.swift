// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GoogleBidMachineAdapter",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "GoogleBidMachineAdapter",
            targets: ["GoogleBidMachineAdapter"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/googleads/swift-package-manager-google-mobile-ads.git",
            exact: "13.0.0"
        ),
        .package(
            url: "https://github.com/bidmachine/OMSDK-Appodeal-iOS-Package",
            from: "1.6.3"
        ),
    ],
    targets: [
        .binaryTarget(
            name: "BidMachine",
            url: "https://bidmachine-ios.s3.amazonaws.com/BidMachine/3.7.2-beta.0/package/BidMachine.xcframework.zip",
            checksum: "39787f0e9d494446b20122fab44f580133fbaabd32c0ca37e97413e3a8e6accc"
        ),
        .target(
            name: "GoogleBidMachineAdapter",
            dependencies: [
                .product(
                    name: "GoogleMobileAds",
                    package: "swift-package-manager-google-mobile-ads"
                ),
                "BidMachine",
                .product(
                    name: "OMSDK_Appodeal",
                    package: "OMSDK-Appodeal-iOS-Package"
                ),
            ],
            path: "adapters/BidMachine/BidMachineAdapter",
            linkerSettings: [
                .linkedFramework("AdSupport"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AVKit"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("CFNetwork"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreImage"),
                .linkedFramework("CoreLocation"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreTelephony"),
                .linkedFramework("ImageIO"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("SafariServices"),
                .linkedFramework("Security"),
                .linkedFramework("StoreKit"),
                .linkedFramework("SystemConfiguration"),
                .linkedFramework("UIKit"),
                .linkedFramework("WebKit"),
                .linkedFramework("AppTrackingTransparency", .when(platforms: [.iOS])),
                .linkedLibrary("z", .when(platforms: [.iOS])),
                .linkedLibrary("sqlite3", .when(platforms: [.iOS])),
                .linkedLibrary("xml2", .when(platforms: [.iOS])),
            ]
        ),
    ]
)
