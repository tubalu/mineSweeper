import AppKit
import MinesweeperCore

// Offscreen render of representative board states to PNG, for visual
// verification without launching a window.

func render(_ board: Board, layout: Layout, seconds: Int, to path: String) {
    let image = NSImage(size: NSSize(width: layout.width, height: layout.height))
    image.lockFocusFlipped(true)
    Renderer.draw(board: board, layout: layout, pressed: [], seconds: seconds)
    image.unlockFocus()
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("failed to encode PNG\n".utf8))
        exit(1)
    }
    do {
        try png.write(to: URL(fileURLWithPath: path))
        print("saved \(path)")
    } catch {
        FileHandle.standardError.write(Data("write failed: \(error)\n".utf8))
        exit(1)
    }
}

let args = CommandLine.arguments
let midPath = args.count > 1 ? args[1] : "/tmp/msw_mid.png"
let overPath = args.count > 2 ? args[2] : "/tmp/msw_over.png"

let layout = Layout(rows: 10, cols: 10)
let mines = [(0, 7), (0, 8), (1, 9), (2, 6), (3, 8), (5, 1),
             (6, 2), (7, 7), (8, 4), (9, 9), (4, 4), (2, 2)].map { Position($0.0, $0.1) }

var mid = Board(rows: 10, cols: 10, mineCount: 20)
mid.setMines(mines)
mid.reveal(9, 0)        // cascade
mid.reveal(0, 0)
mid.toggleFlag(0, 7)
mid.toggleFlag(1, 9)
render(mid, layout: layout, seconds: 42, to: midPath)

var over = Board(rows: 10, cols: 10, mineCount: 20)
over.setMines(mines)
over.reveal(9, 0)
over.toggleFlag(5, 5)   // wrong flag (no mine there)
over.reveal(2, 2)       // detonate
render(over, layout: layout, seconds: 99, to: overPath)
