import Foundation
import MinesweeperCore

// ---------------------------------------------------------------------------
// validateCustomDims(width:height:mines:minSide:maxWidth:maxHeight:maxMines:)
// ---------------------------------------------------------------------------
// Pure, testable validation for the Custom difficulty dialog (see
// docs/research/resizable-window-and-difficulty.md). Does not exist yet in
// MinesweeperCore -- this file is written against the expected public
// signature:
//
//   public enum CustomDimsError: Error, Equatable {
//     case widthOutOfBounds(min: Int, max: Int)
//     case heightOutOfBounds(min: Int, max: Int)
//     case mineCountOutOfBounds(min: Int, max: Int)
//   }
//
//   public func validateCustomDims(width: Int, height: Int, mines: Int,
//                                   minSide: Int = 8, maxWidth: Int = 30,
//                                   maxHeight: Int = 24, maxMines: Int = 999)
//     -> Result<BoardDims, CustomDimsError>
//
// Width/height bounds: [minSide, maxWidth] / [minSide, maxHeight].
// Mine count bounds: [1, min(maxMines, (width-1)*(height-1))] -- the
// (width-1)*(height-1) ceiling reserves the classic safe-first-click margin
// (mirrors nightmareDims's clamp-to-board-size discipline in
// NightmareSizing.swift); maxMines is the hard cap from the 3-digit LED
// mine counter.
//
// Row/col mapping convention (must match NightmareSizing.swift, where
// screenWidth drives cols and screenHeight drives rows): `width` maps to
// `BoardDims.cols`, `height` maps to `BoardDims.rows`.

func runCustomDimsValidationTests() {
    // (a) width below minSide (7 < 8) fails with widthOutOfBounds(min:8,max:30).
    // height/mines are otherwise valid so the width bound is unambiguously
    // the reported violation.
    do {
        let result = validateCustomDims(width: 7, height: 15, mines: 50)
        check(result == .failure(.widthOutOfBounds(min: 8, max: 30)),
              "width below minSide (7) fails with widthOutOfBounds(min:8,max:30)")
    }

    // (b) width above maxWidth (31 > 30) fails.
    do {
        let result = validateCustomDims(width: 31, height: 15, mines: 50)
        check(result == .failure(.widthOutOfBounds(min: 8, max: 30)),
              "width above maxWidth (31) fails with widthOutOfBounds(min:8,max:30)")
    }

    // (c) height below minSide (7 < 8) fails with heightOutOfBounds(min:8,max:24).
    do {
        let result = validateCustomDims(width: 20, height: 7, mines: 50)
        check(result == .failure(.heightOutOfBounds(min: 8, max: 24)),
              "height below minSide (7) fails with heightOutOfBounds(min:8,max:24)")
    }

    // (d) height above maxHeight (25 > 24) fails.
    do {
        let result = validateCustomDims(width: 20, height: 25, mines: 50)
        check(result == .failure(.heightOutOfBounds(min: 8, max: 24)),
              "height above maxHeight (25) fails with heightOutOfBounds(min:8,max:24)")
    }

    // (e) mines below the floor (0 < 1) fails with mineCountOutOfBounds. For
    // a 20x15 board, the ceiling is min(999, 19*14) = min(999, 266) = 266.
    do {
        let result = validateCustomDims(width: 20, height: 15, mines: 0)
        check(result == .failure(.mineCountOutOfBounds(min: 1, max: 266)),
              "mines below floor (0) fails with mineCountOutOfBounds(min:1,max:266)")
    }

    // (f) mines exactly at the (width-1)*(height-1) ceiling succeeds. For a
    // 10x10 board: (10-1)*(10-1) = 81, which is below the 999 hard cap, so
    // the board-size ceiling is the binding bound.
    do {
        let result = validateCustomDims(width: 10, height: 10, mines: 81)
        check(result == .success(BoardDims(rows: 10, cols: 10, mines: 81)),
              "mines exactly at the (width-1)*(height-1) ceiling (81 on a 10x10 board) succeeds")
    }

    // (g) mines one above that ceiling (82 on the same 10x10 board) fails
    // with mineCountOutOfBounds(min:1,max:81).
    do {
        let result = validateCustomDims(width: 10, height: 10, mines: 82)
        check(result == .failure(.mineCountOutOfBounds(min: 1, max: 81)),
              "mines one above the board-size ceiling (82 on a 10x10 board) fails")
    }

    // (h) mines at 999 succeeds when the board is large enough that the
    // board-size ceiling would otherwise exceed 999 -- override maxWidth/
    // maxHeight so a 50x50 board is permitted; (50-1)*(50-1) = 2401, so
    // min(999, 2401) = 999 is the binding (hard-cap) bound.
    do {
        let result = validateCustomDims(width: 50, height: 50, mines: 999,
                                         maxWidth: 100, maxHeight: 100)
        check(result == .success(BoardDims(rows: 50, cols: 50, mines: 999)),
              "mines at 999 succeeds on a large-enough board (hard cap reached exactly)")
    }

    // (i) mines at 1000 fails even on the same huge board -- the 999 hard
    // cap is never exceeded regardless of board size.
    do {
        let result = validateCustomDims(width: 50, height: 50, mines: 1000,
                                         maxWidth: 100, maxHeight: 100)
        check(result == .failure(.mineCountOutOfBounds(min: 1, max: 999)),
              "mines at 1000 fails even on a huge board (999 hard cap)")
    }

    // (j) a clearly valid mid-range case succeeds, and pins down the
    // width->cols / height->rows mapping convention.
    do {
        let result = validateCustomDims(width: 20, height: 15, mines: 50)
        check(result == .success(BoardDims(rows: 15, cols: 20, mines: 50)),
              "mid-range valid input (20x15, 50 mines) succeeds with width->cols, height->rows")
    }
}
