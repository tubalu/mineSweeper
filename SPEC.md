# Windows 95 Minesweeper — Implementation Specification

A self-contained, language- and framework-agnostic specification for building a
Windows 95-style Minesweeper game. It is written so that an independent
implementer (human or AI) can reproduce the game from scratch, and so that the
result can be **objectively compared** against this spec.

> **How to use this for benchmarking:** Hand this file to a tool with a prompt
> like *"Implement this specification."* Then evaluate the output against the
> **Acceptance Criteria** (§8) and **Reference Test Cases** (§9). The test cases
> are deterministic, so any correct implementation must pass them regardless of
> language.

You may use **any** language, GUI framework, and rendering approach. Concrete
pixel sizes and colors in §5 are provided so independent results look alike and
can be compared side-by-side; treat them as the intended target.

---

## 1. Goal & Scope

Build a single-player Minesweeper game with the classic Windows 95 look and
feel: a grid of chunky 3-D gray buttons, a status header with a mine counter, a
clickable smiley reset button, and an elapsed-time counter.

**In scope:** the full single-player game, mouse + keyboard input, the Win95
visual style, restart, difficulty presets, a user-entered Custom difficulty
(§6), and a resizable window frame (§6) on the macOS/Swift build.

**Out of scope (do NOT implement):** networking, accounts, high-score
persistence, sound, animations beyond the button press effect, themes/skins,
persisting a user's last-used custom dimensions across launches, and any
mid-game resize that preserves in-progress board state (resize is
confirm/restart, like switching difficulty).

---

## 2. Core Game Rules (Functional)

1. **Board.** A rectangular grid of `rows × cols` cells with a fixed number of
   hidden mines, `mineCount`.
2. **Mine placement.** Mines are placed at distinct random cells at board
   creation. (First-click safety is **not** required — the first reveal may hit
   a mine.)
3. **Adjacency counts.** Every non-mine cell has a number 0–8: the count of
   mines in its up-to-8 neighboring cells (orthogonal + diagonal).
4. **Cell lifecycle.** Each cell is in exactly one state: `covered`,
   `revealed`, or `flagged`. All cells start `covered`. **Mines are not visible
   until the game ends** (a board fresh from setup shows no mines).
5. **Reveal.**
   - Revealing a covered mine → **loss** (see §2.8).
   - Revealing a covered non-mine → it becomes `revealed`.
   - If the revealed cell's count is **0**, perform a **flood fill** (§2.6).
   - Revealing a `revealed` or `flagged` cell does nothing.
6. **Flood fill (cascade).** When a `0` cell is revealed, recursively/iteratively
   reveal all contiguous `0` cells **and the numbered border surrounding that
   region**. Concretely: reveal the cell; if its count is 0, enqueue every
   covered non-mine neighbor; repeat. Numbered cells reached this way are
   revealed but do not expand further.
7. **Flagging.** The player can toggle a flag on a `covered` cell
   (`covered → flagged → covered`). A `revealed` cell cannot be flagged. Flags
   mark suspected mines and block reveal/chord from opening that cell.
8. **Loss.** Revealing a mine ends the game: record which mine was detonated,
   and reveal **all** mines. On loss, any flag placed on a non-mine cell is
   shown as a mistaken flag (see §5).
9. **Win.** The game is won when **every non-mine cell is revealed** (flags are
   irrelevant to winning). Reaching this state ends the game.
10. **Chording.** Acting on an already-`revealed` numbered cell whose number of
    adjacent flags **equals** its count reveals all of its remaining (covered,
    unflagged) neighbors at once. If a flag was wrong, this can reveal a mine and
    lose. If the adjacent flag count does not equal the number, chording does
    nothing. Chording on a covered cell or a `0` cell does nothing.
11. **Restart.** The player can start a fresh game (new random board, reset
    timer) at any time without relaunching the program.

A critical modeling note: **distinguish "is a mine" from "adjacency count".** Do
not encode a mine as count value `1`, or a safe cell with one neighboring mine
becomes indistinguishable from a mine.

---

## 3. Controls (Input)

| Action | Input |
|---|---|
| Reveal a cell | Left-click |
| Toggle flag | Right-click |
| Chord (reveal neighbors of a satisfied number) | Middle-click, **or** press left+right together |
| Restart game | Click the smiley, **or** press `R` |
| Quit | `Q` (or the platform-native quit) |

**Pressed feedback (required):** While the left button is held over a covered
cell, that cell must render in a "pressed" (sunken/depressed) state, returning
to raised on release — the classic tactile button feel. While **chording**
(both buttons held over a number), the number's covered, unflagged neighbors all
show the pressed state. Flagged cells never show the pressed state.

**Chord timing (required):** A chord must resolve on button **release**, not on
press, so the pressed-neighbors preview is visible during the hold and the
player can cancel by moving away before releasing.

