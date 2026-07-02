# PRD: Custom Difficulty Dialog + Resizable Window

## Problem Statement

Today the macOS Minesweeper (Swift/AppKit, `macos/`) only offers four fixed
board configurations (Beginner, Intermediate, Expert, and screen-derived
Nightmare) and a window that cannot be drag-resized. Players who want a board
size or mine density outside those four presets — e.g. a 20×20 board with 60
mines — have no way to get one, and cannot casually resize the window the way
most native macOS apps allow.

## Solution

1. Add a **Custom difficulty dialog** where the player enters width, height,
   and mine count, validated against safe bounds, and starts a new game at
   that size.
2. Make the game window **drag-resizable**, snapping to whole-cell increments
   and regrowing/shrinking the visible board at a fixed cell size — mirroring
   the fit-to-space approach Nightmare mode already uses — without ever
   stretching cells or silently changing the mine count.

Ship (1) first; (2) is separable and can be dropped if (1) alone satisfies
the need.

## User Stories

1. As a player, I want to open a "Custom…" difficulty option, so that I can play a board size the presets don't offer.
2. As a player, I want to enter width, height, and mine count in the Custom dialog, so that I control exactly how hard the game is.
3. As a player, I want invalid custom inputs (too few/many mines, board too small/large) rejected with a clear message, so that I can't create an unplayable or crashing board.
4. As a player, I want my custom board to always have a safe first click, so that starting a custom game feels fair like the classic presets.
5. As a player, I want the mine counter to still display correctly for custom games, so that the 3-digit LED display never overflows or misrenders.
6. As a player, I want selecting Custom to behave like selecting any other difficulty (start a fresh board), so that the interaction is consistent with existing presets.
7. As a player, I want to drag the edge or corner of the window to resize it, so that I can make the app bigger or smaller like any other native Mac app.
8. As a player, I want resizing the window to change how many cells are visible (growing/shrinking the board), not stretch the existing cells, so that the Win95 pixel art never looks distorted.
9. As a player, I want a resize to snap to whole cells, so that I never see a partial cell or ragged edge.
10. As a player, I want the window to enforce a sensible minimum size, so that I can't shrink it below a playable board (and can't hide the header/mine-counter/smiley chrome).
11. As a player, I want resizing the window to never change my current mine count or "difficulty" identity, so that difficulty stays owned exclusively by preset selection or the Custom dialog.
12. As a player, I want resizing mid-game to not lose or corrupt my current game state inconsistently with how difficulty switches already behave (confirm/restart semantics), so that behavior is predictable.
13. As a developer, I want custom board sizing to go through the existing `loadBoard()` rebuild path, so that no new state-transition code paths are introduced beyond what Nightmare mode already established.
14. As a developer, I want window-resize geometry math to be pure/testable (mirroring `nightmareDims`), so that sizing logic can be unit tested headlessly without AppKit.
15. As a player, I want Nightmare mode's existing fullscreen behavior to keep working unaffected by these changes, so that a new feature doesn't regress an existing one.

## Implementation Decisions

- **`Difficulty` enum gains a `.custom` case** (or an associated-value variant) carrying an explicit `BoardDims` supplied by the user, alongside the existing `beginner`/`intermediate`/`expert`/`nightmare` cases. `resolve(screenSize:)` returns the user-supplied `BoardDims` unchanged for `.custom`.
- **Validation lives in a pure, testable function** (same style as `nightmareDims` in `NightmareSizing.swift`), not inline in AppKit code:
  - width/height bounds: minimum ~8×8, maximum 30×24 (matching the historical Windows Minesweeper custom-dialog cap).
  - mine count bounds: minimum 1 (or a small positive floor), maximum `min(999, (width−1) × (height−1))` — the `(width−1)×(height−1)` ceiling reserves the classic safe first-click margin; 999 is the hard ceiling of the existing 3-digit LED mine counter.
  - Invalid input is rejected before a board is constructed; the dialog surfaces the specific violated bound rather than a generic error.
