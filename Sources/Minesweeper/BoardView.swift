import AppKit
import MinesweeperCore

/// The interactive board. Translates AppKit mouse/keyboard events into game
/// actions and renders via the shared `Renderer`. `isFlipped` gives a top-left
/// origin so the geometry matches `Layout`.
final class BoardView: NSView {
    private(set) var board: Board { didSet { needsDisplay = true } }
    let layout: Layout

    private var leftDown = false
    private var rightDown = false
    private var chording = false        // both buttons held: chord fires on release
    private var chordArmed = false      // suppress stray reveal while a chord resolves
    private var hover: Position?
    private var seconds = 0
    private var timer: Timer?
    private var timerRunning = false
    private var trackingArea: NSTrackingArea?
    private let confetti = ConfettiOverlay(frame: .zero)
    private var celebratedWin = false

    init(board: Board) {
        self.board = board
        self.layout = Layout(rows: board.rows, cols: board.cols)
        super.init(frame: NSRect(x: 0, y: 0, width: layout.width, height: layout.height))
        confetti.frame = bounds
        confetti.autoresizingMask = [.width, .height]
        addSubview(confetti)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = trackingArea { removeTrackingArea(t) }
        let t = NSTrackingArea(rect: bounds,
                               options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect],
                               owner: self)
        addTrackingArea(t)
        trackingArea = t
    }

    override func draw(_ dirtyRect: NSRect) {
        Renderer.draw(board: board, layout: layout, pressed: pressedPreview(),
                      seconds: seconds, dirtyRect: dirtyRect)
    }

    private func pressedPreview() -> Set<Position> {
        guard !board.gameOver, let h = hover else { return [] }
        if leftDown && rightDown {
            var s = Set(board.neighbors(h.row, h.col))
            s.insert(h)
            return s
        }
        return leftDown ? [h] : []
    }

    private func pos(_ event: NSEvent) -> Position? {
        layout.cellAt(convert(event.locationInWindow, from: nil))
    }

    // MARK: - mouse

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if layout.smileyRect.contains(p) { newGame(); return }
        leftDown = true
        hover = layout.cellAt(p)
        if rightDown { chording = true; chordArmed = true }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        leftDown = false
        hover = pos(event)
        if chording {
            if let h = hover { startTimer(); board.chord(h.row, h.col) }
            chording = false
        } else if !chordArmed, !board.gameOver, let h = hover {
            startTimer()
            board.reveal(h.row, h.col)
        }
        if !leftDown, !rightDown { chordArmed = false }
        needsDisplay = true
        celebrateIfWon()
    }

    override func rightMouseDown(with event: NSEvent) {
        rightDown = true
        hover = pos(event)
        if leftDown {
            chording = true
            chordArmed = true
        } else if let h = hover {
            board.toggleFlag(h.row, h.col)
        }
        needsDisplay = true
    }

    override func rightMouseUp(with event: NSEvent) {
        rightDown = false
        hover = pos(event)
        if chording {
            if let h = hover { startTimer(); board.chord(h.row, h.col) }
            chording = false
        }
        if !leftDown, !rightDown { chordArmed = false }
        needsDisplay = true
        celebrateIfWon()
    }

    override func otherMouseDown(with event: NSEvent) {
        if let h = pos(event) { startTimer(); board.chord(h.row, h.col) }
        chordArmed = true
        needsDisplay = true
        celebrateIfWon()
    }

    override func otherMouseUp(with event: NSEvent) {
        if !leftDown, !rightDown { chordArmed = false }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) { hover = pos(event); needsDisplay = true }
    override func rightMouseDragged(with event: NSEvent) { hover = pos(event); needsDisplay = true }
    override func mouseMoved(with event: NSEvent) { hover = pos(event); needsDisplay = true }

    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers?.lowercased() == "r" {
            newGame()
        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: - game control

    func newGame() {
        board.reset()
        seconds = 0
        timerRunning = false
        timer?.invalidate()
        timer = nil
        celebratedWin = false
        confetti.stop()
        needsDisplay = true
    }

    private func celebrateIfWon() {
        guard board.win, !celebratedWin else { return }
        celebratedWin = true
        confetti.burst()
    }

    private func startTimer() {
        guard !timerRunning, !board.gameOver else { return }
        timerRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.board.gameOver {
                self.timerRunning = false
                self.timer?.invalidate()
                return
            }
            if self.seconds < 999 {
                self.seconds += 1
                self.needsDisplay = true
            }
        }
    }
}
