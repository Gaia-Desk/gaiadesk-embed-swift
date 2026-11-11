// swift-tools-version:5.9
//
// GaiaDeskEmbed: GaiaDesk support inside your macOS app.
//
// The Swift API (MIT) wraps libgaiadesk_embed, which ships as a prebuilt
// universal XCFramework (GaiaDesk Native Binary Licence, LICENSE-BINARY),
// downloaded by SwiftPM from this repository's release and checked against
// the checksum below. To build against a local copy instead (e.g. one from
// `scripts/fetch-binary.sh`, or your own GaiaDesk build of the library) put it
// at Frameworks/GaiaDeskEmbedFFI.xcframework and set GAIADESK_EMBED_LOCAL_BINARY=1.

import PackageDescription

// Set by scripts/release.sh for each release.
let binaryVersion = "0.2.0"
let binaryChecksum = "1cd55c271752412e3bd1cd38b6c7259cac1db073cf4b09fd0239f9e5bacc2db5"

let ffi: Target = Context.environment["GAIADESK_EMBED_LOCAL_BINARY"] != nil
    ? .binaryTarget(name: "GaiaDeskEmbedFFI", path: "Frameworks/GaiaDeskEmbedFFI.xcframework")
    : .binaryTarget(
        name: "GaiaDeskEmbedFFI",
        url: "https://github.com/Gaia-Desk/gaiadesk-embed-swift/releases/download/v\(binaryVersion)/GaiaDeskEmbedFFI.xcframework.zip",
        checksum: binaryChecksum
    )

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
        ffi,
        .target(
            name: "GaiaDeskEmbed",
            dependencies: ["GaiaDeskEmbedFFI"],
            linkerSettings: systemFrameworks
        ),
        .executableTarget(name: "HelpDeskDemo", dependencies: ["GaiaDeskEmbed"], path: "Examples/HelpDeskDemo"),
        .testTarget(name: "GaiaDeskEmbedTests", dependencies: ["GaiaDeskEmbed"]),
    ]
)
