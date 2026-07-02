import Foundation

/// Board dimensions resolved for a given difficulty.
public struct BoardDims: Equatable {
    public let rows: Int
    public let cols: Int
    public let mines: Int

    public init(rows: Int, cols: Int, mines: Int) {
        self.rows = rows
        self.cols = cols
        self.mines = mines
    }
}

/// Pure geometry: how many fixed-size cells fit in the available space,
/// clamped to non-negative. No AppKit dependency, so it is testable
/// headlessly. Shared by Nightmare's screen-fit sizing and interactive
/// window-resize fitting -- one source of truth for "whole cells fit
/// available space."
public func fitCells(availableWidth: Double, availableHeight: Double,
                     cell: Double = Double(Layout.defaultCell),
                     border: Double = Double(Layout.defaultBorder),
                     header: Double = Double(Layout.defaultHeader)) -> (rows: Int, cols: Int) {
    let cols = max(0, Int(((availableWidth - 2 * border) / cell).rounded(.down)))
    let rows = max(0, Int(((availableHeight - header - 3 * border) / cell).rounded(.down)))
    return (rows, cols)
}

/// Pure geometry: how many fixed-size cells fit a screen, at Nightmare's mine
/// density. No AppKit dependency, so it is testable headlessly.
public func nightmareDims(screenWidth: Double, screenHeight: Double,
                          cell: Double = Double(Layout.defaultCell),
                          border: Double = Double(Layout.defaultBorder),
                          header: Double = Double(Layout.defaultHeader),
                          density: Double = 0.206,
                          maxMines: Int = 999) -> BoardDims {
    let fit = fitCells(availableWidth: screenWidth, availableHeight: screenHeight,
                       cell: cell, border: border, header: header)
    let rawMines = Int((density * Double(fit.rows * fit.cols)).rounded())
    let mines = min(maxMines, max(0, rawMines))
    return BoardDims(rows: fit.rows, cols: fit.cols, mines: mines)
}

/// Mine count re-scaled to a board's mine density (mines / (rows*cols)),
/// clamped to the safe-first-click ceiling and to non-negative. This is the
/// same density-preserving math `nightmareDims` uses for its own screen-fit
/// sizing, generalized so interactive window-resize can keep a board's
/// relative difficulty roughly constant as its cell count changes -- leaving
/// mine count fixed while the board grows would otherwise dilute an easy
/// board across a huge grid (near-zero effective density), and leaving it
/// fixed while the board shrinks risks exceeding the safe ceiling.
public func densityScaledMines(rows: Int, cols: Int, density: Double, maxMines: Int = 999) -> Int {
    let raw = Int((density * Double(rows * cols)).rounded())
    return min(safeMineCeiling(rows: rows, cols: cols, maxMines: maxMines), max(0, raw))
}
