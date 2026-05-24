// Recolor the existing AppIcon (dark bg + cream "提") into the LightBlue
// alternate icon (white bg + blue "提"), preserving the exact glyph shape.
//
// Usage:
//   swift Scripts/recolor_icons.swift

import AppKit
import CoreGraphics
import Foundation

let repoRoot = URL(fileURLWithPath: CommandLine.arguments[0])
    .deletingLastPathComponent()  // Scripts/
    .deletingLastPathComponent()  // repo root
let sourcePath = repoRoot
    .appendingPathComponent("TLGX/Assets.xcassets/AppIcon.appiconset/appicon.png")
let outDir = repoRoot.appendingPathComponent("TLGX/AppIcons")

// Target colors for the new "LightBlue" variant.
let bgR: UInt8 = 255, bgG: UInt8 = 255, bgB: UInt8 = 255
let fgR: UInt8 = 0,   fgG: UInt8 = 48,  fgB: UInt8 = 224  // 更饱和的深蓝

// Sizes required for an iPhone + iPad alternate icon.
let sizes: [(suffix: String, px: Int)] = [
    ("@2x", 120),
    ("@3x", 180),
    ("@2x~ipad", 152),
    ("83.5@2x~ipad", 167),
]

guard let srcImage = NSImage(contentsOf: sourcePath),
      let srcCG = srcImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
else {
    FileHandle.standardError.write("failed to load \(sourcePath.path)\n".data(using: .utf8)!)
    exit(1)
}

// 1. Read source pixels once into RGBA8.
let srcW = srcCG.width
let srcH = srcCG.height
let srcBytesPerRow = srcW * 4
var srcPixels = [UInt8](repeating: 0, count: srcW * srcH * 4)
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let srcCtx = CGContext(
    data: &srcPixels,
    width: srcW,
    height: srcH,
    bitsPerComponent: 8,
    bytesPerRow: srcBytesPerRow,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { exit(1) }
srcCtx.draw(srcCG, in: CGRect(x: 0, y: 0, width: srcW, height: srcH))

// 2. Recolor in-place: lerp between bg/fg using luminance of source pixel.
//    Original art is essentially 2-tone, so this preserves anti-aliased edges.
//    First pass — find actual luma range so we can normalize; otherwise the
//    near-black background still has ~10% luma and bleeds blue into the bg.
var minLuma = 1.0
var maxLuma = 0.0
for i in stride(from: 0, to: srcPixels.count, by: 4) {
    let r = Double(srcPixels[i])
    let g = Double(srcPixels[i + 1])
    let b = Double(srcPixels[i + 2])
    let luma = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
    if luma < minLuma { minLuma = luma }
    if luma > maxLuma { maxLuma = luma }
}
let range = max(0.0001, maxLuma - minLuma)
for i in stride(from: 0, to: srcPixels.count, by: 4) {
    let r = Double(srcPixels[i])
    let g = Double(srcPixels[i + 1])
    let b = Double(srcPixels[i + 2])
    let luma = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
    // Normalize so min → 0 (pure bg/white), max → 1 (pure fg/blue).
    let t = min(1.0, max(0.0, (luma - minLuma) / range))
    let mr = Double(bgR) * (1 - t) + Double(fgR) * t
    let mg = Double(bgG) * (1 - t) + Double(fgG) * t
    let mb = Double(bgB) * (1 - t) + Double(fgB) * t
    srcPixels[i]     = UInt8(mr.rounded())
    srcPixels[i + 1] = UInt8(mg.rounded())
    srcPixels[i + 2] = UInt8(mb.rounded())
    srcPixels[i + 3] = 255
}

guard let recoloredCG = srcCtx.makeImage() else { exit(1) }

// 3. Downsample to each required size and write PNG.
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

for (suffix, px) in sizes {
    guard let outCtx = CGContext(
        data: nil,
        width: px,
        height: px,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { continue }
    outCtx.interpolationQuality = .high
    outCtx.draw(recoloredCG, in: CGRect(x: 0, y: 0, width: px, height: px))
    guard let cg = outCtx.makeImage() else { continue }
    let rep = NSBitmapImageRep(cgImage: cg)
    guard let data = rep.representation(using: .png, properties: [:]) else { continue }
    let url = outDir.appendingPathComponent("IconLightBlue\(suffix).png")
    try? data.write(to: url)
    print("wrote \(url.lastPathComponent) (\(px)×\(px))")
}
