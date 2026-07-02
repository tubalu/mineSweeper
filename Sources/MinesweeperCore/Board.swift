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

    /// Mines are deferred until the first `reveal` (first-click safety) unless
    /// placed deterministically via `setMines`.
    private var minesPlaced = false

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
        minesPlaced = false
    }

    /// Deterministically place mines (used by tests). Placement is immediate
    /// and not subject to first-click exclusion.
    public mutating func setMines(_ coords: [Position]) {
        isMine = Self.grid(rows, cols, false)
        for p in coords { isMine[p.row][p.col] = true }
        mineCount = coords.count
        state = Self.grid(rows, cols, CellState.covered)
        counts = Self.grid(rows, cols, 0)
        gameOver = false
        win = false
        detonated = nil
        minesPlaced = true
        computeCounts()
    }

    /// Randomly places `mineCount` mines, excluding `excluded` cells (relocating
    /// what would have landed there elsewhere so the total count is unchanged).
    private mutating func placeRandomMines(excluding excluded: Set<Position>) {
        let excludedIdx = Set(excluded.map { $0.row * cols + $0.col })
        let available = (0 ..< rows * cols).filter { !excludedIdx.contains($0) }
        let target = min(mineCount, available.count)
        // Keep mineCount in sync with what's actually placed -- if the safe
        // zone leaves fewer available cells than requested mines, mineCount
        // (and therefore minesRemaining()) must reflect the placed total,
        // not the original request.
        mineCount = target
        var chosen = Set<Int>()
        while chosen.count < target {
            chosen.insert(available[Int.random(in: 0 ..< available.count)])
        }
        for idx in chosen { isMine[idx / cols][idx % cols] = true }
        minesPlaced = true
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
        if !minesPlaced {
            var safeZone = Set(neighbors(r, c))
            safeZone.insert(Position(r, c))
            placeRandomMines(excluding: safeZone)
            computeCounts()
        }
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
