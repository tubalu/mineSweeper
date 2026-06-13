import AppKit

/// Stateless Win95 renderer. Draws into the *current* `NSGraphicsContext`,
/// which must be flipped (top-left origin) so the geometry in `Layout` matches.
public enum Renderer {
    public static func draw(board: Board, layout: Layout,
                            pressed: Set<Position>, seconds: Int) {
        Theme.face.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: layout.width, height: layout.height)).fill()
        drawHeader(board: board, layout: layout, seconds: seconds)
        for r in 0 ..< board.rows {
            for c in 0 ..< board.cols {
                drawCell(board: board, layout: layout, r: r, c: c,
                         pressed: pressed.contains(Position(r, c)))
            }
        }
    }

    // MARK: - primitives

    private static func fillPolygon(_ pts: [NSPoint], _ color: NSColor) {
        let path = NSBezierPath()
        path.move(to: pts[0])
        for p in pts.dropFirst() { path.line(to: p) }
        path.close()
        color.setFill()
        path.fill()
    }

    static func bevel(_ rect: NSRect, raised: Bool, width w: CGFloat = 3) {
        Theme.face.setFill()
        NSBezierPath(rect: rect).fill()
        let light = raised ? Theme.hilite : Theme.shadow
        let dark = raised ? Theme.shadow : Theme.hilite
        let x = rect.minX, y = rect.minY, ww = rect.width, hh = rect.height
        fillPolygon([
            NSPoint(x: x, y: y), NSPoint(x: x + ww, y: y),
            NSPoint(x: x + ww - w, y: y + w), NSPoint(x: x + w, y: y + w),
            NSPoint(x: x + w, y: y + hh - w), NSPoint(x: x, y: y + hh),
        ], light)
        fillPolygon([
            NSPoint(x: x + ww, y: y), NSPoint(x: x + ww, y: y + hh),
            NSPoint(x: x, y: y + hh), NSPoint(x: x + w, y: y + hh - w),
            NSPoint(x: x + ww - w, y: y + hh - w), NSPoint(x: x + ww - w, y: y + w),
        ], dark)
    }

    private static func drawFlat(_ rect: NSRect) {
        Theme.face.setFill()
        NSBezierPath(rect: rect).fill()
        Theme.gridline.setStroke()
        let p = NSBezierPath()
        p.move(to: NSPoint(x: rect.minX, y: rect.minY))
        p.line(to: NSPoint(x: rect.maxX, y: rect.minY))
        p.move(to: NSPoint(x: rect.minX, y: rect.minY))
        p.line(to: NSPoint(x: rect.minX, y: rect.maxY))
        p.lineWidth = 1
        p.stroke()
    }

    private static func drawCentered(_ s: String, in rect: NSRect,
                                     font: NSFont, color: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let ns = s as NSString
        let sz = ns.size(withAttributes: attrs)
        ns.draw(at: NSPoint(x: rect.midX - sz.width / 2, y: rect.midY - sz.height / 2),
                withAttributes: attrs)
    }

    // MARK: - cell content

    private static func drawNumber(_ rect: NSRect, _ value: Int) {
        guard let color = Theme.numberColors[value] else { return }
        drawCentered(String(value), in: rect,
                     font: .boldSystemFont(ofSize: rect.height * 0.6), color: color)
    }

    private static func drawFlag(_ rect: NSRect) {
        let cx = rect.midX, cy = rect.midY
        let poleX = cx + 2
        Theme.black.setStroke()
        let pole = NSBezierPath()
        pole.move(to: NSPoint(x: poleX, y: cy - 8))
        pole.line(to: NSPoint(x: poleX, y: cy + 8))
        pole.lineWidth = 2
        pole.stroke()
        let base = NSBezierPath()
        base.move(to: NSPoint(x: cx - 7, y: cy + 8))
        base.line(to: NSPoint(x: cx + 8, y: cy + 8))
        base.lineWidth = 3
        base.stroke()
        fillPolygon([NSPoint(x: poleX, y: cy - 8), NSPoint(x: poleX, y: cy),
                     NSPoint(x: cx - 6, y: cy - 4)], Theme.flagRed)
    }

    private static func drawMine(_ rect: NSRect, exploded: Bool) {
        if exploded {
            Theme.exploded.setFill()
            NSBezierPath(rect: rect).fill()
        }
        let cx = rect.midX, cy = rect.midY
        let rad = rect.width / 4
        Theme.black.setStroke()
        let spokes = NSBezierPath()
        spokes.move(to: NSPoint(x: cx - (rad + 2), y: cy))
        spokes.line(to: NSPoint(x: cx + (rad + 2), y: cy))
        spokes.move(to: NSPoint(x: cx, y: cy - (rad + 2)))
        spokes.line(to: NSPoint(x: cx, y: cy + (rad + 2)))
        spokes.lineWidth = 2
        spokes.stroke()
        Theme.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: cx - rad, y: cy - rad, width: rad * 2, height: rad * 2)).fill()
        Theme.hilite.setFill()
        NSBezierPath(ovalIn: NSRect(x: cx - rad / 2, y: cy - rad / 2, width: 4, height: 4)).fill()
    }

    private static func drawWrongFlag(_ rect: NSRect) {
        drawMine(rect, exploded: false)
        let cx = rect.midX, cy = rect.midY, d = rect.width / 3
        Theme.exploded.setStroke()
        let x = NSBezierPath()
        x.move(to: NSPoint(x: cx - d, y: cy - d)); x.line(to: NSPoint(x: cx + d, y: cy + d))
        x.move(to: NSPoint(x: cx + d, y: cy - d)); x.line(to: NSPoint(x: cx - d, y: cy + d))
        x.lineWidth = 3
        x.stroke()
    }

    private static func drawCell(board: Board, layout: Layout, r: Int, c: Int, pressed: Bool) {
        let rect = layout.cellRect(r, c)
        let lost = board.gameOver && !board.win
        let mine = board.isMine[r][c]

        switch board.state[r][c] {
        case .revealed:
            drawFlat(rect)
            if mine {
                drawMine(rect, exploded: board.detonated == Position(r, c))
            } else {
                drawNumber(rect, board.counts[r][c])
            }
        case .flagged:
            if lost && !mine {
                drawFlat(rect)
                drawWrongFlag(rect)
            } else {
                bevel(rect, raised: true)
                drawFlag(rect)
            }
        case .covered:
            if lost && mine {
                drawFlat(rect)
                drawMine(rect, exploded: false)
            } else if pressed {
                drawFlat(rect)
            } else {
                bevel(rect, raised: true)
            }
        }
    }

    // MARK: - header

    private static func format3(_ value: Int) -> String {
        if value < 0 { return String(format: "-%02d", min(abs(value), 99)) }
        return String(format: "%03d", min(value, 999))
    }

    private static func drawLED(_ rect: NSRect, _ text: String) {
        bevel(rect, raised: false, width: 2)
        Theme.black.setFill()
        NSBezierPath(rect: rect.insetBy(dx: 3, dy: 3)).fill()
        drawCentered(text, in: rect,
                     font: .monospacedDigitSystemFont(ofSize: rect.height * 0.62, weight: .bold),
                     color: Theme.ledRed)
    }

    private static func drawSmiley(board: Board, layout: Layout) {
        let rect = layout.smileyRect
        bevel(rect, raised: true)
        let cx = rect.midX, cy = rect.midY
        let rad = rect.width / 2 - 5
        Theme.smileyYellow.setFill()
        NSBezierPath(ovalIn: NSRect(x: cx - rad, y: cy - rad, width: rad * 2, height: rad * 2)).fill()
        Theme.black.setStroke()
        let outline = NSBezierPath(ovalIn: NSRect(x: cx - rad, y: cy - rad, width: rad * 2, height: rad * 2))
        outline.lineWidth = 1
        outline.stroke()

        let e = rad * 0.5
        let eyeY = cy - rad * 0.3
        Theme.black.setStroke()
        Theme.black.setFill()

        func smile(up: Bool) {
            let path = NSBezierPath()
            if up {  // frown: bulge upward
                path.move(to: NSPoint(x: cx - e, y: cy + rad * 0.55))
                path.curve(to: NSPoint(x: cx + e, y: cy + rad * 0.55),
                           controlPoint1: NSPoint(x: cx - e * 0.4, y: cy + rad * 0.05),
                           controlPoint2: NSPoint(x: cx + e * 0.4, y: cy + rad * 0.05))
            } else {  // smile: bulge downward
                path.move(to: NSPoint(x: cx - e, y: cy + rad * 0.15))
                path.curve(to: NSPoint(x: cx + e, y: cy + rad * 0.15),
                           controlPoint1: NSPoint(x: cx - e * 0.4, y: cy + rad * 0.7),
                           controlPoint2: NSPoint(x: cx + e * 0.4, y: cy + rad * 0.7))
            }
            path.lineWidth = 2
            path.stroke()
        }

        func dot(_ x: CGFloat, _ y: CGFloat) {
            NSBezierPath(ovalIn: NSRect(x: x - 2, y: y - 2, width: 4, height: 4)).fill()
        }

        if board.win {  // cool: sunglasses + smile
            Theme.black.setFill()
            NSBezierPath(rect: NSRect(x: cx - e - 3, y: eyeY - 2, width: 7, height: 4)).fill()
            NSBezierPath(rect: NSRect(x: cx + e - 4, y: eyeY - 2, width: 7, height: 4)).fill()
            smile(up: false)
        } else if board.gameOver {  // dead: X eyes + frown
            Theme.black.setStroke()
            for sx in [cx - e, cx + e] {
                let xp = NSBezierPath()
                xp.move(to: NSPoint(x: sx - 3, y: eyeY - 3)); xp.line(to: NSPoint(x: sx + 3, y: eyeY + 3))
                xp.move(to: NSPoint(x: sx + 3, y: eyeY - 3)); xp.line(to: NSPoint(x: sx - 3, y: eyeY + 3))
                xp.lineWidth = 2
                xp.stroke()
            }
            smile(up: true)
        } else {  // alive: dot eyes + smile
            dot(cx - e, eyeY)
            dot(cx + e, eyeY)
            smile(up: false)
        }
    }

    private static func drawHeader(board: Board, layout: Layout, seconds: Int) {
        bevel(layout.headerRect, raised: false, width: 2)
        let leds = layout.ledRects()
        drawLED(leds.mines, format3(board.minesRemaining()))
        drawLED(leds.timer, format3(seconds))
        drawSmiley(board: board, layout: layout)
    }
}