- **Custom dialog** is a new small AppKit sheet/modal (numeric fields for width/height/mines, Cancel/OK), triggered from a new "Custom…" item in the existing Difficulty submenu (`AppDelegate.swift` `buildMenu()`). On OK with valid input, it calls the same `loadBoard(_:)` path used by `selectPreset(_:)` today — no new board-construction code path.
- **Window resizing**: add `.resizable` to the `NSWindow` `styleMask` (`AppDelegate.swift:20`). Introduce `NSWindowDelegate` conformance on `AppDelegate` (currently only `NSApplicationDelegate`). Implement:
  - `windowWillResize(_:to:)` — snap the proposed size down to the nearest whole-cell increment using `Layout.defaultCell`/`defaultBorder`/`defaultHeader`, reusing the same fixed-cell-size fit math `nightmareDims` already established (generalize/extract that math to accept arbitrary available width/height rather than only screen size, so both Nightmare and interactive resize share one function).
  - `windowDidResize(_:)` — recompute rows/cols for the new content size at the fixed cell size, rebuild `BoardView`/`Board` via the existing rebuild pattern, preserving the current mine density (mines-per-cell ratio) or, per design decision, a fixed reasonable default — this exact behavior (does resize preserve density, or does it just show more/less of a board with the same mine count?) is flagged as an **open question** below and must be pinned down before implementation.
  - `contentMinSize` set to the minimum playable board's content size (from the 8×8 floor) plus header/border chrome, so AppKit clamps drags automatically without extra delegate math.
  - Window resize must **never** touch `mineCount`/difficulty identity in a way that conflicts with story 11 — resolving the open question above is required to keep this invariant unambiguous.
- **`SPEC.md` amendment**: lines 29–32 (repo root `SPEC.md`) currently list "user-entered custom board dimensions UI" as explicitly out of scope while carving Nightmare's non-user-entered sizing back in. This PRD requires updating that line to bring user-entered custom dimensions in scope, and to state the window-resize behavior explicitly (cell regrow, not stretch) since `SPEC.md` §6 currently only documents Nightmare's screen-derived sizing.

## Testing Decisions

- Prior art: `NightmareSizing.swift`'s `nightmareDims` is a pure function with no AppKit dependency, tested headlessly — this PRD's validation and resize-fit functions should follow the same pattern (pure `MinesweeperCore` functions, not embedded in `AppDelegate`/`BoardView`).
- **Unit test**: custom-dimensions validation function — boundary cases at min/max width/height, mine count at the `(width−1)×(height−1)` ceiling and one above it, mine count at 999 and one above it, and at least one clearly valid mid-range input.
- **Unit test**: the generalized fixed-cell-size fit function (extracted from `nightmareDims`) — given arbitrary available width/height, returns the correct whole-cell row/col count with no partial cells, and clamps to the same min/max bounds as the Custom dialog.
- **No AppKit/UI test** is required for the dialog itself or live window-drag behavior — consistent with this project's existing test coverage, which tests `MinesweeperCore` logic headlessly and leaves `AppKit`-layer code (views, delegates) untested by automated tests.

## Out of Scope

- Live mid-game resize that changes an in-progress board without a restart (both custom difficulty and window resize use confirm/restart semantics, matching existing preset-switch behavior).
- Preserving/replaying game state across a resize or difficulty change.
- Any window-resize behavior that changes mine count or difficulty identity as a side effect of dragging (that remains exclusively the Custom dialog's responsibility, pending the open question below).
- Persisting a user's last-used custom dimensions across app launches (no persistence exists anywhere in the app today).
- Any change to Nightmare mode's existing fullscreen-only sizing behavior.

## Further Notes

- **Open question requiring a decision before implementation**: when the window is drag-resized, should the mine count scale with the new cell count (preserving roughly the same mine density), or stay fixed at whatever the current difficulty's mine count was (risking an unplayably sparse or dense board at extreme sizes)? Nightmare mode's precedent is "recompute mines from density," which argues for scaling; but story 11 above argues resize should never touch difficulty/mine identity. Recommend resolving this by treating window-resize as **Nightmare-style** (density-preserving, recomputed) only when the *current* difficulty is Nightmare, and as a **fixed mine count, clamped board only** (extra cells added stay empty/inaccessible beyond the original board, or resize is simply disabled) for Beginner/Intermediate/Expert/Custom — this needs explicit user sign-off, it is a product decision, not an engineering one.
- Ranking from feature prioritization: build the Custom difficulty dialog first (high impact, low risk, zero design ambiguity); build/ship window resizing second, and only if the Custom dialog alone doesn't satisfy the original request.
- `SPEC.md` scope amendment is a prerequisite, not a side effect — flag it explicitly to whoever owns that document before `/feature-team` starts writing code.