**Cursor → grid mapping (required):** Every click must map the pixel position to
the correct `(row, col)`, accounting for the header height and any border/margin
offset. Clicks outside the grid do nothing.

---

## 4. Status Header (Required)

A panel above the grid showing, left to right:

1. **Mine counter** — a 3-digit, red-on-black, LED-style readout of
   `mineCount − (number of flags placed)`. It may go negative (display e.g.
   `-01`); clamp the magnitude to 3 characters.
2. **Smiley reset button** — centered, clickable; restarts the game. Its face
   reflects game state:
   - Playing → smiling 🙂
   - Loss → dead (e.g. X eyes + frown) 😵
   - Win → cool / sunglasses 😎
3. **Timer** — a 3-digit, red-on-black, LED-style elapsed-seconds counter. It
   starts on the first reveal/chord, stops when the game ends, and caps at 999.

---

## 5. Visual Style — Windows 95 (Target Appearance)

The signature look is **chunky 3-D beveled gray controls**. Recommended values
(use these so results are comparable):

**Geometry**
- Cell size: `30 × 30` px.
- Outer border/margin: `12` px on all sides.
- Header height: `52` px, separated from the grid by the border.
- Window/content size: `cols*30 + 2*12` wide, `rows*30 + 52 + 3*12` tall.

**Palette (sRGB)**
| Role | RGB |
|---|---|
| Face (gray) | 192, 192, 192 |
| Highlight (raised top/left, sunken bottom/right) | 255, 255, 255 |
| Shadow (raised bottom/right, sunken top/left) | 128, 128, 128 |
| Revealed gridline | 160, 160, 160 |
| Black (mines, text, outlines) | 0, 0, 0 |
| LED digits | 255, 0, 0 |
| Exploded-mine background | 255, 0, 0 |
| Smiley face | 255, 221, 0 |

**Bevels.** A *raised* button: light edges on top+left, dark edges on
bottom+right (≈3 px thick), gray face. A *sunken* element (revealed cell well,
header well, LED frames, pressed button): the inverse. This bevel is the core of
the aesthetic — implement it as a reusable primitive.

**Cell rendering by state**
- **Covered:** raised gray button. (Pressed: drawn flat/sunken.)
- **Revealed, count 0:** flat gray cell, empty.
- **Revealed, count 1–8:** flat gray cell with the centered, bold number in its
  classic color (below).
- **Flagged:** raised button with a small flag glyph (red pennant on a black
  pole/base).
- **Mine (after loss):** flat cell with a black round mine (circle + spokes +
  small highlight). The **detonated** mine sits on a red background.
- **Mistaken flag (after loss):** a mine glyph with a red ✗ through it (a flag
  on a cell that had no mine).

**Classic number colors (count → color, sRGB)**
`1`=blue (0,0,255), `2`=green (0,128,0), `3`=red (255,0,0), `4`=navy (0,0,128),
`5`=maroon (128,0,0), `6`=teal (0,128,128), `7`=black (0,0,0), `8`=gray
(128,128,128).

---

## 6. Difficulty & Menu (Required)

Provide selectable difficulty presets that rebuild the board (and resize the
window to fit):

| Preset | rows × cols | mines |
|---|---|---|
| Beginner | 9 × 9 | 10 |
| Intermediate | 16 × 16 | 40 |
| Expert | 16 × 30 | 99 |
| Nightmare | screen-derived | ~20.6% density |
| Custom | 8–30 × 8–24, user-entered | user-entered, ≤ min(999, (w−1)(h−1)) |

