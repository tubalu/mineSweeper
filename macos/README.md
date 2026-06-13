# Minesweeper — macOS (Swift/AppKit)

A native macOS implementation of Windows 95 Minesweeper using Swift and AppKit.

## Build Requirements

- **macOS 10.15** or later
- **Command Line Tools** (clang, swift, linker) — **Xcode is NOT required**
  ```bash
  xcode-select --install
  ```

## Quick Start

```bash
cd macos

# Build (debug) and run
make run

# Build optimized app + sign + open
make app

# Test
make test

# Clean build artifacts
make clean
```

## Tasks

| Command | Purpose |
|---------|---------|
| `make run` | Debug build; launch in window |
| `make build` | Release build (binary only, no app bundle) |
| `make app` | Release build + assemble **Minesweeper.app** (with icon + codesign + open) |
| `make icon` | Generate icon assets (AppIcon.icns + icon.png) |
| `make test` | Run headless logic test suite |
| `make preview` | Dump mid-game and game-over PNG screenshots |
| `make clean` | Remove build artifacts |

## App Icon

The app icon is **programmatically generated** using Core Graphics — no external art assets:

- **Style:** Windows 95-inspired beveled gray tile
- **Content:** centered mine sprite with a red flag
- **Generated sizes:** 16, 32, 64, 128, 256, 512, 1024 px (appended to AppIcon.iconset)
- **Files:**
  - `Sources/MinesweeperCore/IconArt.swift` — Core Graphics drawing + pixel-exact bitmap/PNG rendering
  - `Sources/MinesweeperIcon/main.swift` — executable that generates all icon sizes
  - `Sources/MinesweeperIcon/main.swift` — invoked by `make icon`

### Icon Embedding

The `make app` target:
1. Calls `make icon` to generate `AppIcon.icns`
2. Copies `AppIcon.icns` → `Minesweeper.app/Contents/Resources/AppIcon.icns`
3. Uses `CFBundleIconFile` in `Info.plist` to link the icon
4. Ad-hoc signs the bundle (so it can run without a developer certificate)

A side-effect of `make icon` is the generation of **icon.png** at the repo root, which the Python/pygame version loads as its window icon (non-fatal if missing).

## Project Structure

```
macos/
├── Makefile                          # Build tasks (run, app, icon, test, clean)
├── Package.swift                     # Swift package manifest
├── Info.plist                        # Bundle metadata (CFBundleIconFile, etc.)
├── build/                            # Ephemeral output dir (iconset, icns, app bundle)
├── .build/                           # Swift build cache
└── Sources/
    ├── Minesweeper/                  # Main app target
    │   ├── main.swift
    │   ├── AppDelegate.swift
    │   ├── GameViewController.swift
    │   ├── BoardView.swift
    │   └── ... (other UI/rendering)
    ├── MinesweeperCore/              # Shared game logic
    │   ├── Board.swift
    │   ├── Cell.swift
    │   └── IconArt.swift             # ← Icon generation (Core Graphics)
    ├── MinesweeperIcon/              # Icon generator CLI
    │   └── main.swift
    ├── MinesweeperTests/             # Test suite
    │   └── main.swift
    └── MinesweeperPreview/           # Screenshot dumper
        └── main.swift
```

## Dependencies

Minimal external dependencies — uses only Swift stdlib, AppKit (Apple framework), and Core Graphics.

## Troubleshooting

**"Could not find module or product named Minesweeper"**
```bash
swift build --product Minesweeper
```

**Build fails on Intel Mac**
- Ensure Command Line Tools are up-to-date:
  ```bash
  xcode-select --reset
  xcode-select --install
  ```

**Icon does not appear**
- Regenerate: `make icon`
- Check `Info.plist` contains `<key>CFBundleIconFile</key><string>AppIcon</string>`
- Force Finder to refresh: press Cmd+Option+Esc, select Finder, force quit, relaunch

**App signature invalid**
- The Makefile uses ad-hoc signing (requires no developer certificate). If you see a gatekeeper warning, either:
  - Approve in System Settings > General > Security & Privacy
  - Or re-run: `make clean && make app`
