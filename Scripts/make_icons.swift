// Generates alternate app icon PNGs for TLGX.
//
// Run with:
//   swift TLGX/AppIcons/make_icons.swift
//
// Drops PNGs into TLGX/AppIcons/ — these files must be added as Resources
// of the app target so the bundle contains them at the top level.

import AppKit
import CoreGraphics
import Foundation

struct IconSpec {
    let name: String
    let background: NSColor
    let text: String
    let textColor: NSColor
}

// Sizes required by iOS for an alternate icon, both iPhone and iPad.
// Filename suffix convention:
//   Name@2x.png        — iPhone 60pt @2x (120)
//   Name@3x.png        — iPhone 60pt @3x (180)
//   Name@2x~ipad.png   — iPad 76pt @2x   (152)
//   Name83.5@2x~ipad.png — iPad 83.5pt @2x (167)
let sizes: [(suffix: String, px: Int)] = [
    ("@2x", 120),
    ("@3x", 180),
    ("@2x~ipad", 152),
    ("83.5@2x~ipad", 167),
]

let icons: [IconSpec] = [
    IconSpec(
        name: "IconLightBlue",
        background: NSColor.white,
        text: "提",
        textColor: NSColor(red: 0.0, green: 0.47, blue: 0.95, alpha: 1)
    ),
]

func render(_ spec: IconSpec, px: Int) -> Data? {
    let size = CGFloat(px)
    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    guard let ctx = CGContext(
        data: nil,
        width: px,
        height: px,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    // Background — full-bleed; iOS applies its own corner mask.
    ctx.setFillColor(spec.background.cgColor)
    ctx.fill(rect)

    // Text rendering: use NSAttributedString routed through Core Text via
    // NSGraphicsContext so we don't need to manage CTLine ourselves.
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

    let pointSize = size * 0.62
    let font: NSFont = NSFont.systemFont(ofSize: pointSize, weight: .heavy)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: spec.textColor,
    ]
    let str = spec.text as NSString
    let bounds = str.size(withAttributes: attrs)
    // Visually center: optical center for Chinese characters sits slightly
    // higher than the geometric center because of the leading.
    let origin = NSPoint(
        x: (size - bounds.width) / 2,
        y: (size - bounds.height) / 2 - size * 0.04
    )
    str.draw(at: origin, withAttributes: attrs)

    NSGraphicsContext.restoreGraphicsState()

    guard let cg = ctx.makeImage() else { return nil }
    let rep = NSBitmapImageRep(cgImage: cg)
    return rep.representation(using: .png, properties: [:])
}

let outDir = URL(fileURLWithPath: CommandLine.arguments.first ?? "")
    .deletingLastPathComponent()

for spec in icons {
    for (suffix, px) in sizes {
        guard let data = render(spec, px: px) else {
            FileHandle.standardError.write("Failed to render \(spec.name)\(suffix).png\n".data(using: .utf8)!)
            continue
        }
        let url = outDir.appendingPathComponent("\(spec.name)\(suffix).png")
        try? data.write(to: url)
        print("wrote \(url.lastPathComponent) (\(px)×\(px))")
    }
}
