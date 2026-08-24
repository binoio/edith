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

// ── SVG twin of the icon, from the same geometry, for the web ────────────

func fmt(_ v: CGFloat) -> String {
    let s = String(format: "%.2f", v)
    return s.hasSuffix(".00") ? String(s.dropLast(3)) : s
}

func hex(_ c: NSColor) -> String {
    let rgb = c.usingColorSpace(.sRGB)!
    return String(format: "#%02X%02X%02X",
                  Int(round(rgb.redComponent * 255)),
                  Int(round(rgb.greenComponent * 255)),
                  Int(round(rgb.blueComponent * 255)))
}

func svgStroke(_ c: NSColor) -> String {
    let rgb = c.usingColorSpace(.sRGB)!
    let base = "stroke=\"\(hex(c))\""
    return rgb.alphaComponent < 1
        ? base + String(format: " stroke-opacity=\"%.2f\"", rgb.alphaComponent)
        : base
}

func svgPathData(_ path: CGPath) -> String {
    var d = ""
    path.applyWithBlock { elem in
        let p = elem.pointee
        switch p.type {
        case .moveToPoint:
            d += "M\(fmt(p.points[0].x)) \(fmt(p.points[0].y))"
        case .addLineToPoint:
            d += "L\(fmt(p.points[0].x)) \(fmt(p.points[0].y))"
        case .addQuadCurveToPoint:
            d += "Q\(fmt(p.points[0].x)) \(fmt(p.points[0].y)) \(fmt(p.points[1].x)) \(fmt(p.points[1].y))"
        case .addCurveToPoint:
            d += "C\(fmt(p.points[0].x)) \(fmt(p.points[0].y)) \(fmt(p.points[1].x)) \(fmt(p.points[1].y)) \(fmt(p.points[2].x)) \(fmt(p.points[2].y))"
        case .closeSubpath:
            d += "Z"
        @unknown default:
            break
        }
    }
    return d
}

