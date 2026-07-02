# Research: Nightmare mode (fullscreen board) — Swift/AppKit build only

Date: 2026-07-01. Scope decided during research: Swift build only (`macos/`); fixed 30px cell,
board grows in cell count to fill the screen (no cell scaling).

## Market reality

- The de-facto tier above Expert is "Evil": 30x20 with 130 mines, ~21.7% density — harder via
  area, not density (minesweeper.org/evil; minesweeper.fandom.com/wiki/Evil_NG).
- Screen-filling implementations (Google Minesweeper fullscreen, infiniteminesweeper.net,
  1000mines.com) keep cell size constant and grow the grid — matching our decision.
- Playability ceiling: research shows a solvability phase transition above ~25% density
  (arXiv:2008.04116, arXiv:2506.01634); community ceiling is ~20–25%. Solvers win only ~41%
  of Expert games (github.com/DavidNHill/JSMinesweeper).
- First-click safety (mines placed after first click, ideally a 3x3 clear zone) is considered
  essential on large boards (minesweepergame.com/strategy/first-click.php).

**Implication:** Nightmare = Expert-density (~20.6%) applied to a screen-filling grid. Density
stays fixed; the board area supplies the nightmare.

## Findings (codebase + docs)

- Swift build is already parameterized: `Difficulty` enum + menu with shortcuts 1/2/3
  (`macos/Sources/Minesweeper/AppDelegate.swift:4-14`, `:49-85`), dynamic geometry in
  `Layout` (`macos/Sources/MinesweeperCore/Theme.swift:34-77`), and
  `Board(rows:cols:mineCount:)` accepts arbitrary sizes (`Board.swift:35`).
- `loadBoard(_:)` (`AppDelegate.swift:34-42`) already rebuilds the view and resizes/centers
  the window — Nightmare adds a fullscreen branch to this path.
- No fullscreen/resize/NSScreen code exists; window styleMask is fixed non-resizable
  (`AppDelegate.swift:24-25`).
- AppKit fullscreen: set `window.collectionBehavior.insert(.fullScreenPrimary)`, call
  `window.toggleFullScreen(nil)`; the transition is asynchronous — size the board from the
  final frame via `NSWindow.didEnterFullScreenNotification` (or `windowDidEnterFullScreen`
  delegate), not immediately after the call.
- Flood fill is iterative with an explicit stack (`Board.swift:122-134`) — safe at any size.
- Rendering: `BoardView.draw(_:)` ignores `dirtyRect` and repaints the whole board
  (`Renderer.swift:6-17`). Event-driven (needsDisplay), so acceptable at ~2–4k cells, but
  honoring `dirtyRect` (or per-cell `setNeedsDisplay(_:)`) is the cheap insurance.
- LED counters clamp at 3 digits (`Renderer.swift:163-166`). At 30px cells / 20% density even
  a 5K display yields ~756 mines (<999), so the cap holds — but clamp mines to 999 anyway.
- `SPEC.md` §6 defines only the three presets and the out-of-scope list excludes custom board
  dimensions — SPEC.md needs an update alongside the feature.

## Board math (fixed 30px cell)

usable = screen frame minus chrome:
`cols = (w − 2·border) / 30`, `rows = (h − header − 3·border) / 30`,
`mines = round(0.206 · rows · cols)` clamped to 999.
Example, 1512×982-pt MacBook display: ~49×29 = 1421 cells, ~293 mines.

## Trade-offs decided

1. **Dynamic dims from screen** (not a fixed preset) — resolution-independent.
2. **Native `toggleFullScreen`** (not zoomed window) — system Esc/green-button behavior free.
3. **Keep Win95 header chrome**; center grid, letterbox leftovers with FACE gray.
4. **Density = Expert's 20.6%**, per market/solvability evidence.

## Open questions

1. Does the Swift build have first-click safety? Not confirmed during recon — verify
   `Board.swift` mine placement; add 3x3-safe generation if absent (matters most at this size).
2. Exit behavior: leaving fullscreen (Esc) should restore the previous preset's windowed
   geometry — confirm desired UX (revert to last preset vs. stay Nightmare-windowed).
3. Menu item state while in fullscreen (disable resize-dependent items?).

## Recommendation

Proceed to build via `/feature-team` — see hand-off PRD.
