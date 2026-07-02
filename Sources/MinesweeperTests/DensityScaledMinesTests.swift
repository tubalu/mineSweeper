import Foundation
import MinesweeperCore

// ---------------------------------------------------------------------------
// densityScaledMines(rows:cols:density:maxMines:)
// ---------------------------------------------------------------------------
// Mine count re-scaled to a board's mine density, clamped to the
// safe-first-click ceiling (safeMineCeiling) and to non-negative. Used by
// interactive window-resize (AppDelegate.swift) so a board's relative
// difficulty stays roughly constant as its cell count changes, instead of
// leaving mine count fixed (which dilutes an easy preset across a large
// window -- see docs/research/resizable-window-and-difficulty.md).

func runDensityScaledMinesTests() {
    // (a) Beginner's density (10/81) scaled up to a 30x30 board.
    // raw = round(0.12345679 * 900) = round(111.111) = 111, well under the
    // safe ceiling (29*29 = 841) and the 999 hard cap.
    do {
        let mines = densityScaledMines(rows: 30, cols: 30, density: 10.0 / 81.0)
        check(mines == 111, "Beginner density (10/81) scaled to a 30x30 board yields 111 mines")
    }

    // (b) A high density on a small board is clamped to the safe
    // first-click ceiling rather than the raw density-scaled count.
    // raw = round(0.9 * 25) = 23, but safeMineCeiling(5,5) = min(999, 4*4) = 16.
    do {
        let mines = densityScaledMines(rows: 5, cols: 5, density: 0.9)
        check(mines == 16, "high density on a small board clamps to the safe-first-click ceiling (16), not the raw density-scaled count (23)")
    }

    // (c) Zero density yields zero mines regardless of board size.
    do {
        let mines = densityScaledMines(rows: 20, cols: 20, density: 0)
        check(mines == 0, "zero density yields zero mines")
    }

    // (d) Degenerate zero-size board never returns a negative count.
    do {
        let mines = densityScaledMines(rows: 0, cols: 0, density: 0.5)
        check(mines == 0, "degenerate zero-size board yields zero mines, never negative")
    }

    // (e) A very high density on a large board is clamped to the 999 hard
    // cap even though the board-size ceiling would otherwise allow more.
    // raw = round(1.0 * 2500) = 2500; safeMineCeiling(50,50) = min(999, 49*49=2401) = 999.
    do {
        let mines = densityScaledMines(rows: 50, cols: 50, density: 1.0)
        check(mines == 999, "100% density on a 50x50 board clamps to the 999 hard cap")
    }
}
