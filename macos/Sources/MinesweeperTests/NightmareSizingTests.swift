import Foundation
import MinesweeperCore

// ---------------------------------------------------------------------------
// Pure nightmare board sizing function
// (macos/Sources/MinesweeperCore/NightmareSizing.swift -- does not exist yet)
// ---------------------------------------------------------------------------
// public struct BoardDims: Equatable { rows: Int, cols: Int, mines: Int }
//
// public func nightmareDims(screenWidth: Double, screenHeight: Double,
//                            cell: Double = 30, border: Double = 12,
//                            header: Double = 52, density: Double = 0.206,
//                            maxMines: Int = 999) -> BoardDims
//
// cols  = floor((screenWidth  - 2*border) / cell)
// rows  = floor((screenHeight - header - 3*border) / cell)
// mines = min(maxMines, Int((density * Double(rows*cols)).rounded()))
//
// rows/cols must never be negative even for degenerate (too-small) screen
// sizes -- the raw formula can go negative, so the implementation must clamp
// -- and mines must never exceed rows*cols.

func runNightmareSizingTests() {
    // (a) realistic screen size -> hand-computed expected rows/cols/mines.
    // cols = floor((1512 - 24)/30)      = floor(49.6)       = 49
    // rows = floor((982 - 52 - 36)/30)  = floor(29.8)       = 29
    // mines = min(999, round(0.206 * 29*49)) = min(999, round(292.726)) = 293
    do {
        let dims = nightmareDims(screenWidth: 1512, screenHeight: 982)
        check(dims == BoardDims(rows: 29, cols: 49, mines: 293),
              "nightmareDims(1512x982) matches hand-computed rows/cols/mines")
    }

    // (b) a huge screen size that would produce >999 mines is clamped to 999.
    // cols = floor((5000-24)/30)        = floor(165.867)    = 165
    // rows = floor((3000-52-36)/30)     = floor(97.067)     = 97
    // raw mines = round(0.206 * 165*97) = round(3297.03)    = 3297 -> clamp 999
    do {
        let dims = nightmareDims(screenWidth: 5000, screenHeight: 3000)
        check(dims.rows == 97 && dims.cols == 165, "nightmareDims huge-screen rows/cols match formula")
        check(dims.mines == 999, "nightmareDims clamps mine count to maxMines (999) on huge screens")
    }

    // (c) a very small screen size produces small-but-valid (non-negative)
    // rows/cols, and mines never exceeds rows*cols. The raw formula for rows
    // here is negative (floor((40-52-36)/30) = floor(-1.6) = -2), so the
    // implementation must clamp to zero rather than return a negative count.
    do {
        let dims = nightmareDims(screenWidth: 40, screenHeight: 40)
        check(dims.rows >= 0 && dims.cols >= 0, "nightmareDims never returns negative rows/cols on tiny screens")
        check(dims.mines >= 0 && dims.mines <= dims.rows * dims.cols,
              "nightmareDims mine count is non-negative and never exceeds rows*cols")
    }

    // (d) density is approximately 0.206 of total cells for a mid-size screen
    // (within rounding tolerance).
    do {
        let dims = nightmareDims(screenWidth: 1512, screenHeight: 982)
        let actualDensity = Double(dims.mines) / Double(dims.rows * dims.cols)
        check(abs(actualDensity - 0.206) < 0.01,
              "nightmareDims mine density is approximately 0.206 of total cells (within rounding)")
    }
}
