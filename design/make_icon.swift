// Draws the app icon from simple flat shapes and writes both a PNG (for Xcode) and an SVG (editable).
// Usage: swift make_icon.swift <out.png> <out.svg>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let S: CGFloat = 1024
// Palette
let bg = "#1F2A44", white = "#FFFFFF", yellow = "#FFC83D", orange = "#FF8A3D", red = "#F2453D"

// Geometry (y-down)
let pinC = CGPoint(x: 512, y: 370), pinR: CGFloat = 170, tip = CGPoint(x: 512, y: 730)
let holeR: CGFloat = 70
let rings: [(w: CGFloat, h: CGFloat, color: String)] = [(600, 210, yellow), (420, 148, orange), (240, 86, red)]

// Pin outline: tangent lines from tip to circle
let alpha = acos(pinR / (tip.y - pinC.y))
let a1 = CGFloat.pi / 2 - alpha, a2 = CGFloat.pi / 2 + alpha
let p1 = CGPoint(x: pinC.x + pinR * cos(a1), y: pinC.y + pinR * sin(a1))
let p2 = CGPoint(x: pinC.x + pinR * cos(a2), y: pinC.y + pinR * sin(a2))

// ---- SVG ----
func f(_ v: CGFloat) -> String { String(format: "%.1f", v) }
var svg = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <rect width="1024" height="1024" fill="\(bg)"/>

"""
for r in rings {
    svg += "  <ellipse cx=\"\(f(tip.x))\" cy=\"\(f(tip.y))\" rx=\"\(f(r.w / 2))\" ry=\"\(f(r.h / 2))\" fill=\"\(r.color)\"/>\n"
}
svg += "  <path d=\"M\(f(tip.x)),\(f(tip.y)) L\(f(p1.x)),\(f(p1.y)) A\(f(pinR)),\(f(pinR)) 0 1 0 \(f(p2.x)),\(f(p2.y)) Z\" fill=\"\(white)\"/>\n"
svg += "  <circle cx=\"\(f(pinC.x))\" cy=\"\(f(pinC.y))\" r=\"\(f(holeR))\" fill=\"\(bg)\"/>\n</svg>\n"

// ---- PNG ----
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.translateBy(x: 0, y: S); ctx.scaleBy(x: 1, y: -1)
func color(_ hex: String) -> CGColor {
    let v = UInt32(hex.dropFirst(), radix: 16)!
    return CGColor(colorSpace: cs, components: [CGFloat(v >> 16 & 255) / 255, CGFloat(v >> 8 & 255) / 255, CGFloat(v & 255) / 255, 1])!
}
ctx.setFillColor(color(bg)); ctx.fill(CGRect(x: 0, y: 0, width: S, height: S))
for r in rings {
    ctx.setFillColor(color(r.color))
    ctx.fillEllipse(in: CGRect(x: tip.x - r.w / 2, y: tip.y - r.h / 2, width: r.w, height: r.h))
}
let pin = CGMutablePath()
pin.move(to: tip); pin.addLine(to: p1)
pin.addArc(center: pinC, radius: pinR, startAngle: a1, endAngle: a2, clockwise: true)
pin.closeSubpath()
ctx.addPath(pin); ctx.setFillColor(color(white)); ctx.fillPath()
ctx.setFillColor(color(bg))
ctx.fillEllipse(in: CGRect(x: pinC.x - holeR, y: pinC.y - holeR, width: holeR * 2, height: holeR * 2))

let args = CommandLine.arguments
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil); CGImageDestinationFinalize(dest)
try! svg.write(toFile: args[2], atomically: true, encoding: .utf8)
