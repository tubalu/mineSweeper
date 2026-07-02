import AppKit
import MinesweeperCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private var boardView: BoardView!
    private var difficulty: Difficulty = .beginner
    private var preNightmareDifficulty: Difficulty = .beginner
    private var pendingDifficulty: Difficulty?
    /// True from the moment `toggleFullScreen` is invoked until the matching
    /// enter/exit notification fires. `difficulty` only updates once that
    /// notification lands, so without this guard a preset selection made
    /// during the ~0.3-0.5s system animation would branch on a stale
    /// `difficulty` and could fire a second overlapping `toggleFullScreen`.
    private var fullScreenTransitionInProgress = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        window = NSWindow(contentRect: .zero,
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "Minesweeper"
        window.delegate = self
        // The smallest playable board (8x8) sets the floor; AppKit clamps
        // drags to this automatically so windowWillResize never has to.
        let minLayout = Layout(rows: 8, cols: 8)
        window.contentMinSize = NSSize(width: minLayout.width, height: minLayout.height)
        window.collectionBehavior.insert(.fullScreenPrimary)
        // windowWillEnterFullScreen/windowDidEnterFullScreen/etc. below are
        // NSWindowDelegate protocol methods -- now that `window.delegate =
        // self` is set, AppKit calls them directly for every transition
        // (menu, native green button, or ^⌘F). No manual
        // NotificationCenter.addObserver is needed (and adding one would
        // double-fire alongside the automatic delegate dispatch).
        loadBoard(.beginner)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func loadBoard(_ d: Difficulty, screenSize: CGSize? = nil) {
        difficulty = d
        let dims = d.resolve(screenSize: screenSize ?? .zero)
        boardView = BoardView(board: Board(rows: dims.rows, cols: dims.cols, mineCount: dims.mines))
        window.contentView = boardView
        // `toggleFullScreen` alone does not resize window content to the
        // screen -- nightmareDims sizes the board to (screen - border/header),
        // so setContentSize already yields ~screen-sized content; position it
        // at the fullscreen space's origin instead of centering a windowed
        // preset.
        window.setContentSize(NSSize(width: boardView.layout.width, height: boardView.layout.height))
        if d == .nightmare, let origin = window.screen?.frame.origin {
            window.setFrameOrigin(origin)
        } else {
            window.center()
        }
        window.makeFirstResponder(boardView)
    }

    @objc private func newGame() { boardView.newGame() }

    @objc private func setBeginner() { selectPreset(.beginner) }
    @objc private func setIntermediate() { selectPreset(.intermediate) }
    @objc private func setExpert() { selectPreset(.expert) }

    @objc private func setNightmare() {
        guard !fullScreenTransitionInProgress else { return }
        guard difficulty != .nightmare else { boardView.newGame(); return }
        fullScreenTransitionInProgress = true
        window.toggleFullScreen(nil)
    }

    /// Selecting a windowed preset. If Nightmare is currently active this
    /// must first leave fullscreen -- the board load happens once
    /// `didExitFullScreenNotification` confirms the transition finished, so
    /// the final geometry is never computed against a stale frame.
    private func selectPreset(_ d: Difficulty) {
        guard !fullScreenTransitionInProgress else { return }
        guard difficulty == .nightmare else { loadBoard(d); return }
        pendingDifficulty = d
        fullScreenTransitionInProgress = true
        window.toggleFullScreen(nil)
    }

    @objc func windowWillEnterFullScreen(_ note: Notification) { fullScreenTransitionInProgress = true }
    @objc func windowWillExitFullScreen(_ note: Notification) { fullScreenTransitionInProgress = true }

    // MARK: - interactive window resize
    //
    // Nightmare is fullscreen-only and already owns its own sizing via the
    // fullscreen notifications above, so all of this is skipped whenever
    // `difficulty == .nightmare` or a fullscreen transition is in flight --
    // resize must never fight Nightmare's screen-driven layout.
    //
    // `windowWillResize` snaps the live-drag frame to whole cells on every
    // frame (cheap: pure geometry, no Board allocation). The board itself is
    // only rebuilt once, at the end of the gesture (`windowDidEndLiveResize`)
    // or for a non-live resize (`windowDidResize` while NOT `inLiveResize`,
    // e.g. the titlebar zoom button) -- rebuilding on every intermediate
    // `windowDidResize` frame during a drag would reset the board (and its
    // timer) dozens of times per gesture instead of once.

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        guard !fullScreenTransitionInProgress, difficulty != .nightmare else { return frameSize }
        let candidateFrame = NSRect(origin: sender.frame.origin, size: frameSize)
        let contentSize = sender.contentRect(forFrameRect: candidateFrame).size
        let fit = fitCells(availableWidth: Double(contentSize.width), availableHeight: Double(contentSize.height))
        guard fit.rows > 0, fit.cols > 0 else { return frameSize }
        let snapped = Layout(rows: fit.rows, cols: fit.cols)
        let snappedContent = NSRect(origin: .zero, size: NSSize(width: snapped.width, height: snapped.height))
        return sender.frameRect(forContentRect: snappedContent).size
    }

    func windowDidResize(_ notification: Notification) {
        guard !window.inLiveResize else { return }
        rebuildBoardForCurrentWindowSize()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        rebuildBoardForCurrentWindowSize()
    }

    /// Rebuilds the board to fit the window's current content size, at the
    /// fixed cell size (cells regrow/shrink in count, never stretch). Mine
    /// count stays exactly what it was UNLESS the new board is too small to
    /// safely hold it (its (cols-1)*(rows-1) safe-first-click ceiling would
    /// be exceeded), in which case mines are clamped down to that ceiling --
    /// resize must never produce an invalid board, even at the cost of
    /// reducing mines in an extreme shrink.
    private func rebuildBoardForCurrentWindowSize() {
        guard !fullScreenTransitionInProgress, difficulty != .nightmare else { return }
        let contentSize = window.contentRect(forFrameRect: window.frame).size
        let fit = fitCells(availableWidth: Double(contentSize.width), availableHeight: Double(contentSize.height))
        guard fit.rows > 0, fit.cols > 0 else { return }
        // Also the re-entrancy guard: `setContentSize` below fires another
        // `windowDidResize`, which calls back into this method -- that second
        // call sees a matching row/col count and returns here as a no-op.
        if fit.rows == boardView.board.rows, fit.cols == boardView.board.cols { return }
        let mines = min(boardView.board.mineCount, safeMineCeiling(rows: fit.rows, cols: fit.cols))
        boardView = BoardView(board: Board(rows: fit.rows, cols: fit.cols, mineCount: mines))
        window.contentView = boardView
        window.makeFirstResponder(boardView)
        window.setContentSize(NSSize(width: boardView.layout.width, height: boardView.layout.height))
    }

    /// Fires once the async fullscreen transition completes -- only then is
    /// `window.screen`'s frame final, so board construction is deferred here
    /// rather than done inline when Nightmare is selected. Also the single
    /// source of truth for what to restore on exit: `collectionBehavior`
    /// grants the native green-button fullscreen affordance at every
    /// difficulty, not just via `setNightmare()`, so this must capture
    /// whatever was active BEFORE this notification -- not assume the menu
    /// action was the only path in.
    @objc func windowDidEnterFullScreen(_ note: Notification) {
        fullScreenTransitionInProgress = false
        if difficulty != .nightmare { preNightmareDifficulty = difficulty }
        let size = window.screen?.frame.size ?? window.frame.size
        loadBoard(.nightmare, screenSize: size)
    }

    /// Fires on ANY exit from fullscreen -- Esc, the green button, or our own
    /// programmatic `toggleFullScreen` call from `selectPreset` -- so exit
    /// behavior is unconditional and idempotent regardless of cause.
    @objc func windowDidExitFullScreen(_ note: Notification) {
        fullScreenTransitionInProgress = false
        let target = pendingDifficulty ?? preNightmareDifficulty
        pendingDifficulty = nil
        loadBoard(target)
    }

    // MARK: - custom difficulty dialog

    /// Presents a modal width/height/mines form (an `NSAlert` accessory view,
    /// matching this codebase's existing no-Auto-Layout / manual-frame
    /// style). Re-prompts with the entered (invalid) values on failure so
    /// the specific violated bound can be shown and fixed in place, rather
    /// than a generic error or a silent clamp/crash. On success, routes
    /// through `selectPreset` so Custom gets identical Nightmare-exit and
    /// board-rebuild handling as the existing presets.
    @objc private func showCustomDialog() {
        guard !fullScreenTransitionInProgress else { return }
        // Clamp the prefill to Custom's own bounds -- if Nightmare is active
        // its board can be far larger than 30x24, which would otherwise
        // guarantee the very first "OK" is rejected on an unedited field.
        var width = min(boardView.board.cols, 30)
        var height = min(boardView.board.rows, 24)
        var mines = min(boardView.board.mineCount, safeMineCeiling(rows: height, cols: width))

        while true {
            let alert = NSAlert()
            alert.messageText = "Custom Game"
            alert.informativeText = "Enter board width, height, and mine count."
            alert.addButton(withTitle: "OK")
            alert.addButton(withTitle: "Cancel")

            let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 180, height: 78))
            let widthField = Self.labeledIntField(label: "Width:", value: width, y: 52, in: accessory)
            let heightField = Self.labeledIntField(label: "Height:", value: height, y: 26, in: accessory)
            let minesField = Self.labeledIntField(label: "Mines:", value: mines, y: 0, in: accessory)
            alert.accessoryView = accessory
            alert.window.initialFirstResponder = widthField

            guard alert.runModal() == .alertFirstButtonReturn else { return }  // Cancel

            width = widthField.integerValue
            height = heightField.integerValue
            mines = minesField.integerValue

            switch validateCustomDims(width: width, height: height, mines: mines) {
            case .success(let dims):
                selectPreset(.custom(dims))
                return
            case .failure(let error):
                Self.showValidationError(error)
            }
        }
    }

    private static func labeledIntField(label: String, value: Int, y: CGFloat, in container: NSView) -> NSTextField {
        let labelField = NSTextField(labelWithString: label)
        labelField.frame = NSRect(x: 0, y: y, width: 60, height: 20)
        container.addSubview(labelField)

        let field = NSTextField(frame: NSRect(x: 64, y: y, width: 100, height: 20))
        field.integerValue = value
        // No Auto Layout ties this field to `labelField`, so VoiceOver can't
        // infer the field's name from on-screen proximity -- set it explicitly.
        field.setAccessibilityLabel(label.trimmingCharacters(in: CharacterSet(charactersIn: ":")))
        container.addSubview(field)
        return field
    }

    private static func showValidationError(_ error: CustomDimsError) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Invalid Custom Game"
        switch error {
        case .widthOutOfBounds(let lo, let hi):
            alert.informativeText = "Width must be between \(lo) and \(hi)."
        case .heightOutOfBounds(let lo, let hi):
            alert.informativeText = "Height must be between \(lo) and \(hi)."
        case .mineCountOutOfBounds(let lo, let hi):
            alert.informativeText = "Mines must be between \(lo) and \(hi)."
        }
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func buildMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Minesweeper",
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let gameItem = NSMenuItem()
        mainMenu.addItem(gameItem)
        let gameMenu = NSMenu(title: "Game")

        let newItem = NSMenuItem(title: "New Game", action: #selector(newGame), keyEquivalent: "n")
        newItem.target = self
        gameMenu.addItem(newItem)
        gameMenu.addItem(.separator())

        let diffMenu = NSMenu(title: "Difficulty")
        let presets: [(String, Selector, String)] = [
            ("Beginner", #selector(setBeginner), "1"),
            ("Intermediate", #selector(setIntermediate), "2"),
            ("Expert", #selector(setExpert), "3"),
            ("Nightmare", #selector(setNightmare), "4"),
        ]
        for (title, sel, key) in presets {
            let item = NSMenuItem(title: title, action: sel, keyEquivalent: key)
            item.target = self
            diffMenu.addItem(item)
        }
        diffMenu.addItem(.separator())
        let customItem = NSMenuItem(title: "Custom…", action: #selector(showCustomDialog), keyEquivalent: "5")
        customItem.target = self
        diffMenu.addItem(customItem)
        let diffItem = NSMenuItem(title: "Difficulty", action: nil, keyEquivalent: "")
        diffItem.submenu = diffMenu
        gameMenu.addItem(diffItem)

        gameItem.submenu = gameMenu
        NSApp.mainMenu = mainMenu
    }
}
