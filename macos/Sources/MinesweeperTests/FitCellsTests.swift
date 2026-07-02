import Foundation
import MinesweeperCore

// ---------------------------------------------------------------------------
// fitCells(availableWidth:availableHeight:cell:border:header:)
// ---------------------------------------------------------------------------
// A generalized, pure "how many fixed-size cells fit in the available
// space" function, extracted from nightmareDims's existing floor/clamp math
// (macos/Sources/MinesweeperCore/NightmareSizing.swift) so that both
// Nightmare-mode sizing and interactive window resize (see
// docs/research/resizable-window-and-difficulty.md) share one function.
// Implemented in MinesweeperCore with the public signature:
//
//   public func fitCells(availableWidth: Double, availableHeight: Double,
//                         cell: Double = Double(Layout.defaultCell),
//                         border: Double = Double(Layout.defaultBorder),
//                         header: Double = Double(Layout.defaultHeader))
//     -> (rows: Int, cols: Int)
//
// cols = floor((availableWidth  - 2*border) / cell)
// rows = floor((availableHeight - header - 3*border) / cell)
// -- clamped to non-negative, mirroring nightmareDims's existing clamp for
// degenerate (too-small) inputs.
//
// nightmareDims(screenWidth:screenHeight:...) should end up as a thin
// wrapper around this function (computing mines on top of the returned
// rows/cols); these test cases reuse nightmareDims's existing hand-computed
// expectations from NightmareSizingTests.swift for the rows/cols portion.

func runFitCellsTests() {
    // (a) realistic screen size -> hand-computed expected rows/cols (same
    // case as NightmareSizingTests.swift's (a)).
    // cols = floor((1512 - 24)/30)      = floor(49.6)  = 49
    // rows = floor((982 - 52 - 36)/30)  = floor(29.8)  = 29
    do {
        let fit = fitCells(availableWidth: 1512, availableHeight: 982)
        check(fit.rows == 29 && fit.cols == 49,
              "fitCells(1512x982) matches nightmareDims's hand-computed rows/cols")
    }

    // (b) a huge available size -> hand-computed expected rows/cols (same
    // case as NightmareSizingTests.swift's (b), rows/cols portion only --
    // fitCells has no notion of mines/density).
    // cols = floor((5000-24)/30)        = floor(165.867) = 165
    // rows = floor((3000-52-36)/30)     = floor(97.067)  = 97
    do {
        let fit = fitCells(availableWidth: 5000, availableHeight: 3000)
        check(fit.rows == 97 && fit.cols == 165,
              "fitCells(5000x3000) matches nightmareDims's hand-computed rows/cols")
    }

    // (c) a degenerate tiny-input case must clamp to non-negative rows/cols
    // (mirrors NightmareSizingTests.swift's existing tiny-screen case). The
    // raw formula for rows here is negative
    // (floor((40-52-36)/30) = floor(-1.6) = -2), so the implementation must
    // clamp to zero rather than return a negative count.
    do {
        let fit = fitCells(availableWidth: 40, availableHeight: 40)
        check(fit.rows >= 0 && fit.cols >= 0,
              "fitCells never returns negative rows/cols on tiny available space")
        check(fit.rows == 0 && fit.cols == 0,
              "fitCells(40x40) clamps to zero rows/cols (raw formula goes negative for rows)")
    }
}
