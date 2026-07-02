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

/// Pure geometry: how many fixed-size cells fit a screen, at Nightmare's mine
/// density. No AppKit dependency, so it is testable headlessly.
public func nightmareDims(screenWidth: Double, screenHeight: Double,
                          cell: Double = Double(Layout.defaultCell),
                          border: Double = Double(Layout.defaultBorder),
                          header: Double = Double(Layout.defaultHeader),
                          density: Double = 0.206,
                          maxMines: Int = 999) -> BoardDims {
    let cols = max(0, Int(((screenWidth - 2 * border) / cell).rounded(.down)))
    let rows = max(0, Int(((screenHeight - header - 3 * border) / cell).rounded(.down)))
    let rawMines = Int((density * Double(rows * cols)).rounded())
    let mines = min(maxMines, max(0, rawMines))
    return BoardDims(rows: rows, cols: cols, mines: mines)
}
