import Foundation
import AppKit
import MinesweeperCore

// Lightweight assertion runner (XCTest needs Xcode; this runs under CLT-only).
// Mirrors test_mine1.py.

var failures = 0
func check(_ cond: Bool, _ name: String) {
    if cond {
        print("ok   - \(name)")
    } else {
        print("FAIL - \(name)")
        failures += 1
    }
}

/// 3x3 board with a single mine at (0,0):  M 1 0 / 1 1 0 / 0 0 0
func mineAtOrigin() -> Board {
    var b = Board(rows: 3, cols: 3, mineCount: 0)
    b.setMines([Position(0, 0)])
    return b
}

// board setup
do {
    let b = mineAtOrigin()
    check(b.isMine[0][0], "mine placed at origin")
    check(b.counts[0][1] == 1 && b.counts[1][0] == 1 && b.counts[1][1] == 1,
          "adjacency counts around single mine")
    check(b.counts[0][2] == 0 && b.counts[2][2] == 0, "far cells count zero")
}

do {
    let b = Board(rows: 10, cols: 10, mineCount: 20)
    let allCovered = (0 ..< 10).allSatisfy { r in (0 ..< 10).allSatisfy { b.state[r][$0] == .covered } }
    check(allCovered, "mines hidden until revealed (regression)")
}

// reveal & cascade
do {
    var b = mineAtOrigin()
    b.reveal(0, 0)
    check(b.gameOver && !b.win && b.detonated == Position(0, 0), "revealing a mine loses + records detonation")
}

do {
    var b = mineAtOrigin()
    b.reveal(2, 2)  // a zero cell
    check(b.state[0][1] == .revealed, "cascade reveals numbered border")
    check(b.state[1][1] == .revealed, "cascade reveals the diagonal 1")
    check(b.win, "full clear from a zero => win")
}

do {
    var b = Board(rows: 3, cols: 3, mineCount: 0)
    b.reveal(1, 1)
    let all = (0 ..< 3).allSatisfy { r in (0 ..< 3).allSatisfy { b.state[r][$0] == .revealed } }
    check(all && b.win, "no-mines first reveal clears and wins")
}

do {
    var b = mineAtOrigin()
    b.toggleFlag(1, 1)
    b.reveal(1, 1)
    check(b.state[1][1] == .flagged, "flag protects against reveal")
}

// flagging
do {
    var b = mineAtOrigin()
    check(b.toggleFlag(0, 1) && b.state[0][1] == .flagged, "flag sets on covered cell")
    check(b.toggleFlag(0, 1) && b.state[0][1] == .covered, "flag toggles off")
}

do {
    var b = mineAtOrigin()
    b.reveal(1, 1)
    check(!b.toggleFlag(1, 1) && b.state[1][1] == .revealed, "cannot flag a revealed cell")
}

do {
    var b = mineAtOrigin()
    check(b.minesRemaining() == 1, "mines remaining starts at mine count")
    b.toggleFlag(0, 1)
    check(b.minesRemaining() == 0, "mines remaining counts down with flags")
}

// chording
do {
    var b = mineAtOrigin()
    b.reveal(1, 1)        // the "1"
    b.toggleFlag(0, 0)    // correctly flag the only mine
    b.chord(1, 1)
    check(b.detonated == nil, "chord opens only safe cells")
    check(b.state[0][1] == .revealed, "chord revealed a safe neighbor")
    check(b.win, "chord full clear => win")
}

do {
    var b = mineAtOrigin()
    b.reveal(1, 1)
    b.toggleFlag(0, 1)    // WRONG: flag a safe cell
    b.chord(1, 1)
    check(b.gameOver && !b.win, "chord with wrong flag detonates")
}

do {
    var b = mineAtOrigin()
    b.reveal(1, 1)        // zero flags around it
    b.chord(1, 1)
    check(b.state[0][0] == .covered && !b.gameOver, "chord is a no-op when flag count mismatches")
}

do {
    var b = mineAtOrigin()
    b.chord(1, 1)         // not revealed yet
    check(b.state[1][1] == .covered, "chord on unrevealed cell is a no-op")
}

