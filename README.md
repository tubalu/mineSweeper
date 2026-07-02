# Windows 95 Minesweeper

A native macOS implementation of the classic Windows 95 Minesweeper game, built
in Swift and AppKit, with a programmatically-generated Windows 95-style app
icon. Follows the specification in [SPEC.md](SPEC.md) for exact gameplay logic
and Win95 visuals.

## Build Requirements

- **macOS 12** or later
- **Command Line Tools** (clang, swift, linker) — **Xcode is NOT required**
  ```bash
  xcode-select --install
  ```

## Quick Start

```bash
# Build (debug) and run
make run

# Build optimized app bundle with icon
make app

# Or: test, clean, rebuild icon only
make test
make clean
make icon
```

## Features

### Gameplay
- **Classic Minesweeper rules:** random mine placement, adjacent mine counts, cascade reveals, flagging, chording, win/loss detection
- **Difficulty presets:** Beginner (9×9 / 10 mines), Intermediate (16×16 / 40 mines), Expert (16×30 / 99 mines), Nightmare (screen-filling fullscreen, ~20.6% mine density), and Custom (user-entered width/height/mine count)
- **Controls:** left-click to reveal, right-click to flag, middle-click or left+right to chord, press `R` or click smiley to restart, `Q` to quit; press `4` to enter Nightmare mode, Esc to exit
- **First-click safety:** mines are placed after your first click, ensuring the first click never loses
- **Resizable window:** drag-resize the window frame for any difficulty except Nightmare; the board snaps to whole cells at a fixed cell size (grid grows/shrinks, cells never stretch), rescaling mine count to the difficulty's density, and starts a fresh game, like switching difficulty

### Visual Style (Win95)
- **3-D beveled gray buttons** with highlight/shadow edges
- **Classic number colors** (1=blue, 2=green, 3=red, 4=navy, 5=maroon, 6=teal, 7=black, 8=gray)
- **LED-style** mine counter and timer
- **Smiley face** that reflects game state (playing 🙂 / lost 😵 / won 😎)
- **App icon:** programmatically generated gray tile with centered mine and red flag

### Icon
- Drawn in **Core Graphics** — no external art assets
- **AppIcon.icns** — embedded into Minesweeper.app via Info.plist
- **icon.png (256px)** — a standalone PNG generated alongside the iconset, kept as a general-purpose icon asset

## Testing

```bash
make test
```

## Architecture

- **Game logic** (board state, reveal/cascade/flag/chord/win-loss) separated from UI rendering, so it's testable headlessly with no AppKit dependency
- **Test coverage:** deterministic headless assertion suite covering the §9 logic cases in [SPEC.md](SPEC.md)

## CI / Downloads

Every push to `main` runs [`.github/workflows/build.yml`](.github/workflows/build.yml) on `macos-latest`: debug build, headless test suite, release build, then `make bundle` assembles and ad-hoc signs `Minesweeper.app`.

- **Every push:** the run uploads `Minesweeper-macOS` as a workflow artifact — download it from the run's Summary page under **Artifacts** (Actions tab).
- **Tagged release (`git tag vX.Y.Z && git push --tags`):** the same build is zipped and published as a [GitHub Release](../../releases) with a permanent download link.

## Project Structure

```
├── Makefile                          # Build tasks (run, build, bundle, app, icon, test, clean)
├── Package.swift                     # Swift package manifest
├── Info.plist                        # Bundle metadata (CFBundleIconFile, etc.)
├── build/                            # Ephemeral output dir (iconset, icns, app bundle)
├── .build/                           # Swift build cache
└── Sources/
    ├── Minesweeper/                  # Main app target (NSApplication, window, menu, views)
    ├── MinesweeperCore/              # Shared game logic + rendering (no AppKit-only state)
    ├── MinesweeperIcon/              # Icon generator CLI
    ├── MinesweeperTests/             # Headless test suite
    └── MinesweeperPreview/           # Screenshot dumper for visual verification
```

## Files

- `SPEC.md` — full implementation specification
- `Makefile` — build, run, test, and icon generation
- `Sources/` — Swift package source (see Project Structure above)
- `docs/research/` — design/research briefs for past features

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
