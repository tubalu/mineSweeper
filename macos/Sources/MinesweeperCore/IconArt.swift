import AppKit

/// Programmatic Win95 app icon: a raised beveled gray tile with a centered
/// black mine and a small red flag accent. Pure drawing into the *current*
/// (flipped, top-left origin) NSGraphicsContext, scaled to a `size` x `size`
/// canvas so it stays crisp from 16 px to 1024 px. Reuses only `Theme` colors.
public enum IconArt {
    public static func draw(size s: CGFloat) {
        // 1. Win95 gray field to the corners.
        Theme.face.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: s, height: s)).fill()

        // 2. Raised beveled tile, inset so the gray field frames it.
        let margin = s * 0.10
        let tile = NSRect(x: margin, y: margin, width: s - 2 * margin, height: s - 2 * margin)
        bevel(tile, width: max(2, s * 0.06))

        // 3. Centered mine (dark — the icon's focal point).
        drawMine(center: NSPoint(x: s / 2, y: s / 2),
                 radius: s * 0.20, lineWidth: max(1.5, s * 0.028))

        // 4. Small red flag accent, lower-left of the tile.
        drawFlag(center: NSPoint(x: s * 0.30, y: s * 0.70), scale: s)
    }

    // MARK: - primitives (self-contained, all relative to the icon size)

    private static func fillPolygon(_ pts: [NSPoint], _ color: NSColor) {
        let path = NSBezierPath()
        path.move(to: pts[0])
        for p in pts.dropFirst() { path.line(to: p) }
        path.close()
        color.setFill()
        path.fill()
    }

    private static func bevel(_ rect: NSRect, width w: CGFloat) {
        Theme.face.setFill()
        NSBezierPath(rect: rect).fill()
        let x = rect.minX, y = rect.minY, ww = rect.width, hh = rect.height
        fillPolygon([
            NSPoint(x: x, y: y), NSPoint(x: x + ww, y: y),
            NSPoint(x: x + ww - w, y: y + w), NSPoint(x: x + w, y: y + w),
            NSPoint(x: x + w, y: y + hh - w), NSPoint(x: x, y: y + hh),
        ], Theme.hilite)
        fillPolygon([
            NSPoint(x: x + ww, y: y), NSPoint(x: x + ww, y: y + hh),
            NSPoint(x: x, y: y + hh), NSPoint(x: x + w, y: y + hh - w),
            NSPoint(x: x + ww - w, y: y + hh - w), NSPoint(x: x + ww - w, y: y + w),
        ], Theme.shadow)
    }

    private static func drawMine(center c: NSPoint, radius rad: CGFloat, lineWidth lw: CGFloat) {
        Theme.black.setStroke()
        let reach = rad * 1.45
        let diag = reach * 0.72
        let spokes = NSBezierPath()
        spokes.lineWidth = lw
        let segments: [(CGFloat, CGFloat)] = [
            (reach, 0), (0, reach), (diag, diag), (-diag, diag),
        ]
        for (dx, dy) in segments {
            spokes.move(to: NSPoint(x: c.x - dx, y: c.y - dy))
            spokes.line(to: NSPoint(x: c.x + dx, y: c.y + dy))
        }
        spokes.stroke()
        Theme.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: c.x - rad, y: c.y - rad, width: rad * 2, height: rad * 2)).fill()
        // Glossy highlight (upper-left of the sphere).
        let hr = rad * 0.34
        Theme.hilite.setFill()
        NSBezierPath(ovalIn: NSRect(x: c.x - rad * 0.5, y: c.y - rad * 0.5, width: hr, height: hr)).fill()
    }

    private static func drawFlag(center c: NSPoint, scale s: CGFloat) {
        let h = s * 0.20
        let poleX = c.x + h * 0.18
        Theme.black.setStroke()
        let pole = NSBezierPath()
        pole.move(to: NSPoint(x: poleX, y: c.y - h / 2))
        pole.line(to: NSPoint(x: poleX, y: c.y + h / 2))
        pole.lineWidth = max(1.5, s * 0.022)
        pole.stroke()
        let base = NSBezierPath()
        base.move(to: NSPoint(x: poleX - h * 0.5, y: c.y + h / 2))
        base.line(to: NSPoint(x: poleX + h * 0.55, y: c.y + h / 2))
        base.lineWidth = max(2, s * 0.03)
        base.stroke()
        fillPolygon([
            NSPoint(x: poleX, y: c.y - h / 2),
            NSPoint(x: poleX, y: c.y - h * 0.04),
            NSPoint(x: poleX - h * 0.52, y: c.y - h * 0.27),
        ], Theme.flagRed)
    }
}

public extension IconArt {
    /// Render the icon to an exact `pixels` x `pixels` bitmap, independent of
    /// display scale. (NSImage.lockFocus renders at the Retina backing scale,
    /// producing 2x output — wrong for icon sizing and pixel sampling.) A
    /// manual flip gives the top-left origin `draw(size:)` expects; safe here
    /// because the icon contains only shapes, no text.
    static func renderBitmap(pixels px: Int) -> NSBitmapImageRep {
        precondition(px > 0, "IconArt.renderBitmap: pixels must be > 0, got \(px)")
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0)
        else {
            fatalError("IconArt.renderBitmap: could not allocate \(px)x\(px) bitmap")
        }
        rep.size = NSSize(width: px, height: px)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let flip = NSAffineTransform()
        flip.translateX(by: 0, yBy: CGFloat(px))
        flip.scaleX(by: 1, yBy: -1)
        flip.concat()
        draw(size: CGFloat(px))
        NSGraphicsContext.current?.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    /// PNG-encoded icon at an exact pixel size.
    static func pngData(pixels px: Int) -> Data? {
        renderBitmap(pixels: px).representation(using: .png, properties: [:])
    }
}
