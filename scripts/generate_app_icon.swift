import AppKit
import Foundation

struct IconRenderer {
    let canvasSize: CGFloat
    let context: CGContext

    var unit: CGFloat { canvasSize / 1024.0 }

    func color(_ hex: Int, alpha: CGFloat = 1.0) -> NSColor {
        NSColor(
            calibratedRed: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }

    func draw() {
        let iconRect = NSRect(
            x: 56 * unit,
            y: 56 * unit,
            width: canvasSize - (112 * unit),
            height: canvasSize - (112 * unit)
        )
        let cornerRadius = 232 * unit

        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -26 * unit),
            blur: 70 * unit,
            color: NSColor.black.withAlphaComponent(0.28).cgColor
        )
        let basePath = roundedPath(in: iconRect, radius: cornerRadius)
        color(0x0A1222).setFill()
        basePath.fill()
        context.restoreGState()

        context.saveGState()
        roundedPath(in: iconRect, radius: cornerRadius).addClip()

        drawBase(in: iconRect)
        drawGlows(in: iconRect)
        drawPanels(in: iconRect)
        drawEdgeHighlights(in: iconRect, radius: cornerRadius)

        context.restoreGState()

        let outline = roundedPath(in: iconRect, radius: cornerRadius)
        outline.lineWidth = 4 * unit
        color(0xFFFFFF, alpha: 0.15).setStroke()
        outline.stroke()
    }

    private func drawBase(in rect: NSRect) {
        drawLinearGradient(
            in: rect,
            colors: [
                color(0xBBF8FF),
                color(0x59B5FF),
                color(0x245BEB),
                color(0x08152D)
            ],
            locations: [0.0, 0.34, 0.72, 1.0],
            start: CGPoint(x: rect.minX, y: rect.maxY),
            end: CGPoint(x: rect.maxX, y: rect.minY)
        )

        let lowerWash = NSRect(
            x: rect.minX - 120 * unit,
            y: rect.minY - 40 * unit,
            width: rect.width * 1.15,
            height: rect.height * 0.44
        )
        fillEllipse(
            in: lowerWash,
            color: color(0x081B45, alpha: 0.42)
        )
    }

    private func drawGlows(in rect: NSRect) {
        fillGlow(
            in: NSRect(
                x: rect.minX - 60 * unit,
                y: rect.maxY - 292 * unit,
                width: 360 * unit,
                height: 360 * unit
            ),
            color: color(0xFFFFFF, alpha: 0.54),
            blur: 124 * unit
        )

        fillGlow(
            in: NSRect(
                x: rect.maxX - 430 * unit,
                y: rect.minY + 40 * unit,
                width: 360 * unit,
                height: 360 * unit
            ),
            color: color(0x53A7FF, alpha: 0.32),
            blur: 120 * unit
        )

        fillGlow(
            in: NSRect(
                x: rect.minX + 160 * unit,
                y: rect.minY + 50 * unit,
                width: 440 * unit,
                height: 220 * unit
            ),
            color: color(0x8DEFFF, alpha: 0.08),
            blur: 90 * unit
        )
    }

    private func drawPanels(in rect: NSRect) {
        let mainRect = NSRect(
            x: rect.minX + 140 * unit,
            y: rect.minY + 232 * unit,
            width: rect.width - 280 * unit,
            height: rect.height - 442 * unit
        )
        let backRect = mainRect.offsetBy(dx: -58 * unit, dy: 58 * unit)
        let pipRect = NSRect(
            x: mainRect.maxX - 252 * unit,
            y: mainRect.minY + 76 * unit,
            width: 230 * unit,
            height: 176 * unit
        )

        drawGlassPanel(
            in: backRect,
            radius: 106 * unit,
            colors: [
                color(0x13397A, alpha: 0.26),
                color(0x07142A, alpha: 0.12)
            ],
            highlightAlpha: 0.14,
            shadowAlpha: 0.17
        )

        drawCaptureCorners(around: mainRect)

        drawGlassPanel(
            in: mainRect,
            radius: 116 * unit,
            colors: [
                color(0xFFFFFF, alpha: 0.22),
                color(0xCDEEFF, alpha: 0.12),
                color(0x4D88FF, alpha: 0.06)
            ],
            highlightAlpha: 0.3,
            shadowAlpha: 0.24
        )
        drawWindowChrome(in: mainRect, compact: false)

        let streakRect = NSRect(
            x: mainRect.minX - 60 * unit,
            y: mainRect.maxY - 182 * unit,
            width: mainRect.width * 0.92,
            height: 86 * unit
        )
        context.saveGState()
        roundedPath(in: mainRect, radius: 116 * unit).addClip()
        drawDiagonalStreak(in: streakRect)
        context.restoreGState()

        drawGlassPanel(
            in: pipRect,
            radius: 56 * unit,
            colors: [
                color(0xF7FDFF, alpha: 0.3),
                color(0x99D6FF, alpha: 0.18),
                color(0x3D70FF, alpha: 0.12)
            ],
            highlightAlpha: 0.24,
            shadowAlpha: 0.22
        )
        drawWindowChrome(in: pipRect, compact: true)
    }

    private func drawWindowChrome(in rect: NSRect, compact: Bool) {
        let headerHeight = compact ? 34 * unit : 74 * unit
        let dividerY = rect.maxY - headerHeight

        let divider = NSBezierPath()
        divider.move(to: CGPoint(x: rect.minX + 26 * unit, y: dividerY))
        divider.line(to: CGPoint(x: rect.maxX - 26 * unit, y: dividerY))
        divider.lineWidth = compact ? 2 * unit : 3 * unit
        color(0xFFFFFF, alpha: compact ? 0.18 : 0.24).setStroke()
        divider.stroke()

        let dotRadius = compact ? 7 * unit : 12 * unit
        let dotGap = compact ? 18 * unit : 26 * unit
        let dotStartX = rect.minX + (compact ? 26 * unit : 40 * unit)
        let dotCenterY = rect.maxY - (compact ? 18 * unit : 36 * unit)
        let colors = [
            color(0xFFFFFF, alpha: compact ? 0.34 : 0.42),
            color(0xD6ECFF, alpha: compact ? 0.3 : 0.38),
            color(0xA6D3FF, alpha: compact ? 0.27 : 0.34)
        ]

        for index in 0..<3 {
            let x = dotStartX + CGFloat(index) * dotGap
            fillEllipse(
                in: NSRect(
                    x: x - dotRadius,
                    y: dotCenterY - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                ),
                color: colors[index]
            )
        }
    }

    private func drawCaptureCorners(around rect: NSRect) {
        let pad = 30 * unit
        let arm = 78 * unit
        let width = 20 * unit

        let path = NSBezierPath()
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.lineWidth = width

        path.move(to: CGPoint(x: rect.minX - pad, y: rect.maxY - arm))
        path.line(to: CGPoint(x: rect.minX - pad, y: rect.maxY + pad))
        path.line(to: CGPoint(x: rect.minX + arm, y: rect.maxY + pad))

        path.move(to: CGPoint(x: rect.maxX - arm, y: rect.maxY + pad))
        path.line(to: CGPoint(x: rect.maxX + pad, y: rect.maxY + pad))
        path.line(to: CGPoint(x: rect.maxX + pad, y: rect.maxY - arm))

        path.move(to: CGPoint(x: rect.minX - pad, y: rect.minY + arm))
        path.line(to: CGPoint(x: rect.minX - pad, y: rect.minY - pad))
        path.line(to: CGPoint(x: rect.minX + arm, y: rect.minY - pad))

        path.move(to: CGPoint(x: rect.maxX - arm, y: rect.minY - pad))
        path.line(to: CGPoint(x: rect.maxX + pad, y: rect.minY - pad))
        path.line(to: CGPoint(x: rect.maxX + pad, y: rect.minY + arm))

        color(0xFFFFFF, alpha: 0.78).setStroke()
        path.stroke()

        let glowPath = path.copy() as! NSBezierPath
        glowPath.lineWidth = width * 0.55
        context.saveGState()
        context.setShadow(
            offset: .zero,
            blur: 30 * unit,
            color: color(0x9FF1FF, alpha: 0.58).cgColor
        )
        color(0xD6FAFF, alpha: 0.94).setStroke()
        glowPath.stroke()
        context.restoreGState()
    }

    private func drawDiagonalStreak(in rect: NSRect) {
        context.saveGState()
        context.translateBy(x: rect.midX, y: rect.midY)
        context.rotate(by: -.pi / 10)
        let streak = NSRect(
            x: -rect.width / 2,
            y: -rect.height / 2,
            width: rect.width,
            height: rect.height
        )
        drawLinearGradient(
            in: streak,
            colors: [
                color(0xFFFFFF, alpha: 0.0),
                color(0xFFFFFF, alpha: 0.18),
                color(0xFFFFFF, alpha: 0.0)
            ],
            locations: [0.0, 0.5, 1.0],
            start: CGPoint(x: streak.minX, y: streak.midY),
            end: CGPoint(x: streak.maxX, y: streak.midY)
        )
        context.restoreGState()
    }

    private func drawGlassPanel(
        in rect: NSRect,
        radius: CGFloat,
        colors: [NSColor],
        highlightAlpha: CGFloat,
        shadowAlpha: CGFloat
    ) {
        let path = roundedPath(in: rect, radius: radius)

        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -18 * unit),
            blur: 32 * unit,
            color: NSColor.black.withAlphaComponent(shadowAlpha).cgColor
        )
        color(0xFFFFFF, alpha: 0.07).setFill()
        path.fill()
        context.restoreGState()

        context.saveGState()
        path.addClip()
        let locations = stride(from: 0, to: colors.count, by: 1).map {
            CGFloat($0) / CGFloat(max(colors.count - 1, 1))
        }
        drawLinearGradient(
            in: rect,
            colors: colors,
            locations: locations,
            start: CGPoint(x: rect.minX, y: rect.maxY),
            end: CGPoint(x: rect.maxX, y: rect.minY)
        )

        let highlightRect = NSRect(
            x: rect.minX + 10 * unit,
            y: rect.maxY - (rect.height * 0.36),
            width: rect.width * 0.74,
            height: rect.height * 0.18
        )
        fillGlow(
            in: highlightRect,
            color: color(0xFFFFFF, alpha: highlightAlpha),
            blur: 40 * unit
        )
        context.restoreGState()

        path.lineWidth = 3 * unit
        color(0xFFFFFF, alpha: 0.34).setStroke()
        path.stroke()

        let innerPath = roundedPath(in: rect.insetBy(dx: 8 * unit, dy: 8 * unit), radius: radius - (8 * unit))
        innerPath.lineWidth = 2 * unit
        color(0xFFFFFF, alpha: 0.08).setStroke()
        innerPath.stroke()
    }

    private func drawEdgeHighlights(in rect: NSRect, radius: CGFloat) {
        let topArc = roundedPath(
            in: rect.insetBy(dx: 24 * unit, dy: 24 * unit),
            radius: radius - (24 * unit)
        )
        context.saveGState()
        topArc.addClip()
        let shineRect = NSRect(
            x: rect.minX - 40 * unit,
            y: rect.maxY - 214 * unit,
            width: rect.width,
            height: 160 * unit
        )
        drawLinearGradient(
            in: shineRect,
            colors: [
                color(0xFFFFFF, alpha: 0.36),
                color(0xFFFFFF, alpha: 0.0)
            ],
            locations: [0.0, 1.0],
            start: CGPoint(x: shineRect.midX, y: shineRect.maxY),
            end: CGPoint(x: shineRect.midX, y: shineRect.minY)
        )
        context.restoreGState()
    }

    private func roundedPath(in rect: NSRect, radius: CGFloat) -> NSBezierPath {
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    }

    private func fillGlow(in rect: NSRect, color: NSColor, blur: CGFloat) {
        context.saveGState()
        context.setShadow(offset: .zero, blur: blur, color: color.cgColor)
        fillEllipse(in: rect, color: color)
        context.restoreGState()
    }

    private func fillEllipse(in rect: NSRect, color: NSColor) {
        let ellipse = NSBezierPath(ovalIn: rect)
        color.setFill()
        ellipse.fill()
    }

    private func drawLinearGradient(
        in rect: NSRect,
        colors: [NSColor],
        locations: [CGFloat],
        start: CGPoint,
        end: CGPoint
    ) {
        let cgColors = colors.map(\.cgColor) as CFArray
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: cgColors, locations: locations) else {
            return
        }

        context.saveGState()
        context.addRect(rect)
        context.clip()
        context.drawLinearGradient(gradient, start: start, end: end, options: [])
        context.restoreGState()
    }
}

func makeImage(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    guard let context = NSGraphicsContext.current?.cgContext else {
        fatalError("Unable to access graphics context")
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    let renderer = IconRenderer(canvasSize: CGFloat(size), context: context)
    renderer.draw()
    return image
}

func pngData(for image: NSImage) -> Data {
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        fatalError("Unable to encode PNG")
    }
    return png
}

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let defaultOutput = projectRoot.appendingPathComponent("CaptureInPicture/Assets.xcassets/AppIcon.appiconset")
let outputURL = CommandLine.arguments.dropFirst().first.map { URL(fileURLWithPath: $0) } ?? defaultOutput

let outputs: [(fileName: String, size: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

for output in outputs {
    let image = makeImage(size: output.size)
    let data = pngData(for: image)
    let fileURL = outputURL.appendingPathComponent(output.fileName)
    try data.write(to: fileURL)
    print("Wrote \(output.fileName)")
}
