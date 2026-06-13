import Foundation

/// A grid coordinate. Hashable so it can live in sets (pressed-preview, etc.).
public struct Position: Hashable {
    public let row: Int
    public let col: Int
    public init(_ row: Int, _ col: Int) {
        self.row = row
        self.col = col
    }
}

public enum CellState: Equatable {
    case covered
    case revealed
    case flagged
}

/// Headless Minesweeper game state. Value type with mutating actions; no UI
/// dependency, so it is fully unit-testable. Port of the Python
/// `MinesweeperGame`, keeping `isMine` and `counts` as separate grids so a
/// "1 adjacent mine" cell can never be confused with a mine.
public struct Board {
    public let rows: Int
    public let cols: Int
    public private(set) var mineCount: Int

    public private(set) var isMine: [[Bool]]
    public private(set) var counts: [[Int]]
    public private(set) var state: [[CellState]]
    public private(set) var gameOver: Bool = false
    public private(set) var win: Bool = false
    public private(set) var detonated: Position?

    public init(rows: Int, cols: Int, mineCount: Int) {
        self.rows = rows
        self.cols = cols
        self.mineCount = mineCount
        self.isMine = Self.grid(rows, cols, false)
        self.counts = Self.grid(rows, cols, 0)
        self.state = Self.grid(rows, cols, CellState.covered)
        reset()
    }

    private static func grid<T>(_ rows: Int, _ cols: Int, _ value: T) -> [[T]] {
        Array(repeating: Array(repeating: value, count: cols), count: rows)
    }

    // MARK: - lifecycle

    public mutating func reset() {
        isMine = Self.grid(rows, cols, false)
        counts = Self.grid(rows, cols, 0)
        state = Self.grid(rows, cols, CellState.covered)
        gameOver = false
        win = false
        detonated = nil
        placeRandomMines()
        computeCounts()
    }

    /// Deterministically place mines (used by tests).
    public mutating func setMines(_ coords: [Position]) {
        isMine = Self.grid(rows, cols, false)
        for p in coords { isMine[p.row][p.col] = true }
        mineCount = coords.count
        state = Self.grid(rows, cols, CellState.covered)
        counts = Self.grid(rows, cols, 0)
        gameOver = false
        win = false
        detonated = nil
        computeCounts()
    }

    private mutating func placeRandomMines() {
        let target = min(mineCount, rows * cols)
        var chosen = Set<Int>()
        while chosen.count < target {
            chosen.insert(Int.random(in: 0 ..< rows * cols))
        }
        for idx in chosen { isMine[idx / cols][idx % cols] = true }
    }

    public func neighbors(_ r: Int, _ c: Int) -> [Position] {
        var result: [Position] = []
        for dr in -1 ... 1 {
            for dc in -1 ... 1 where !(dr == 0 && dc == 0) {
                let nr = r + dr, nc = c + dc
                if nr >= 0, nr < rows, nc >= 0, nc < cols {
                    result.append(Position(nr, nc))
                }
            }
        }
        return result
    }

    private mutating func computeCounts() {
        for r in 0 ..< rows {
            for c in 0 ..< cols where !isMine[r][c] {
                counts[r][c] = neighbors(r, c).filter { isMine[$0.row][$0.col] }.count
            }
        }
    }

    // MARK: - player actions

    public mutating func reveal(_ r: Int, _ c: Int) {
        guard !gameOver, state[r][c] == .covered else { return }
        if isMine[r][c] {
            state[r][c] = .revealed
            detonated = Position(r, c)
            gameOver = true
            win = false
            return
        }
        flood(r, c)
        checkWin()
    }

    /// Iterative flood-fill: open the cell and, for any zero, its whole
    /// contiguous region plus the surrounding numbered border.
    private mutating func flood(_ r: Int, _ c: Int) {
        var stack = [Position(r, c)]
        while let p = stack.popLast() {
            if state[p.row][p.col] != .covered || isMine[p.row][p.col] { continue }
            state[p.row][p.col] = .revealed
            if counts[p.row][p.col] == 0 {
                for n in neighbors(p.row, p.col)
                where state[n.row][n.col] == .covered && !isMine[n.row][n.col] {
                    stack.append(n)
                }
            }
        }
    }

    @discardableResult
    public mutating func toggleFlag(_ r: Int, _ c: Int) -> Bool {
        guard !gameOver else { return false }
        switch state[r][c] {
        case .covered: state[r][c] = .flagged; return true
        case .flagged: state[r][c] = .covered; return true
        case .revealed: return false
        }
    }

    /// Reveal all unflagged neighbors of a revealed number, but only when its
    /// adjacent flag count already equals the number (classic chording).
    public mutating func chord(_ r: Int, _ c: Int) {
        guard !gameOver, state[r][c] == .revealed, counts[r][c] > 0 else { return }
        let flags = neighbors(r, c).filter { state[$0.row][$0.col] == .flagged }.count
        guard flags == counts[r][c] else { return }
        for n in neighbors(r, c) where state[n.row][n.col] == .covered {
            reveal(n.row, n.col)
            if gameOver { return }
        }
    }

    // MARK: - queries

    public func minesRemaining() -> Int {
        var flags = 0
        for r in 0 ..< rows {
            for c in 0 ..< cols where state[r][c] == .flagged { flags += 1 }
        }
        return mineCount - flags
    }

    private mutating func checkWin() {
        for r in 0 ..< rows {
            for c in 0 ..< cols where !isMine[r][c] && state[r][c] != .revealed {
                return
            }
        }
        win = true
        gameOver = true
    }
}
