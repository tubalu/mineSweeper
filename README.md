# Windows 95 Minesweeper

A cross-platform implementation of the classic Windows 95 Minesweeper game in two flavors:
- **Python/pygame** — cross-platform, runs on macOS, Linux, Windows
- **Native Swift/AppKit** — macOS only, with a programmatically-generated Windows 95-style app icon

Both implementations follow the specification in [SPEC.md](SPEC.md) for exact gameplay logic and Win95 visuals.

## Quick Start

### Python (pygame) version

```bash
# First run (sets up venv and dependencies)
make run

# Or: test, clean
make test
make clean
```

The window displays the app icon (256px PNG) on macOS.

### macOS (Swift) version

```bash
cd macos

# Build and run (debug)
make run

# Build optimized app bundle with icon
make app

# Or: test, clean, rebuild icon only
make test
make clean
make icon
```

**Note:** Requires macOS 10.15+ and Command Line Tools (Xcode not needed).

## Features

### Gameplay
- **Classic Minesweeper rules:** random mine placement, adjacent mine counts, cascade reveals, flagging, chording, win/loss detection
- **Difficulty presets:** Beginner (9×9 / 10 mines), Intermediate (16×16 / 40 mines), Expert (16×30 / 99 mines), and Nightmare (screen-filling fullscreen, ~20.6% mine density; **Swift/AppKit macOS build only**)
- **Controls:** left-click to reveal, right-click to flag, middle-click or left+right to chord, press `R` or click smiley to restart, `Q` to quit; press `4` to enter Nightmare mode (macOS Swift build only), Esc to exit
- **First-click safety** (macOS Swift build only): mines are placed after your first click, ensuring the first click never loses

### Visual Style (Win95)
- **3-D beveled gray buttons** with highlight/shadow edges
- **Classic number colors** (1=blue, 2=green, 3=red, 4=navy, 5=maroon, 6=teal, 7=black, 8=gray)
- **LED-style** mine counter and timer
- **Smiley face** that reflects game state (playing 🙂 / lost 😵 / won 😎)
- **App icon** (macOS): programmatically generated gray tile with centered mine and red flag

### Icon (macOS/Swift only)
- Drawn in **Core Graphics** — no external art assets
- **AppIcon.icns** — embedded into Minesweeper.app via Info.plist
- **icon.png (256px)** — generated at repo root for pygame window (optional; loading failure is non-fatal)

## Testing

Both implementations include deterministic test suites covering the logic specification:

```bash
# Python: pytest
make test

# macOS: Swift unit tests
cd macos && make test
```

## Architecture

- **Game logic** (board state, reveal/cascade/flag/chord/win-loss) separated from UI rendering
- **Test coverage:** 80%+ on core logic (optional, recommended)

## Files

- `SPEC.md` — full implementation specification (language/framework agnostic)
- `mine1.py` — Python/pygame implementation
- `test_mine1.py` — pytest suite
- `macos/` — Swift/AppKit implementation and icon generator
- `Makefile` — root-level Python tasks
- `macos/Makefile` — Swift build, run, test, and icon generation
