import Foundation

/// Validation failure for a user-entered custom board. Each case carries the
/// bound that was violated so the dialog can name it exactly, rather than
/// showing a generic error.
public enum CustomDimsError: Error, Equatable {
    case widthOutOfBounds(min: Int, max: Int)
    case heightOutOfBounds(min: Int, max: Int)
    case mineCountOutOfBounds(min: Int, max: Int)
}

/// Pure, testable validation for the Custom difficulty dialog. `width` maps
/// to `BoardDims.cols`, `height` maps to `BoardDims.rows` -- same convention
/// as `nightmareDims` (screenWidth drives cols, screenHeight drives rows).
///
/// The mine-count ceiling is `min(maxMines, (width-1)*(height-1))`: the
/// `(width-1)*(height-1)` term reserves the classic safe-first-click margin,
/// and `maxMines` is the hard cap imposed by the 3-digit LED mine counter.
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
    let mineCeiling = min(maxMines, (width - 1) * (height - 1))
    guard mines >= 1, mines <= mineCeiling else {
        return .failure(.mineCountOutOfBounds(min: 1, max: mineCeiling))
    }
    return .success(BoardDims(rows: height, cols: width, mines: mines))
}