**Nightmare** (macOS/Swift build only) enters native fullscreen and sizes the
board to fill the active display at the same fixed cell size as every other
preset (cells are never scaled — the grid grows instead). Dimensions are
computed from the screen size at selection time: `cols = (screenWidth −
2·border) / cell`, `rows = (screenHeight − header − 3·border) / cell`, `mines
= round(0.206 · rows · cols)` clamped to 999 (the LED display is 3 digits).
Exiting fullscreen (Esc or the window's fullscreen control) returns to the
difficulty that was active before Nightmare was selected.

**Custom** (macOS/Swift build only) prompts for width, height, and mine
count. Width/height must each fall within 8–30 (width) and 8–24 (height);
mine count must be between 1 and `min(999, (width−1)·(height−1))` — the
`(width−1)(height−1)` term reserves a safe first click, and 999 is the LED
counter's hard cap. Invalid input is rejected with the specific bound
violated (not a generic error), and the input dialog stays open for
correction. Selecting Custom starts a fresh game, like any preset.

**Resizable window** (macOS/Swift build only): the window frame can be
drag-resized like any native app, for every difficulty except Nightmare
(which is fullscreen-only and unaffected). Resizing snaps to whole cells at
the same fixed cell size as every preset — the grid regrows or shrinks in
cell count, cells are never stretched, and no partial cell is ever shown. The
window cannot be dragged smaller than an 8×8 board plus chrome. Resizing
keeps the current mine count fixed unless the new board is too small to
safely hold it, in which case mines are clamped down to the largest count
that still satisfies the `(cols−1)(rows−1)` safe-first-click ceiling; resize
never changes which difficulty/preset is active. Resizing starts a fresh
game, like any preset switch — in-progress board state is not preserved
across a resize.

If the platform has a native menu/command system, expose: **New Game**, the
**Difficulty** presets (including **Custom…**), and **Quit**. The default
difficulty is Beginner.

---

## 7. Architecture Guidance (Recommended, not graded)

Separate **game logic** (board state, reveal/cascade/flag/chord/win-loss) from
**rendering and input**. The logic layer should have no dependency on the GUI
framework, which makes it unit-testable headlessly. The drawing layer should be,
as much as possible, a function of game state. These are recommendations; only
observable behavior (§8–§9) is graded.

---

## 8. Acceptance Criteria (Checklist)

A correct implementation must satisfy ALL of:

**Logic**
- [ ] Random, distinct mine placement of exactly `mineCount` mines.
- [ ] Correct 0–8 adjacency counts.
- [ ] A fresh board shows **no** revealed/visible mines.
- [ ] Left-click reveals; revealing a 0 cascades and also reveals the numbered border.
- [ ] Revealing a mine loses and reveals all mines (detonated one marked).
- [ ] Win is detected exactly when all non-mine cells are revealed.
- [ ] Right-click toggles flags only on covered cells; flags block reveal.
- [ ] Chording works only when adjacent flag count equals the number; wrong flags can lose.
- [ ] Restart produces a fresh, fully-covered board and resets the timer.

**UI / UX**
- [ ] Chunky Win95 bevels: raised covered buttons, sunken/flat revealed cells.
- [ ] Header with LED mine counter, state-reflecting clickable smiley, LED timer.
- [ ] Distinct visuals for covered / revealed-number / flagged / mine / mistaken-flag.
- [ ] Pressed (sunken) feedback while holding left, including chord neighbor preview.
- [ ] Classic gray palette and number colors.

**Input**
- [ ] Accurate pixel→cell mapping accounting for header/border offset.
- [ ] Mouse reveal/flag/chord, smiley/`R` restart, difficulty switching.
- [ ] Chord resolves on release.

---

## 9. Reference Test Cases (Deterministic)

These let you verify any implementation's logic regardless of language. They use
a **3×3 board with a single mine at row 0, col 0** (top-left). With that mine,
the adjacency counts are:

```
     col0 col1 col2
row0  [M]   1    0
row1   1    1    0
row2   0    0    0
```

(Coordinates are `(row, col)`, 0-indexed.)

| # | Setup → Action | Expected result |
|---|---|---|
| 1 | Build the board above | `(0,1)=1, (1,0)=1, (1,1)=1`; `(0,2)=(2,2)=0`; `(0,0)` is a mine |
| 2 | Fresh 10×10 / 20-mine board | every cell is `covered` (no mine visible) |
| 3 | Reveal `(0,0)` | game lost; detonated = `(0,0)`; not won |
| 4 | Reveal `(2,2)` (a 0) | cascade reveals all safe cells including `(0,1)` and `(1,1)` → **win** |
| 5 | 3×3 with **0 mines**, reveal `(1,1)` | all 9 cells revealed → **win** |
| 6 | Flag `(1,1)`, then reveal `(1,1)` | stays `flagged` (flag blocks reveal) |
| 7 | Toggle flag on `(0,1)` twice | `flagged` then back to `covered` |
| 8 | Reveal `(1,1)`, then try to flag `(1,1)` | flag rejected; stays `revealed` |
| 9 | 1-mine board: mines remaining before/after flagging `(0,1)` | `1` then `0` |
| 10 | Reveal `(1,1)`, flag `(0,0)` (the mine), chord `(1,1)` | no detonation; safe neighbors open → **win** |
| 11 | Reveal `(1,1)`, flag `(0,1)` (wrong), chord `(1,1)` | reveals the mine → **loss** |
| 12 | Reveal `(1,1)` with no flags, chord `(1,1)` | nothing happens (flag count ≠ 1) |
| 13 | Chord `(1,1)` while still covered | nothing happens |
| 14 | Lose, then restart | fresh board: all covered, not over, not won, correct mine count |

**Visual acceptance** (manual): a mid-game screenshot should show raised gray
buttons, flat numbered cells in classic colors, red LED counters, a smiling
face, and flag glyphs. A post-loss screenshot should show all mines, the
detonated one on red, mistaken flags X'd, and a dead face.

---

## 10. Deliverables

1. A runnable program that launches a playable window.
2. Clear instructions to build/run it.
3. (Recommended) An automated test suite covering the §9 logic cases.
4. (Optional) An app icon that reflects the Windows 95 aesthetic.