// reset
do {
    var b = mineAtOrigin()
    b.reveal(0, 0)        // lose
    b.reset()
    let fresh = (0 ..< 3).allSatisfy { r in (0 ..< 3).allSatisfy { b.state[r][$0] == .covered } }
    check(!b.gameOver && !b.win && b.detonated == nil && fresh, "reset restores a fresh board")
    // Mines are deferred until the first reveal (first-click safety), so
    // immediately after reset() none are placed yet.
    let mineTotalBeforeReveal = (0 ..< 3).reduce(0) { acc, r in acc + (0 ..< 3).filter { b.isMine[r][$0] }.count }
    check(mineTotalBeforeReveal == 0, "reset defers mine placement until the first reveal")
    b.reveal(2, 2)
    let mineTotalAfterReveal = (0 ..< 3).reduce(0) { acc, r in acc + (0 ..< 3).filter { b.isMine[r][$0] }.count }
    check(mineTotalAfterReveal == b.mineCount, "first reveal after reset re-seeds the right number of mines")
}

// ---------------------------------------------------------------------------
// IconArt rendering tests
// ---------------------------------------------------------------------------
// Helper: render IconArt into an offscreen bitmap at the given size.
// Uses the shared exact-pixel renderer (NSImage.lockFocus would yield 2x
// output on Retina, so 1 pt != 1 px and pixel sampling would be off-center).

func renderIconArt(size: CGFloat) -> NSBitmapImageRep {
    IconArt.renderBitmap(pixels: Int(size))
}

// Helper: brightness in [0, 1] from an NSColor (device-space approximation).
func brightness(of color: NSColor) -> CGFloat {
    guard let c = color.usingColorSpace(.deviceRGB) else { return 0 }
    return (c.redComponent + c.greenComponent + c.blueComponent) / 3.0
}

// 1. NON-BLANK: rendering at size 64 produces at least two distinct pixel
//    colors — proves something was drawn, not just a blank canvas.
do {
    let bmp = renderIconArt(size: 64)
    let mid = Int(64 / 2)
    // Sample top-left corner vs center; they must differ if anything was drawn.
    let corner = bmp.colorAt(x: 2, y: 2)!
    let center = bmp.colorAt(x: mid, y: mid)!
    let cornerBrightness = brightness(of: corner)
    let centerBrightness = brightness(of: center)
    check(abs(cornerBrightness - centerBrightness) > 0.05,
          "icon draw(size:64) is non-blank: corner and center differ in brightness")
}

// 2. DARK CENTER: pixels near the center of the 64-pt icon are dark (mine is
//    black). Check a 3-pixel cluster around the exact center; all must be
//    below 0.35 brightness (dark, but not necessarily pure black, due to
//    anti-aliasing).
do {
    let bmp = renderIconArt(size: 64)
    let mid = Int(64 / 2)
    let offsets = [0, 1, -1]
    let allDark = offsets.allSatisfy { dx in
        offsets.allSatisfy { dy in
            guard let c = bmp.colorAt(x: mid + dx, y: mid + dy) else { return false }
            return brightness(of: c) < 0.35
        }
    }
    check(allDark, "icon draw(size:64) center pixels are dark (mine is black)")
}

// 3. GRAY CORNER: the top-left corner pixel is approximately Win95 face gray
//    (192/255 ≈ 0.753). Allow a tolerance of ±20 per channel (~0.078 in [0,1]).
do {
    let bmp = renderIconArt(size: 64)
    let corner = bmp.colorAt(x: 2, y: 2)!
    let c = corner.usingColorSpace(.deviceRGB)
    let target: CGFloat = 192.0 / 255.0   // ~0.753
    let tol:    CGFloat = 20.0  / 255.0   // ~0.078
    let isGray: Bool = {
        guard let c else { return false }
        let rOk = abs(c.redComponent   - target) <= tol
        let gOk = abs(c.greenComponent - target) <= tol
        let bOk = abs(c.blueComponent  - target) <= tol
        return rOk && gOk && bOk
    }()
    check(isGray,
          "icon draw(size:64) corner pixel is Win95 face gray (~192,192,192) within ±20")
}

// 4. SMALL SIZE: draw(size:16) must complete without crashing. If we reach
//    the check line the call did not crash.
do {
    let _ = renderIconArt(size: 16)
    check(true, "icon draw(size:16) completes without crashing (small-size path)")
}

// ---------------------------------------------------------------------------
// Nightmare-mode feature tests (currently RED -- production code not yet
// implemented). See BoardFirstClickSafetyTests.swift, NightmareSizingTests.swift,
// DifficultyResolveTests.swift, LayoutCellRangeTests.swift.
// ---------------------------------------------------------------------------
runBoardFirstClickSafetyTests()
runNightmareSizingTests()
runDifficultyResolveTests()
runLayoutCellRangeTests()
runCustomDifficultyResolveTests()
runCustomDimsValidationTests()
runFitCellsTests()

print(failures == 0 ? "\nAll tests passed" : "\n\(failures) test(s) FAILED")
exit(failures == 0 ? 0 : 1)
