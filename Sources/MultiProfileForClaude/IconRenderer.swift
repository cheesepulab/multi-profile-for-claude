import AppKit

/// Draws profile icons: the user's own Claude icon with a colored letter badge.
enum IconRenderer {
    private static let iconsetSizes: [(name: String, pixels: Int)] = [
        ("16x16", 16), ("16x16@2x", 32),
        ("32x32", 32), ("32x32@2x", 64),
        ("128x128", 128), ("128x128@2x", 256),
        ("256x256", 256), ("256x256@2x", 512),
        ("512x512", 512), ("512x512@2x", 1024),
    ]

    struct RenderError: LocalizedError {
        var errorDescription: String? { "Could not draw the profile icon." }
    }

    static func writeProfileIcns(base: NSImage, color: NSColor, letter: String, to destination: URL) throws {
        let iconset = FileManager.default.temporaryDirectory
            .appendingPathComponent("mpfc-\(UUID().uuidString).iconset", isDirectory: true)
        try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: iconset) }

        for size in iconsetSizes {
            let png = try renderPNG(pixels: size.pixels) { rect in
                base.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
                drawBadge(in: rect, color: color, letter: letter)
            }
            try png.write(to: iconset.appendingPathComponent("icon_\(size.name).png"))
        }
        try Shell.run("/usr/bin/iconutil", ["-c", "icns", iconset.path, "-o", destination.path])
    }

    /// Small colored square with the profile letter, used in the menu bar.
    static func menuBarImage(color: NSColor, letter: String) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let square = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 4.5, yRadius: 4.5)
            color.setFill()
            square.fill()
            drawLetter(letter, in: rect, fontSize: 11)
            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: Drawing

    static func renderPNG(pixels: Int, draw: (NSRect) -> Void) throws -> Data {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { throw RenderError() }
        rep.size = NSSize(width: pixels, height: pixels)

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else { throw RenderError() }
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        draw(NSRect(x: 0, y: 0, width: pixels, height: pixels))
        context.flushGraphics()

        guard let png = rep.representation(using: .png, properties: [:]) else { throw RenderError() }
        return png
    }

    /// Badge in the lower-right corner, inside the standard macOS icon margin.
    static func drawBadge(in rect: NSRect, color: NSColor, letter: String) {
        let s = rect.width
        let diameter = s * 0.44
        let ring = max(1, s * 0.035)
        let center = NSPoint(x: rect.minX + s * 0.73, y: rect.minY + s * 0.27)

        let outer = NSRect(
            x: center.x - diameter / 2 - ring, y: center.y - diameter / 2 - ring,
            width: diameter + ring * 2, height: diameter + ring * 2
        )
        NSColor.white.setFill()
        NSBezierPath(ovalIn: outer).fill()

        let inner = NSRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
        color.setFill()
        NSBezierPath(ovalIn: inner).fill()

        drawLetter(letter, in: inner, fontSize: diameter * 0.58)
    }

    static func drawLetter(_ letter: String, in rect: NSRect, fontSize: CGFloat) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
        let text = NSAttributedString(string: letter, attributes: attributes)
        let bounds = text.boundingRect(with: rect.size, options: [.usesLineFragmentOrigin, .usesFontLeading])
        let origin = NSPoint(x: rect.midX - bounds.width / 2, y: rect.midY - bounds.height / 2)
        text.draw(at: origin)
    }
}
