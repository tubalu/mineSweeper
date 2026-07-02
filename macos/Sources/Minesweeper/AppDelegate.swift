import AppKit
import MinesweeperCore

final class AppDelegate: NSObject, NSApplicationDelegate {
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
                          styleMask: [.titled, .closable, .miniaturizable],
                          backing: .buffered, defer: false)
        window.title = "Minesweeper"
        window.collectionBehavior.insert(.fullScreenPrimary)
        // Will-notifications fire the instant a transition starts, regardless
        // of trigger (our menu, the native green button, or ^⌘F) -- these set
        // the in-progress guard for every path, not just our own selectors.
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowWillEnterFullScreen(_:)),
            name: NSWindow.willEnterFullScreenNotification, object: window)
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowWillExitFullScreen(_:)),
            name: NSWindow.willExitFullScreenNotification, object: window)
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowDidEnterFullScreen(_:)),
            name: NSWindow.didEnterFullScreenNotification, object: window)
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowDidExitFullScreen(_:)),
            name: NSWindow.didExitFullScreenNotification, object: window)
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
        if d != .nightmare {
            window.setContentSize(NSSize(width: boardView.layout.width, height: boardView.layout.height))
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

    @objc private func windowWillEnterFullScreen(_ note: Notification) { fullScreenTransitionInProgress = true }
    @objc private func windowWillExitFullScreen(_ note: Notification) { fullScreenTransitionInProgress = true }

    /// Fires once the async fullscreen transition completes -- only then is
    /// `window.screen`'s frame final, so board construction is deferred here
    /// rather than done inline when Nightmare is selected. Also the single
    /// source of truth for what to restore on exit: `collectionBehavior`
    /// grants the native green-button fullscreen affordance at every
    /// difficulty, not just via `setNightmare()`, so this must capture
    /// whatever was active BEFORE this notification -- not assume the menu
    /// action was the only path in.
    @objc private func windowDidEnterFullScreen(_ note: Notification) {
        fullScreenTransitionInProgress = false
        if difficulty != .nightmare { preNightmareDifficulty = difficulty }
        let size = window.screen?.frame.size ?? window.frame.size
        loadBoard(.nightmare, screenSize: size)
    }

    /// Fires on ANY exit from fullscreen -- Esc, the green button, or our own
    /// programmatic `toggleFullScreen` call from `selectPreset` -- so exit
    /// behavior is unconditional and idempotent regardless of cause.
    @objc private func windowDidExitFullScreen(_ note: Notification) {
        fullScreenTransitionInProgress = false
        let target = pendingDifficulty ?? preNightmareDifficulty
        pendingDifficulty = nil
        loadBoard(target)
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
        let diffItem = NSMenuItem(title: "Difficulty", action: nil, keyEquivalent: "")
        diffItem.submenu = diffMenu
        gameMenu.addItem(diffItem)

        gameItem.submenu = gameMenu
        NSApp.mainMenu = mainMenu
    }
}
