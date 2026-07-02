import Foundation

/// Validation failure for a user-entered custom board. Each case carries the
/// bound that was violated so the dialog can name it exactly, rather than
/// showing a generic error.
public enum CustomDimsError: Error, Equatable {
    case widthOutOfBounds(min: Int, max: Int)
    case heightOutOfBounds(min: Int, max: Int)
    case mineCountOutOfBounds(min: Int, max: Int)
}

/// The largest mine count a board of the given size can safely hold,
/// reserving the classic safe-first-click margin: the first reveal and its
/// neighborhood must never all be mines, so at most `(cols-1)*(rows-1)`
/// cells can be mined. `maxMines` is the hard cap imposed by the 3-digit LED
/// mine counter. Shared by `validateCustomDims` (rejects input above this
/// ceiling) and interactive window-resize (clamps mines down to it when a
/// shrink would otherwise exceed it) -- one source of truth so the two call
/// sites can never drift apart.
public func safeMineCeiling(rows: Int, cols: Int, maxMines: Int = 999) -> Int {
    max(0, min(maxMines, (cols - 1) * (rows - 1)))
}

/// Pure, testable validation for the Custom difficulty dialog. `width` maps
/// to `BoardDims.cols`, `height` maps to `BoardDims.rows` -- same convention
/// as `nightmareDims` (screenWidth drives cols, screenHeight drives rows).
public func validateCustomDims(width: Int, height: Int, mines: Int,
                               minSide: Int = 8, maxWidth: Int = 30,
                               maxHeight: Int = 24, maxMines: Int = 999)
    -> Result<BoardDims, CustomDimsError> {
    guard width >= minSide, width <= maxWidth else {
        return .failure(.widthOutOfBounds(min: minSide, max: maxWidth))
    }
    guard height >= minSide, height <= maxHeight else {
        return .failure(.heightOutOfBounds(min: minSide, max: maxHeight))
    }
    let mineCeiling = safeMineCeiling(rows: height, cols: width, maxMines: maxMines)
    guard mines >= 1, mines <= mineCeiling else {
        return .failure(.mineCountOutOfBounds(min: 1, max: mineCeiling))
    }
    return .success(BoardDims(rows: height, cols: width, mines: mines))
}
