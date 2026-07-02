import Foundation
import AppKit
import MinesweeperCore

// ---------------------------------------------------------------------------
// Renderer dirtyRect honoring -- pure geometry helper on Layout
// (macos/Sources/MinesweeperCore/Theme.swift -- does not exist yet)
// ---------------------------------------------------------------------------
// A live AppKit rendering context isn't feasible to assert against
// headlessly, so instead of testing `Renderer.draw` itself, we test the pure
// coordinate-math boundary it would rely on to skip untouched cells: a
// `Layout.cellRange(in:)` helper that maps a dirty NSRect (view-space,
// flipped, top-left origin -- same space as `Layout.cellRect`) to the board
// row/col index ranges it overlaps, clamped to valid board bounds.
//
// Expected contract:
//
//   public func cellRange(in rect: NSRect) -> (rows: Range<Int>, cols: Range<Int>)
//
//   colStart = max(0,    floor((rect.minX - gridX) / cell))
//   colEnd   = min(cols, ceil((rect.maxX - gridX) / cell))
//   rowStart = max(0,    floor((rect.minY - gridY) / cell))
//   rowEnd   = min(rows, ceil((rect.maxY - gridY) / cell))
//   -> (rowStart ..< max(rowStart, rowEnd), colStart ..< max(colStart, colEnd))
//
// Using the expert layout (rows: 16, cols: 30) with the fixed defaults
// (cell: 30, border: 12, header: 52): gridX = 12, gridY = 52 + 24 = 76.

func runLayoutCellRangeTests() {
    let layout = Layout(rows: 16, cols: 30)

    // (a) a small dirtyRect near the top-left maps to a small row/col range.
    // rect = (x: 12, y: 76, w: 35, h: 35) i.e. gridX/gridY origin, 35pt square.
    // colStart = floor((12-12)/30) = 0; colEnd = ceil((47-12)/30) = ceil(1.167) = 2
    // rowStart = floor((76-76)/30) = 0; rowEnd = ceil((111-76)/30) = ceil(1.167) = 2
    do {
        let dirty = NSRect(x: 12, y: 76, width: 35, height: 35)
        let range = layout.cellRange(in: dirty)
        check(range.rows == 0 ..< 2, "small top-left dirtyRect maps to a small row range (0..<2)")
        check(range.cols == 0 ..< 2, "small top-left dirtyRect maps to a small col range (0..<2)")
    }

    // (b) a dirtyRect covering the whole board maps to the full range.
    do {
        let dirty = NSRect(x: 0, y: 0, width: layout.width, height: layout.height)
        let range = layout.cellRange(in: dirty)
        check(range.rows == 0 ..< 16, "whole-board dirtyRect maps to the full row range (0..<16)")
        check(range.cols == 0 ..< 30, "whole-board dirtyRect maps to the full col range (0..<30)")
    }

    // (c) a dirtyRect entirely outside the grid (e.g. purely within the
    // header) maps to an empty range, not a crash or out-of-bounds range.
    do {
        let dirty = NSRect(x: layout.border, y: layout.border, width: 20, height: 20)
        let range = layout.cellRange(in: dirty)
        check(range.rows.isEmpty, "dirtyRect confined to the header maps to an empty row range")
    }
}
