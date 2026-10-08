// swift-tools-version:5.9
//
// GaiaDeskEmbed: GaiaDesk support inside your macOS app.
//
// The Swift API (MIT) wraps libgaiadesk_embed, which ships as a prebuilt
// universal XCFramework (GaiaDesk Native Binary Licence, LICENSE-BINARY).
// `scripts/fetch-binary.sh <version>` puts it at Frameworks/; a GaiaDesk
// build of the library can be dropped there instead (see README).

import PackageDescription

let systemFrameworks: [LinkerSetting] = [
    "AppKit", "ApplicationServices", "AudioUnit", "AVFAudio", "AVFoundation", "Carbon", "CloudKit",
    "CoreAudio", "CoreData", "CoreFoundation", "CoreGraphics", "CoreImage", "CoreMedia", "CoreText",
    "CoreVideo", "CoreWLAN", "Foundation", "ImageIO", "IOKit", "IOSurface", "MediaToolbox", "Metal",
    "OpenGL", "QuartzCore", "ScreenCaptureKit", "Security", "SystemConfiguration", "VideoToolbox",
].map { .linkedFramework($0) } + [.linkedLibrary("iconv"), .linkedLibrary("objc")]

let package = Package(
    name: "GaiaDeskEmbed",
    platforms: [.macOS("12.3")],
    products: [
        .library(name: "GaiaDeskEmbed", targets: ["GaiaDeskEmbed"]),
        .executable(name: "HelpDeskDemo", targets: ["HelpDeskDemo"]),
    ],
    targets: [
        .binaryTarget(name: "GaiaDeskEmbedFFI", path: "Frameworks/GaiaDeskEmbedFFI.xcframework"),
        .target(
            name: "GaiaDeskEmbed",
            dependencies: ["GaiaDeskEmbedFFI"],
            linkerSettings: systemFrameworks
        ),
        .executableTarget(name: "HelpDeskDemo", dependencies: ["GaiaDeskEmbed"], path: "Examples/HelpDeskDemo"),
        .testTarget(name: "GaiaDeskEmbedTests", dependencies: ["GaiaDeskEmbed"]),
    ]
)
