// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Minesweeper",
    platforms: [.macOS(.v12)],
    targets: [
        // Pure logic + AppKit-based rendering (drawing is a function of state).
        .target(name: "MinesweeperCore"),
        // The native app (NSApplication + window + menu bar + NSView).
        .executableTarget(name: "Minesweeper", dependencies: ["MinesweeperCore"]),
        // Headless assertion runner for the game logic.
        .executableTarget(name: "MinesweeperTests", dependencies: ["MinesweeperCore"]),
        // Offscreen PNG dump for visual verification without a window.
        .executableTarget(name: "MinesweeperPreview", dependencies: ["MinesweeperCore"]),
        // Renders the app icon at all macOS sizes into an .iconset.
        .executableTarget(name: "MinesweeperIcon", dependencies: ["MinesweeperCore"]),
    ]
)
