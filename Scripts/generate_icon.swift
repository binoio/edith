#!/usr/bin/env swift
//
// generate_icon.swift: Programmatically render Edith's app icon — a stitched
// (embroidered) letter E on a fabric squircle — into the asset catalog.
//
// Usage: xcrun swift Scripts/generate_icon.swift [preview-only-output.png]
//   With an argument, renders only a 1024px preview PNG to that path.
//   Without, writes every size into Edith/Assets.xcassets/AppIcon.appiconset.

import AppKit

let canvas: CGFloat = 1024

func color(_ hex: UInt32, _ alpha: CGFloat = 1.0) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

// Palette: keep the lavender + gold identity of the existing icon
let fabricLight   = color(0xE6E4F7)
let fabricDark    = color(0xC7C3EA)
let weaveLight    = color(0xFFFFFF, 0.10)
let weaveDark     = color(0x6B64B8, 0.07)
let threadGold    = color(0xF2C23E)
let threadGoldHi  = color(0xFFDD6E)
let threadGoldLo  = color(0xD69E1F)
let outlineGold   = color(0xB07E10)
let stitchCream   = color(0xFFF6DE)
let stitchShadow  = color(0x8A81C9, 0.55)

// The letter E, built from four overlapping rounded bars (union via nonzero
// winding). Bars are also kept individually for the running-stitch centerlines.
struct Bar { let rect: NSRect }
let barThickness: CGFloat = 132
let bars: [Bar] = [
    Bar(rect: NSRect(x: 268, y: 176, width: barThickness, height: 672)),            // spine
    Bar(rect: NSRect(x: 268, y: 716, width: 492, height: barThickness)),            // top arm
    Bar(rect: NSRect(x: 268, y: 446, width: 420, height: barThickness)),            // middle arm
    Bar(rect: NSRect(x: 268, y: 176, width: 492, height: barThickness)),            // bottom arm
]

func ePath() -> NSBezierPath {
    // A true union so fills, clips, and strokes see only the outer outline of
    // the letter, with no seams where the bars overlap
    var union = CGPath(roundedRect: bars[0].rect, cornerWidth: 46, cornerHeight: 46, transform: nil)
    for bar in bars.dropFirst() {
        union = union.union(CGPath(roundedRect: bar.rect, cornerWidth: 46, cornerHeight: 46, transform: nil))
    }
    return NSBezierPath(cgPath: union)
}

func squirclePath(inset: CGFloat = 0) -> NSBezierPath {
    // Approximation of the macOS squircle; fills the full canvas (Tahoe style)
    let r = NSRect(x: inset, y: inset, width: canvas - 2 * inset, height: canvas - 2 * inset)
    let radius = (canvas - 2 * inset) * 0.2237
    return NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius)
}

func drawIcon() {
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }

    // ── Fabric background, filling the squircle edge-to-edge ─────────────
    squirclePath().addClip()
    let gradient = NSGradient(colors: [fabricLight, fabricDark])!
    gradient.draw(in: NSRect(x: 0, y: 0, width: canvas, height: canvas), angle: -60)

    // Woven texture: fine alternating threads in both directions
    let weaveSpacing: CGFloat = 12
    for i in stride(from: CGFloat(0), through: canvas, by: weaveSpacing) {
        let stripe = NSBezierPath()
        stripe.lineWidth = 2.5
        stripe.move(to: NSPoint(x: i, y: 0)); stripe.line(to: NSPoint(x: i, y: canvas))
        (Int(i / weaveSpacing) % 2 == 0 ? weaveLight : weaveDark).setStroke()
        stripe.stroke()
        let stripe2 = NSBezierPath()
        stripe2.lineWidth = 2.5
        stripe2.move(to: NSPoint(x: 0, y: i)); stripe2.line(to: NSPoint(x: canvas, y: i))
        (Int(i / weaveSpacing) % 2 == 0 ? weaveDark : weaveLight).setStroke()
        stripe2.stroke()
    }

    // ── Sewn patch border: running stitch just inside the squircle edge ──
    let border = squirclePath(inset: 44)
    border.lineWidth = 14
    border.setLineDash([34, 26], count: 2, phase: 0)
    border.lineCapStyle = .round
    stitchShadow.setStroke()
    border.stroke()
    let borderHi = squirclePath(inset: 47)
    borderHi.lineWidth = 11
    borderHi.setLineDash([34, 26], count: 2, phase: 0)
    borderHi.lineCapStyle = .round
    stitchCream.setStroke()
    borderHi.stroke()

    // ── The E: soft shadow, satin-stitch thread fill, outline ────────────
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30,
                  color: color(0x4A4390, 0.35).cgColor)
    threadGold.setFill()
    ePath().fill()
    ctx.restoreGState()

    // Satin stitch: threads run perpendicular to each bar, the way a letter
    // is actually embroidered — the direction change marks each stitched
    // segment. The spine is stitched first, arms lie over it.
    let threadSpacing: CGFloat = 10
    for bar in bars {
        NSGraphicsContext.current?.saveGraphicsState()
        NSBezierPath(roundedRect: bar.rect, xRadius: 46, yRadius: 46).addClip()
        ePath().addClip()
        let horizontal = bar.rect.width >= bar.rect.height
        // Solid base under this segment's threads so the layer below never
        // peeks through the gaps where segments overlap
        threadGold.setFill()
        NSBezierPath(rect: bar.rect.insetBy(dx: -8, dy: -8)).fill()
        let along = horizontal
            ? stride(from: bar.rect.minX - 8, through: bar.rect.maxX + 8, by: threadSpacing)
            : stride(from: bar.rect.minY - 8, through: bar.rect.maxY + 8, by: threadSpacing)
        var index = 0
        for pos in along {
            let thread = NSBezierPath()
            thread.lineWidth = 8
            thread.lineCapStyle = .round
            // A touch of drift so the threads look laid by hand
            let drift = 1.6 * sin(Double(pos) * 0.09)
            if horizontal {
                thread.move(to: NSPoint(x: pos + drift, y: bar.rect.minY - 8))
                thread.line(to: NSPoint(x: pos - drift, y: bar.rect.maxY + 8))
            } else {
                thread.move(to: NSPoint(x: bar.rect.minX - 8, y: pos + drift))
                thread.line(to: NSPoint(x: bar.rect.maxX + 8, y: pos - drift))
            }
            switch index % 6 {
            case 0, 3: threadGoldHi.setStroke()
            case 1, 4: threadGold.setStroke()
            default:   threadGoldLo.setStroke()
            }
            thread.stroke()
            index += 1
        }
        NSGraphicsContext.current?.restoreGraphicsState()
    }

    // Outline around the whole letter
    let outline = ePath()
    outline.lineWidth = 14
    outlineGold.setStroke()
    outline.stroke()

}

func render(size: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    context.imageInterpolation = .high
    NSGraphicsContext.current = context
    let scale = CGFloat(size) / canvas
    context.cgContext.scaleBy(x: scale, y: scale)
    drawIcon()
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func writePNG(_ rep: NSBitmapImageRep, to path: String) {
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}

let args = CommandLine.arguments
if args.count > 1 {
    writePNG(render(size: 1024), to: args[1])
} else {
    let iconset = "Edith/Assets.xcassets/AppIcon.appiconset"
    let sizes = [("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
                 ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
                 ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
                 ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
                 ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)]
    for (name, size) in sizes {
        writePNG(render(size: size), to: "\(iconset)/\(name)")
    }
}
