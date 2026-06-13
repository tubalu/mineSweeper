import AppKit
import MinesweeperCore

enum Difficulty {
    case beginner, intermediate, expert

    var dims: (rows: Int, cols: Int, mines: Int) {
        switch self {
        case .beginner: return (9, 9, 10)
        case .intermediate: return (16, 16, 40)
        case .expert: return (16, 30, 99)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var boardView: BoardView!
    private var difficulty: Difficulty = .beginner

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        window = NSWindow(contentRect: .zero,
                          styleMask: [.titled, .closable, .miniaturizable],
                          backing: .buffered, defer: false)
        window.title = "Minesweeper"
        loadBoard(.beginner)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    private func loadBoard(_ d: Difficulty) {
        difficulty = d
        let dims = d.dims
        boardView = BoardView(board: Board(rows: dims.rows, cols: dims.cols, mineCount: dims.mines))
        window.contentView = boardView
        window.setContentSize(NSSize(width: boardView.layout.width, height: boardView.layout.height))
        window.center()
        window.makeFirstResponder(boardView)
    }

    @objc private func newGame() { boardView.newGame() }
    @objc private func setBeginner() { loadBoard(.beginner) }
    @objc private func setIntermediate() { loadBoard(.intermediate) }
    @objc private func setExpert() { loadBoard(.expert) }

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
