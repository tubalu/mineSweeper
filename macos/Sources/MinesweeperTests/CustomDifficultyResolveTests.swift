import Foundation
import MinesweeperCore

// ---------------------------------------------------------------------------
// Difficulty.custom(BoardDims) case
// ---------------------------------------------------------------------------
// `Difficulty` (macos/Sources/MinesweeperCore/Difficulty.swift) has a
// `.custom(BoardDims)` case carrying an explicit, user-supplied `BoardDims`.
// `resolve(screenSize:)` returns that `BoardDims` unchanged, exactly
// mirroring how the three static presets already ignore `screenSize` in
// DifficultyResolveTests.swift -- `.custom`'s dims come from the caller, not
// from screen geometry, so screenSize has zero effect on the result.
//
// Public contract:
//
//   public enum Difficulty { case beginner, intermediate, expert, nightmare
//     case custom(BoardDims)
//     public func resolve(screenSize: CGSize) -> BoardDims
//   }

func runCustomDifficultyResolveTests() {
    let dims = BoardDims(rows: 12, cols: 13, mines: 30)
    let smallScreen = CGSize(width: 800, height: 600)
    let largeScreen = CGSize(width: 1920, height: 1080)

    // (a) .custom returns exactly the supplied BoardDims, regardless of
    // screenSize -- mirrors how beginner/intermediate/expert ignore
    // screenSize in DifficultyResolveTests.swift.
    do {
        let resolvedSmall = Difficulty.custom(dims).resolve(screenSize: smallScreen)
        let resolvedLarge = Difficulty.custom(dims).resolve(screenSize: largeScreen)
        check(resolvedSmall == dims, "custom dims match the exact BoardDims supplied (small screen)")
        check(resolvedLarge == dims, "custom dims match the exact BoardDims supplied (large screen)")
        check(resolvedSmall == resolvedLarge, "custom dims ignore screenSize")
    }
}
