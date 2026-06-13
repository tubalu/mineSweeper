import Foundation
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
    let mineTotal = (0 ..< 3).reduce(0) { acc, r in acc + (0 ..< 3).filter { b.isMine[r][$0] }.count }
    check(!b.gameOver && !b.win && b.detonated == nil && fresh, "reset restores a fresh board")
    check(mineTotal == b.mineCount, "reset re-seeds the right number of mines")
}

print(failures == 0 ? "\nAll tests passed" : "\n\(failures) test(s) FAILED")
exit(failures == 0 ? 0 : 1)
