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
            url: "https://github.com/bidmachine/BidMachine-SPM.git",
            exact: "3.7.2"
        ),
    ],
    targets: [
        .target(
            name: "GoogleBidMachineAdapter",
            dependencies: [
                .product(
                    name: "GoogleMobileAds",
                    package: "swift-package-manager-google-mobile-ads"
                ),
                .product(
                    name: "BidMachine",
                    package: "BidMachine-SPM"
                ),
            ],
            path: "adapters/BidMachine/BidMachineAdapter"
        ),
    ]
)
