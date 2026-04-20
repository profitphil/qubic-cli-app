// make_icon.swift
// Renders the Qubic CLI app icon at 1024x1024 (App Store size).
// Usage:  swift make_icon.swift
// Output: AppIcon-1024.png next to this script.
//
// Visual: same dark plate + cyan rounded-bar aesthetic as the Qubic Wallet icon.
// Bars are arranged to spell "CLI".

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import AppKit   // NSColor only for convenience; drawing is all CoreGraphics

let size: CGFloat = 1024

// --- palette (sampled to match the Qubic Wallet tile) -----------------------
let bgTop    = CGColor(red: 0x15/255.0, green: 0x1E/255.0, blue: 0x27/255.0, alpha: 1) // subtle top sheen
let bgBottom = CGColor(red: 0x08/255.0, green: 0x0D/255.0, blue: 0x12/255.0, alpha: 1) // near-black with blue undertone
let cyan     = CGColor(red: 0x7F/255.0, green: 0xEE/255.0, blue: 0xDB/255.0, alpha: 1) // mint-cyan (QX Dashboard)
let cyanGlow = CGColor(red: 0x7F/255.0, green: 0xEE/255.0, blue: 0xDB/255.0, alpha: 0.35)

// --- layout -----------------------------------------------------------------
// iOS 14+ ignores baked-in corners and masks its own, so we fill the full square.
let stroke: CGFloat = 92                  // bar thickness (matches wallet)
let letterH: CGFloat = 560                // cap height
let letterW: CGFloat = 300                // width of C and L (I is narrower)
let iW: CGFloat = stroke
let gap: CGFloat = 56
let totalW = letterW + gap + letterW + gap + iW
let originX = (size - totalW) / 2
let originY = (size - letterH) / 2

// --- setup context ----------------------------------------------------------
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
guard let ctx = CGContext(
    data: nil, width: Int(size), height: Int(size),
    bitsPerComponent: 8, bytesPerRow: 0,
    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("CGContext") }

// --- background gradient plate ---------------------------------------------
let grad = CGGradient(colorsSpace: cs, colors: [bgTop, bgBottom] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(grad,
    start: CGPoint(x: 0, y: size),
    end: CGPoint(x: 0, y: 0),
    options: [])

// subtle vignette so the bars pop
ctx.saveGState()
let vignette = CGGradient(colorsSpace: cs,
    colors: [
        CGColor(red: 0, green: 0, blue: 0, alpha: 0),
        CGColor(red: 0, green: 0, blue: 0, alpha: 0.35)
    ] as CFArray,
    locations: [0, 1])!
ctx.drawRadialGradient(vignette,
    startCenter: CGPoint(x: size/2, y: size/2), startRadius: size*0.2,
    endCenter: CGPoint(x: size/2, y: size/2), endRadius: size*0.7,
    options: [])
ctx.restoreGState()

// --- helpers ----------------------------------------------------------------
func bar(_ rect: CGRect, radius: CGFloat? = nil) {
    let r = radius ?? stroke/2
    let path = CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
    // soft glow under the bar
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 18, color: cyanGlow)
    ctx.addPath(path)
    ctx.setFillColor(cyan)
    ctx.fillPath()
    ctx.restoreGState()
}

// --- C: three bars — left vertical, top horizontal, bottom horizontal ------
do {
    let x = originX
    let y = originY
    // left vertical
    bar(CGRect(x: x, y: y, width: stroke, height: letterH))
    // top horizontal
    bar(CGRect(x: x, y: y + letterH - stroke, width: letterW, height: stroke))
    // bottom horizontal
    bar(CGRect(x: x, y: y, width: letterW, height: stroke))
}

// --- L: two bars — left vertical, bottom horizontal ------------------------
do {
    let x = originX + letterW + gap
    let y = originY
    bar(CGRect(x: x, y: y, width: stroke, height: letterH))
    bar(CGRect(x: x, y: y, width: letterW, height: stroke))
}

// --- I: single vertical bar ------------------------------------------------
do {
    let x = originX + letterW + gap + letterW + gap
    let y = originY
    bar(CGRect(x: x, y: y, width: iW, height: letterH))
}

// --- top highlight (very subtle glass) -------------------------------------
ctx.saveGState()
let hl = CGGradient(colorsSpace: cs,
    colors: [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.06),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0)
    ] as CFArray,
    locations: [0, 1])!
ctx.drawLinearGradient(hl,
    start: CGPoint(x: 0, y: size),
    end: CGPoint(x: 0, y: size*0.55),
    options: [])
ctx.restoreGState()

// --- write PNG -------------------------------------------------------------
let image = ctx.makeImage()!
let outURL = URL(fileURLWithPath: CommandLine.arguments.first ?? ".")
    .deletingLastPathComponent()
    .appendingPathComponent("AppIcon-1024.png")
guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("dest")
}
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("wrote \(outURL.path)")
