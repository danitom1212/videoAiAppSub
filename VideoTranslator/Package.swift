// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VideoTranslator",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "VideoTranslator",
            targets: ["VideoTranslator"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/supabase-community/supabase-swift.git", from: "2.0.0"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0")
    ],
    targets: [
        .target(
            name: "VideoTranslator",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "Alamofire", package: "Alamofire")
            ],
            path: "VideoTranslator"
        ),
        .testTarget(
            name: "VideoTranslatorTests",
            dependencies: ["VideoTranslator"]
        ),
    ]
)
