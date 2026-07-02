import AppKit

/// Win95 control palette and number colors.
public enum Theme {
    public static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
        NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: 1)
    }

    public static let face = rgb(192, 192, 192)
    public static let hilite = rgb(255, 255, 255)
    public static let shadow = rgb(128, 128, 128)
    public static let gridline = rgb(160, 160, 160)
    public static let black = rgb(0, 0, 0)
    public static let ledRed = rgb(255, 0, 0)
    public static let exploded = rgb(255, 0, 0)
    public static let flagRed = rgb(200, 0, 0)
    public static let smileyYellow = rgb(255, 221, 0)

    /// Classic adjacency-number colors, index == count.
    public static let numberColors: [Int: NSColor] = [
        1: rgb(0, 0, 255),
        2: rgb(0, 128, 0),
        3: rgb(255, 0, 0),
        4: rgb(0, 0, 128),
        5: rgb(128, 0, 0),
        6: rgb(0, 128, 128),
        7: rgb(0, 0, 0),
        8: rgb(128, 128, 128),
    ]
}

/// Pixel geometry derived from board dimensions. Assumes a flipped (top-left
/// origin) coordinate space, matching `NSView.isFlipped == true`.
public struct Layout {
    /// Single source of truth for fixed geometry -- `nightmareDims` derives
    /// its defaults from these so Nightmare's screen-filling math can never
    /// drift out of sync with what `Layout`/`Renderer` actually draw.
    public static let defaultCell: CGFloat = 30
    public static let defaultBorder: CGFloat = 12
    public static let defaultHeader: CGFloat = 52

    public let rows: Int
    public let cols: Int
    public let cell: CGFloat = defaultCell
    public let border: CGFloat = defaultBorder
    public let header: CGFloat = defaultHeader

    public init(rows: Int, cols: Int) {
        self.rows = rows
        self.cols = cols
    }

    public var gridX: CGFloat { border }
    public var gridY: CGFloat { header + 2 * border }
    public var width: CGFloat { CGFloat(cols) * cell + 2 * border }
    public var height: CGFloat { CGFloat(rows) * cell + header + 3 * border }

    public func cellRect(_ r: Int, _ c: Int) -> NSRect {
        NSRect(x: gridX + CGFloat(c) * cell, y: gridY + CGFloat(r) * cell,
               width: cell, height: cell)
    }

    public var headerRect: NSRect {
        NSRect(x: border, y: border, width: width - 2 * border, height: header)
    }

    public var smileyRect: NSRect {
        let s = header - 12
        return NSRect(x: width / 2 - s / 2, y: border + 6, width: s, height: s)
    }

    public func ledRects() -> (mines: NSRect, timer: NSRect) {
        let w: CGFloat = 56, h = header - 16
        let mines = NSRect(x: border + 8, y: border + 8, width: w, height: h)
        let timer = NSRect(x: width - border - 8 - w, y: border + 8, width: w, height: h)
        return (mines, timer)
    }

    public func cellAt(_ p: CGPoint) -> Position? {
        guard p.x >= gridX, p.x < gridX + CGFloat(cols) * cell,
              p.y >= gridY, p.y < gridY + CGFloat(rows) * cell else { return nil }
        return Position(Int((p.y - gridY) / cell), Int((p.x - gridX) / cell))
    }

    /// Maps a dirty rect (same flipped, top-left-origin space as `cellRect`)
    /// to the row/col index ranges it overlaps, clamped to board bounds.
    public func cellRange(in rect: NSRect) -> (rows: Range<Int>, cols: Range<Int>) {
        let colStart = max(0, Int(((rect.minX - gridX) / cell).rounded(.down)))
        let colEnd = min(cols, Int(((rect.maxX - gridX) / cell).rounded(.up)))
        let rowStart = max(0, Int(((rect.minY - gridY) / cell).rounded(.down)))
        let rowEnd = min(rows, Int(((rect.maxY - gridY) / cell).rounded(.up)))
        return (rowStart ..< max(rowStart, rowEnd), colStart ..< max(colStart, colEnd))
    }
}
