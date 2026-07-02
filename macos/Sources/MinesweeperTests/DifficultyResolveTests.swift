import Foundation
import MinesweeperCore

// ---------------------------------------------------------------------------
// Difficulty.resolve(screenSize:)
// ---------------------------------------------------------------------------
// `Difficulty` currently lives as an app-target-only enum in
// macos/Sources/Minesweeper/AppDelegate.swift, with a non-screen-aware
// `.dims` computed property (no `.nightmare` case). Per the approved plan,
// production code will need to move (or duplicate-and-expose) `Difficulty`
// into MinesweeperCore so it is screen-size-aware and importable from a
// headless target like this one. These tests are written against the
// expected public signature in MinesweeperCore:
//
//   public enum Difficulty { case beginner, intermediate, expert, nightmare
//     public func resolve(screenSize: CGSize) -> BoardDims
//   }
//
// The three existing presets (beginner/intermediate/expert) must return
// their existing static dims UNCHANGED regardless of the screenSize
// argument; `.nightmare` must return dims computed via `nightmareDims(...)`
// using the passed screen size.

func runDifficultyResolveTests() {
    let smallScreen = CGSize(width: 800, height: 600)
    let largeScreen = CGSize(width: 1920, height: 1080)

    // (a) beginner/intermediate/expert dims match their known current values
    // and are identical for two different screenSize arguments (i.e. screen
    // size is ignored for presets).
    do {
        let beginnerSmall = Difficulty.beginner.resolve(screenSize: smallScreen)
        let beginnerLarge = Difficulty.beginner.resolve(screenSize: largeScreen)
        check(beginnerSmall == BoardDims(rows: 9, cols: 9, mines: 10),
              "beginner dims match known preset (9x9/10)")
        check(beginnerSmall == beginnerLarge, "beginner dims ignore screenSize")
    }

    do {
        let intermediateSmall = Difficulty.intermediate.resolve(screenSize: smallScreen)
        let intermediateLarge = Difficulty.intermediate.resolve(screenSize: largeScreen)
        check(intermediateSmall == BoardDims(rows: 16, cols: 16, mines: 40),
              "intermediate dims match known preset (16x16/40)")
        check(intermediateSmall == intermediateLarge, "intermediate dims ignore screenSize")
    }

    do {
        let expertSmall = Difficulty.expert.resolve(screenSize: smallScreen)
        let expertLarge = Difficulty.expert.resolve(screenSize: largeScreen)
        check(expertSmall == BoardDims(rows: 16, cols: 30, mines: 99),
              "expert dims match known preset (16x30/99)")
        check(expertSmall == expertLarge, "expert dims ignore screenSize")
    }

    // (b) .nightmare with a given screenSize matches directly calling
    // nightmareDims with the same parameters.
    do {
        let screen = CGSize(width: 1512, height: 982)
        let viaDifficulty = Difficulty.nightmare.resolve(screenSize: screen)
        let viaDirect = nightmareDims(screenWidth: Double(screen.width), screenHeight: Double(screen.height))
        check(viaDifficulty == viaDirect,
              "nightmare resolve(screenSize:) matches direct nightmareDims(...) call")
    }
}