func svgIcon() -> String {
    var union = CGPath(roundedRect: bars[0].rect, cornerWidth: 46, cornerHeight: 46, transform: nil)
    for bar in bars.dropFirst() {
        union = union.union(CGPath(roundedRect: bar.rect, cornerWidth: 46, cornerHeight: 46, transform: nil))
    }
    let eData = svgPathData(union)
    let squircleR = canvas * 0.2237

    // Gradient endpoints matching NSGradient's -60° fill of the full canvas
    let theta = -60.0 * .pi / 180
    let half = (canvas / 2) * (abs(CGFloat(cos(theta))) + abs(CGFloat(sin(theta))))
    let (dx, dy) = (CGFloat(cos(theta)) * half, CGFloat(sin(theta)) * half)
    let (cx, cy) = (canvas / 2, canvas / 2)

    var s = """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(Int(canvas)) \(Int(canvas))">
    <defs>
    <linearGradient id="fabric" gradientUnits="userSpaceOnUse" x1="\(fmt(cx - dx))" y1="\(fmt(cy - dy))" x2="\(fmt(cx + dx))" y2="\(fmt(cy + dy))">
    <stop offset="0" stop-color="\(hex(fabricLight))"/>
    <stop offset="1" stop-color="\(hex(fabricDark))"/>
    </linearGradient>
    <clipPath id="squircle"><rect width="\(Int(canvas))" height="\(Int(canvas))" rx="\(fmt(squircleR))"/></clipPath>
    <clipPath id="letter"><path d="\(eData)"/></clipPath>

    """
    for (i, bar) in bars.enumerated() {
        let r = bar.rect
        s += "<clipPath id=\"bar\(i)\"><rect x=\"\(fmt(r.minX))\" y=\"\(fmt(r.minY))\" width=\"\(fmt(r.width))\" height=\"\(fmt(r.height))\" rx=\"46\"/></clipPath>\n"
    }
    let shadow = color(0x4A4390, 0.35).usingColorSpace(.sRGB)!
    s += """
    <filter id="eshadow" x="-20%" y="-20%" width="140%" height="140%">
    <feDropShadow dx="0" dy="-14" stdDeviation="15" flood-color="\(hex(shadow))" flood-opacity="\(String(format: "%.2f", shadow.alphaComponent))"/>
    </filter>
    </defs>
    <g transform="translate(0,\(Int(canvas))) scale(1,-1)">
    <g clip-path="url(#squircle)">
    <rect width="\(Int(canvas))" height="\(Int(canvas))" fill="url(#fabric)"/>

    """

    // Woven texture, same alternation as the bitmap renderer
    for i in stride(from: CGFloat(0), through: canvas, by: 12) {
        let even = Int(i / 12) % 2 == 0
        s += "<line x1=\"\(fmt(i))\" y1=\"0\" x2=\"\(fmt(i))\" y2=\"\(Int(canvas))\" \(svgStroke(even ? weaveLight : weaveDark)) stroke-width=\"2.5\"/>\n"
        s += "<line x1=\"0\" y1=\"\(fmt(i))\" x2=\"\(Int(canvas))\" y2=\"\(fmt(i))\" \(svgStroke(even ? weaveDark : weaveLight)) stroke-width=\"2.5\"/>\n"
    }

    // Sewn patch border
    for (inset, width, c) in [(CGFloat(44), CGFloat(14), stitchShadow), (47, 11, stitchCream)] {
        let side = canvas - 2 * inset
        s += "<rect x=\"\(fmt(inset))\" y=\"\(fmt(inset))\" width=\"\(fmt(side))\" height=\"\(fmt(side))\" rx=\"\(fmt(side * 0.2237))\" fill=\"none\" \(svgStroke(c)) stroke-width=\"\(fmt(width))\" stroke-dasharray=\"34 26\" stroke-linecap=\"round\"/>\n"
    }

    // The E: shadow, then per-bar satin stitching, then the outline
    s += "<path d=\"\(eData)\" fill=\"\(hex(threadGold))\" filter=\"url(#eshadow)\"/>\n"
    for (i, bar) in bars.enumerated() {
        let r = bar.rect
        s += "<g clip-path=\"url(#letter)\"><g clip-path=\"url(#bar\(i))\">\n"
        s += "<rect x=\"\(fmt(r.minX - 8))\" y=\"\(fmt(r.minY - 8))\" width=\"\(fmt(r.width + 16))\" height=\"\(fmt(r.height + 16))\" fill=\"\(hex(threadGold))\"/>\n"
        let horizontal = r.width >= r.height
        let along = horizontal
            ? stride(from: r.minX - 8, through: r.maxX + 8, by: 10)
            : stride(from: r.minY - 8, through: r.maxY + 8, by: 10)
        var index = 0
        for pos in along {
            let drift = CGFloat(1.6 * sin(Double(pos) * 0.09))
            let (x1, y1, x2, y2) = horizontal
                ? (pos + drift, r.minY - 8, pos - drift, r.maxY + 8)
                : (r.minX - 8, pos + drift, r.maxX + 8, pos - drift)
            let c: NSColor
            switch index % 6 {
            case 0, 3: c = threadGoldHi
            case 1, 4: c = threadGold
            default:   c = threadGoldLo
            }
            s += "<line x1=\"\(fmt(x1))\" y1=\"\(fmt(y1))\" x2=\"\(fmt(x2))\" y2=\"\(fmt(y2))\" \(svgStroke(c)) stroke-width=\"8\" stroke-linecap=\"round\"/>\n"
            index += 1
        }
        s += "</g></g>\n"
    }
    s += "<path d=\"\(eData)\" fill=\"none\" \(svgStroke(outlineGold)) stroke-width=\"14\"/>\n"
    s += "</g>\n</g>\n</svg>\n"
    return s
}

func writeSVG(to path: String) {
    try! svgIcon().write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
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
    writeSVG(to: "docs/images/icon.svg")
}
