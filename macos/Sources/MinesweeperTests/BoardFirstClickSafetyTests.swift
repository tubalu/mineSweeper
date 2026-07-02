import Foundation
import MinesweeperCore

// ---------------------------------------------------------------------------
// First-click safety in Board (macos/Sources/MinesweeperCore/Board.swift)
// ---------------------------------------------------------------------------
// Mines must NOT be placed during reset()/init anymore. Placement is
// deferred until the first `reveal(_:_:)` call, which places mines
// excluding the clicked cell's full 3x3 neighborhood (clamped to board
// bounds), then computes counts, then proceeds with the normal
// reveal/flood. The excluded mines must be relocated elsewhere on the
// board -- NOT dropped -- so the total mine count is unchanged. A second
// `reveal` call must be a no-op with respect to mine placement (idempotent).
//
// NOTE: `setMines(_:)` (used throughout main.swift for deterministic tests)
// must remain a synchronous, immediate placement path, unaffected by this
// change -- all the existing `mineAtOrigin()`-based tests in main.swift must
// keep passing unmodified.

private func anyMinePlaced(_ b: Board) -> Bool {
    (0 ..< b.rows).contains { r in (0 ..< b.cols).contains { c in b.isMine[r][c] } }
}

private func totalMinesPlaced(_ b: Board) -> Int {
    (0 ..< b.rows).reduce(0) { acc, r in acc + (0 ..< b.cols).filter { b.isMine[r][$0] }.count }
}

/// The clicked cell plus its full 3x3 neighborhood, clamped to board bounds.
private func firstClickSafeZone(rows: Int, cols: Int, r: Int, c: Int) -> [Position] {
    var result: [Position] = []
    for dr in -1 ... 1 {
        for dc in -1 ... 1 {
            let nr = r + dr, nc = c + dc
            if nr >= 0, nr < rows, nc >= 0, nc < cols {
                result.append(Position(nr, nc))
            }
        }
    }
    return result
}

func runBoardFirstClickSafetyTests() {
    // (a) reset() alone (no reveal) places no mines yet.
    do {
        var b = Board(rows: 16, cols: 30, mineCount: 99)
        b.reset()
        check(!anyMinePlaced(b), "reset() alone defers mine placement (zero mines placed pre-reveal)")
    }

    do {
        let b = Board(rows: 9, cols: 9, mineCount: 10)
        check(!anyMinePlaced(b), "init() alone defers mine placement (zero mines placed pre-reveal)")
    }

    // (b) first reveal excludes the clicked cell's full 3x3 neighborhood,
    // clamped to board bounds, from mine placement -- corner, center, edge.
    let firstClickCases: [(rows: Int, cols: Int, mines: Int, r: Int, c: Int, label: String)] = [
        (16, 30, 99, 0, 0, "top-left corner (0,0)"),
        (16, 30, 99, 15, 29, "bottom-right corner (15,29)"),
        (16, 30, 99, 8, 15, "center (8,15)"),
        (16, 30, 99, 0, 15, "top edge (0,15)"),
        (16, 30, 99, 15, 0, "bottom-left edge (15,0)"),
        (9, 9, 10, 4, 4, "small board center (4,4)"),
    ]
    for tc in firstClickCases {
        var b = Board(rows: tc.rows, cols: tc.cols, mineCount: tc.mines)
        b.reveal(tc.r, tc.c)
        let zone = firstClickSafeZone(rows: tc.rows, cols: tc.cols, r: tc.r, c: tc.c)
        let zoneHasMine = zone.contains { b.isMine[$0.row][$0.col] }
        check(!zoneHasMine, "first reveal at \(tc.label) keeps its 3x3 neighborhood mine-free")
    }

    // (c) excluded mines are relocated elsewhere, not dropped: the full mine
    // count is still placed on the board after the first reveal.
    for tc in firstClickCases {
        var b = Board(rows: tc.rows, cols: tc.cols, mineCount: tc.mines)
        b.reveal(tc.r, tc.c)
        check(totalMinesPlaced(b) == tc.mines,
              "\(tc.label): full mine count (\(tc.mines)) is still placed after exclusion")
    }

    // (d) a second reveal call does not re-place mines (idempotent).
    do {
        var b = Board(rows: 16, cols: 16, mineCount: 40)
        b.reveal(5, 5)
        let minesAfterFirst = b.isMine
        // Find another covered, non-revealed cell to click a second time.
        var target: Position?
        outer: for r in 0 ..< 16 {
            for c in 0 ..< 16 where b.state[r][c] == .covered {
                target = Position(r, c)
                break outer
            }
        }
        if let target {
            b.reveal(target.row, target.col)
        }
        check(b.isMine == minesAfterFirst, "second reveal does not re-place mines (idempotent mine layout)")
    }
}
