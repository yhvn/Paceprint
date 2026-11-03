import AppKit
import CoreGraphics

// Paceprint app icon, per #16: dark background, a short pace-gradient Route stroke (green → yellow → red),
// red start dot, green end dot, no wordmark. Renders the three 1024 px asset-catalog variants.

let size = 1024.0
let out = CommandLine.arguments[1]

struct RGB { var r, g, b: Double }
let fast = RGB(r: 0x4A / 255.0, g: 0xE2 / 255.0, b: 0x7A / 255.0)
let mid = RGB(r: 0xFF / 255.0, g: 0xE0 / 255.0, b: 0x55 / 255.0)
let slow = RGB(r: 0xFF / 255.0, g: 0x4D / 255.0, b: 0x4D / 255.0)

func lerp(_ a: RGB, _ b: RGB, _ t: Double) -> RGB {
    RGB(r: a.r + (b.r - a.r) * t, g: a.g + (b.g - a.g) * t, b: a.b + (b.b - a.b) * t)
}
func pace(_ t: Double) -> RGB { t < 0.5 ? lerp(fast, mid, t * 2) : lerp(mid, slow, (t - 0.5) * 2) }

/// A cubic Bézier route, an easy S from bottom-left to top-right, sampled into points.
func bezier(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, steps: Int) -> [CGPoint] {
    (0...steps).map { i in
        let t: Double = Double(i) / Double(steps), u: Double = 1 - t
        let a: Double = u * u * u, b: Double = 3 * u * u * t, c: Double = 3 * u * t * t, d: Double = t * t * t
        let x: Double = a * p0.x + b * p1.x + c * p2.x + d * p3.x
        let y: Double = a * p0.y + b * p1.y + c * p2.y + d * p3.y
        return CGPoint(x: x, y: y)
    }
}
// CoreGraphics y runs up.
let route = bezier(CGPoint(x: 250, y: 270), CGPoint(x: 820, y: 230), CGPoint(x: 160, y: 820), CGPoint(x: 770, y: 760), steps: 400)

enum Variant: String, CaseIterable { case light = "AppIcon", dark = "AppIcon-Dark", tinted = "AppIcon-Tinted" }

func render(_ variant: Variant) -> Data {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    func color(_ c: RGB, _ a: Double = 1) -> CGColor {
        if variant == .tinted {
            let l = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
            // Tinted icons are grayscale: brighter = more tint. Lift everything so the stroke reads.
            let v = min(1, 0.55 + l * 0.45)
            return CGColor(srgbRed: v, green: v, blue: v, alpha: a)
        }
        return CGColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: a)
    }

    // Background: the design's night map, slightly lighter at the top. The dark variant is left
    // transparent so the system's dark backdrop shows; tinted is black.
    switch variant {
    case .light:
        let gradient = CGGradient(colorsSpace: space, colors: [
            CGColor(srgbRed: 0x11 / 255.0, green: 0x15 / 255.0, blue: 0x1C / 255.0, alpha: 1),
            CGColor(srgbRed: 0x08 / 255.0, green: 0x09 / 255.0, blue: 0x0C / 255.0, alpha: 1),
        ] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: 0, y: 0), options: [])
    case .tinted:
        ctx.setFillColor(CGColor(gray: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
    case .dark:
        break
    }

    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    // Halo under the whole Route.
    ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.18))
    ctx.setLineWidth(118)
    ctx.addLines(between: route)
    ctx.strokePath()

    // The Route in pace colors: short overlapping segments blended along its length.
    ctx.setLineWidth(76)
    for i in 0..<(route.count - 1) {
        ctx.setStrokeColor(color(pace(Double(i) / Double(route.count - 2))))
        ctx.move(to: route[i])
        ctx.addLine(to: route[i + 1])
        ctx.strokePath()
    }

    // Start (red) and finish (green) dots in white rings.
    for (point, c) in [(route.first!, slow), (route.last!, fast)] {
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: point.x - 62, y: point.y - 62, width: 124, height: 124))
        ctx.setFillColor(color(c))
        ctx.fillEllipse(in: CGRect(x: point.x - 42, y: point.y - 42, width: 84, height: 84))
    }

    let image = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    return rep.representation(using: .png, properties: [:])!
}

for variant in Variant.allCases {
    try! render(variant).write(to: URL(fileURLWithPath: "\(out)/\(variant.rawValue).png"))
}
print("ok")
