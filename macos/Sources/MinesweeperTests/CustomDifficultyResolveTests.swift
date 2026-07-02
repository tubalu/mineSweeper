import Foundation
import MinesweeperCore

// ---------------------------------------------------------------------------
// Difficulty.custom(BoardDims) case
// ---------------------------------------------------------------------------
// `Difficulty` (macos/Sources/MinesweeperCore/Difficulty.swift) currently
// only has beginner/intermediate/expert/nightmare cases. Per the approved
// plan (docs/research/resizable-window-and-difficulty.md), it must gain a
// `.custom(BoardDims)` case carrying an explicit, user-supplied `BoardDims`.
// `resolve(screenSize:)` must return that `BoardDims` unchanged, exactly
// mirroring how the three static presets already ignore `screenSize` in
// DifficultyResolveTests.swift -- `.custom`'s dims come from the caller, not
// from screen geometry, so screenSize must have zero effect on the result.
//
// Expected contract:
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
