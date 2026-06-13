"""Windows 95-style Minesweeper built on pygame-ce.

Two responsibilities, two classes:
  * ``MinesweeperGame`` -- headless game logic (board, reveal, cascade, chord,
    flag, win/lose). No pygame dependency, fully unit-testable.
  * ``MinesweeperGUI``  -- rendering (Win95 3-D bevels, LED counters, smiley)
    and input (mouse reveal/flag/chord, R restart, Q quit).
"""

import sys
import random

import pygame

# --- BOARD CONFIGURATION ---------------------------------------------------
ROWS = 10
COLS = 10
MINES = 20

# --- GEOMETRY --------------------------------------------------------------
CELL_SIZE = 30
BORDER = 12          # outer frame thickness
HEADER_H = 52        # height of the counter/smiley/timer panel
GRID_X = BORDER
GRID_Y = HEADER_H + 2 * BORDER
WIDTH = COLS * CELL_SIZE + 2 * BORDER
HEIGHT = ROWS * CELL_SIZE + HEADER_H + 3 * BORDER
FPS = 60

# --- PALETTE (classic Win95 control colors) --------------------------------
FACE = (192, 192, 192)
HILITE = (255, 255, 255)
SHADOW = (128, 128, 128)
GRIDLINE = (160, 160, 160)
BLACK = (0, 0, 0)
LED_RED = (255, 0, 0)
EXPLODED = (255, 0, 0)
FLAG_RED = (200, 0, 0)
SMILEY_YELLOW = (255, 221, 0)

# Classic adjacency-number colors (index == count).
NUMBER_COLORS = {
    1: (0, 0, 255),
    2: (0, 128, 0),
    3: (255, 0, 0),
    4: (0, 0, 128),
    5: (128, 0, 0),
    6: (0, 128, 128),
    7: (0, 0, 0),
    8: (128, 128, 128),
}

# --- CELL STATES -----------------------------------------------------------
COVERED = 0
REVEALED = 1
FLAGGED = 2


# --- GAME LOGIC (headless, testable) ---------------------------------------
class MinesweeperGame:
    def __init__(self, rows: int, cols: int, mines: int) -> None:
        self.rows = rows
        self.cols = cols
        self.mines = mines
        self.reset()

    # -- board lifecycle ----------------------------------------------------
    def reset(self) -> None:
        """Rebuild a fresh board with newly randomized mines."""
        self.is_mine = [[False] * self.cols for _ in range(self.rows)]
        self.counts = [[0] * self.cols for _ in range(self.rows)]
        self.state = [[COVERED] * self.cols for _ in range(self.rows)]
        self.game_over = False
        self.win = False
        self.detonated: tuple[int, int] | None = None
        self._place_random_mines()
        self._compute_counts()

    def set_mines(self, coords: set[tuple[int, int]]) -> None:
        """Deterministically place mines at ``coords`` (used by tests)."""
        self.is_mine = [[False] * self.cols for _ in range(self.rows)]
        for r, c in coords:
            self.is_mine[r][c] = True
        self.mines = len(coords)
        self.state = [[COVERED] * self.cols for _ in range(self.rows)]
        self.game_over = False
        self.win = False
        self.detonated = None
        self._compute_counts()

    def _place_random_mines(self) -> None:
        target = min(self.mines, self.rows * self.cols)
        locations: set[tuple[int, int]] = set()
        while len(locations) < target:
            locations.add(
                (random.randint(0, self.rows - 1), random.randint(0, self.cols - 1))
            )
        for r, c in locations:
            self.is_mine[r][c] = True

    def _neighbors(self, r: int, c: int):
        for dr in (-1, 0, 1):
            for dc in (-1, 0, 1):
                if dr == 0 and dc == 0:
                    continue
                nr, nc = r + dr, c + dc
                if 0 <= nr < self.rows and 0 <= nc < self.cols:
                    yield nr, nc

    def _compute_counts(self) -> None:
        for r in range(self.rows):
            for c in range(self.cols):
                if self.is_mine[r][c]:
                    continue
                self.counts[r][c] = sum(
                    1 for nr, nc in self._neighbors(r, c) if self.is_mine[nr][nc]
                )

    # -- player actions -----------------------------------------------------
    def reveal_cell(self, r: int, c: int) -> None:
        if self.game_over or self.state[r][c] != COVERED:
            return
        if self.is_mine[r][c]:
            self.state[r][c] = REVEALED
            self.detonated = (r, c)
            self.game_over = True
            self.win = False
            return
        self._flood(r, c)
        self._check_win()

    def _flood(self, r: int, c: int) -> None:
        """Iterative flood-fill: open the cell and, for any zero, its whole
        contiguous region plus the surrounding numbered border."""
        stack = [(r, c)]
        while stack:
            cr, cc = stack.pop()
            if self.state[cr][cc] != COVERED or self.is_mine[cr][cc]:
                continue
            self.state[cr][cc] = REVEALED
            if self.counts[cr][cc] == 0:
                for nr, nc in self._neighbors(cr, cc):
                    if self.state[nr][nc] == COVERED and not self.is_mine[nr][nc]:
                        stack.append((nr, nc))

    def toggle_flag(self, r: int, c: int) -> bool:
        if self.game_over:
            return False
        if self.state[r][c] == COVERED:
            self.state[r][c] = FLAGGED
            return True
        if self.state[r][c] == FLAGGED:
            self.state[r][c] = COVERED
            return True
        return False  # cannot flag a revealed cell

    def chord_cell(self, r: int, c: int) -> None:
        """Reveal all unflagged neighbors of a revealed number, but only when
        its adjacent flag count already equals the number (classic chording)."""
        if self.game_over or self.state[r][c] != REVEALED or self.counts[r][c] == 0:
            return
        flags = sum(
            1 for nr, nc in self._neighbors(r, c) if self.state[nr][nc] == FLAGGED
        )
        if flags != self.counts[r][c]:
            return
        for nr, nc in self._neighbors(r, c):
            if self.state[nr][nc] == COVERED:
                self.reveal_cell(nr, nc)
                if self.game_over:
                    return

    # -- queries ------------------------------------------------------------
    def mines_remaining(self) -> int:
        flags = sum(
            1
            for r in range(self.rows)
            for c in range(self.cols)
            if self.state[r][c] == FLAGGED
        )
        return self.mines - flags

    def _check_win(self) -> None:
        for r in range(self.rows):
            for c in range(self.cols):
                if not self.is_mine[r][c] and self.state[r][c] != REVEALED:
                    return
        self.win = True
        self.game_over = True


# --- RENDERING + INPUT -----------------------------------------------------
class MinesweeperGUI:
    def __init__(self, screen: pygame.Surface, game: MinesweeperGame) -> None:
        self.screen = screen
        self.game = game
        self.chording = False         # both buttons currently held (chord gesture)
        self.chord_armed = False      # chord in progress; suppress stray reveal/flag
        self.elapsed_ms = 0
        self.timer_running = False

        self.num_font = pygame.font.Font(None, int(CELL_SIZE * 0.95))
        self.num_font.set_bold(True)
        self.led_font = pygame.font.Font(None, int(HEADER_H * 0.85))
        self.led_font.set_bold(True)

    # -- bevel helper (the core Win95 look) ---------------------------------
    @staticmethod
    def _bevel(surface, rect, raised=True, width=3):
        """Draw a chunky 3-D bevel. Raised = light top/left, dark bottom/right;
        sunken = inverted."""
        x, y, w, h = rect
        light = HILITE if raised else SHADOW
        dark = SHADOW if raised else HILITE
        pygame.draw.rect(surface, FACE, rect)
        pygame.draw.polygon(
            surface, light,
            [(x, y), (x + w, y), (x + w - width, y + width),
             (x + width, y + width), (x + width, y + h - width), (x, y + h)],
        )
        pygame.draw.polygon(
            surface, dark,
            [(x + w, y), (x + w, y + h), (x, y + h),
             (x + width, y + h - width), (x + w - width, y + h - width),
             (x + w - width, y + width)],
        )

    # -- coordinate mapping -------------------------------------------------
    @staticmethod
    def cell_at(pos):
        x, y = pos
        if not (GRID_X <= x < GRID_X + COLS * CELL_SIZE
                and GRID_Y <= y < GRID_Y + ROWS * CELL_SIZE):
            return None
        return ((y - GRID_Y) // CELL_SIZE, (x - GRID_X) // CELL_SIZE)

    @staticmethod
    def _smiley_rect():
        size = HEADER_H - 12
        return pygame.Rect(WIDTH // 2 - size // 2, BORDER + 6, size, size)

    # -- cell drawing -------------------------------------------------------
    def _cell_rect(self, r, c):
        return pygame.Rect(
            GRID_X + c * CELL_SIZE, GRID_Y + r * CELL_SIZE, CELL_SIZE, CELL_SIZE
        )

    def _draw_flat(self, rect):
        pygame.draw.rect(self.screen, FACE, rect)
        pygame.draw.line(self.screen, GRIDLINE, rect.topleft, rect.topright)
        pygame.draw.line(self.screen, GRIDLINE, rect.topleft, rect.bottomleft)

    def _draw_number(self, rect, value):
        color = NUMBER_COLORS.get(value)
        if not color:
            return
        text = self.num_font.render(str(value), True, color)
        self.screen.blit(text, text.get_rect(center=rect.center))

    def _draw_flag(self, rect):
        cx, cy = rect.center
        pole_x = cx + 2
        pygame.draw.line(self.screen, BLACK, (pole_x, cy - 8), (pole_x, cy + 8), 2)
        pygame.draw.line(self.screen, BLACK,
                         (cx - 7, cy + 8), (cx + 8, cy + 8), 3)  # base
        pygame.draw.polygon(self.screen, FLAG_RED,
                            [(pole_x, cy - 8), (pole_x, cy), (cx - 6, cy - 4)])

    def _draw_mine(self, rect, exploded=False):
        if exploded:
            pygame.draw.rect(self.screen, EXPLODED, rect)
        cx, cy = rect.center
        rad = CELL_SIZE // 4
        for dx, dy in ((rad + 2, 0), (0, rad + 2)):
            pygame.draw.line(self.screen, BLACK, (cx - dx, cy - dy),
                             (cx + dx, cy + dy), 2)
        pygame.draw.circle(self.screen, BLACK, (cx, cy), rad)
        pygame.draw.circle(self.screen, HILITE, (cx - rad // 3, cy - rad // 3), 2)

    def _draw_wrong_flag(self, rect):
        self._draw_mine(rect)
        cx, cy = rect.center
        d = CELL_SIZE // 3
        pygame.draw.line(self.screen, EXPLODED, (cx - d, cy - d), (cx + d, cy + d), 3)
        pygame.draw.line(self.screen, EXPLODED, (cx + d, cy - d), (cx - d, cy + d), 3)

    def draw_cell(self, r, c, pressed=False):
        rect = self._cell_rect(r, c)
        state = self.game.state[r][c]
        over = self.game.game_over and not self.game.win
        is_mine = self.game.is_mine[r][c]

        if state == REVEALED:
            self._draw_flat(rect)
            if is_mine:
                self._draw_mine(rect, exploded=self.game.detonated == (r, c))
            else:
                self._draw_number(rect, self.game.counts[r][c])
        elif state == FLAGGED:
            if over and not is_mine:
                self._draw_flat(rect)
                self._draw_wrong_flag(rect)
            else:
                self._bevel(self.screen, rect, raised=True)
                self._draw_flag(rect)
        else:  # COVERED
            if over and is_mine:
                self._draw_flat(rect)
                self._draw_mine(rect)
            elif pressed:
                self._draw_flat(rect)
            else:
                self._bevel(self.screen, rect, raised=True)

    def _pressed_preview(self):
        """Cells to render sunken while a button is held: the single hovered
        cell for a left-press, or the hovered number's neighbors while chording
        (holding left+right)."""
        if self.game.game_over:
            return frozenset()
        hover = self.cell_at(pygame.mouse.get_pos())
        if hover is None:
            return frozenset()
        buttons = pygame.mouse.get_pressed()
        r, c = hover
        if buttons[0] and buttons[2]:
            return frozenset({hover, *self.game._neighbors(r, c)})
        if buttons[0]:
            return frozenset({hover})
        return frozenset()

    def draw_board(self):
        pressed_cells = self._pressed_preview()
        for r in range(self.game.rows):
            for c in range(self.game.cols):
                self.draw_cell(r, c, pressed=(r, c) in pressed_cells)

    # -- header (counter / smiley / timer) ----------------------------------
    @staticmethod
    def _fmt3(value):
        if value < 0:
            return f"-{min(abs(value), 99):02d}"
        return f"{min(value, 999):03d}"

    def _draw_led(self, rect, text):
        self._bevel(self.screen, rect, raised=False, width=2)
        pygame.draw.rect(self.screen, BLACK, rect.inflate(-6, -6))
        surf = self.led_font.render(text, True, LED_RED)
        self.screen.blit(surf, surf.get_rect(center=rect.center))

    def _draw_smiley(self):
        rect = self._smiley_rect()
        self._bevel(self.screen, rect, raised=True)
        cx, cy = rect.center
        rad = rect.width // 2 - 5
        pygame.draw.circle(self.screen, SMILEY_YELLOW, (cx, cy), rad)
        pygame.draw.circle(self.screen, BLACK, (cx, cy), rad, 1)
        ex, ey = rad // 2, rad // 3

        if self.game.win:  # cool sunglasses
            pygame.draw.rect(self.screen, BLACK, (cx - ex - 3, cy - ey, 6, 4))
            pygame.draw.rect(self.screen, BLACK, (cx + ex - 3, cy - ey, 6, 4))
            pygame.draw.arc(self.screen, BLACK,
                            (cx - ex, cy, 2 * ex, ey + 4), 3.6, 5.8, 2)
        elif self.game.game_over:  # dead: X eyes + frown
            for sx in (-ex, ex):
                bx, by = cx + sx, cy - ey
                pygame.draw.line(self.screen, BLACK, (bx - 3, by - 3), (bx + 3, by + 3), 2)
                pygame.draw.line(self.screen, BLACK, (bx + 3, by - 3), (bx - 3, by + 3), 2)
            pygame.draw.arc(self.screen, BLACK,
                            (cx - ex, cy + 2, 2 * ex, ey + 4), 0.5, 2.6, 2)
        else:  # alive: smile
            pygame.draw.circle(self.screen, BLACK, (cx - ex, cy - ey), 2)
            pygame.draw.circle(self.screen, BLACK, (cx + ex, cy - ey), 2)
            pygame.draw.arc(self.screen, BLACK,
                            (cx - ex, cy, 2 * ex, ey + 4), 3.6, 5.8, 2)

    def draw_header(self):
        panel = pygame.Rect(BORDER, BORDER, WIDTH - 2 * BORDER, HEADER_H)
        self._bevel(self.screen, panel, raised=False, width=2)
        led_w, led_h = 56, HEADER_H - 16
        self._draw_led(
            pygame.Rect(BORDER + 8, BORDER + 8, led_w, led_h),
            self._fmt3(self.game.mines_remaining()),
        )
        self._draw_led(
            pygame.Rect(WIDTH - BORDER - 8 - led_w, BORDER + 8, led_w, led_h),
            self._fmt3(self.elapsed_ms // 1000),
        )
        self._draw_smiley()

    # -- input --------------------------------------------------------------
    def _restart(self):
        self.game.reset()
        self.elapsed_ms = 0
        self.timer_running = False

    def _start_timer(self):
        if not self.game.game_over:
            self.timer_running = True

    def handle_event(self, event):
        if event.type == pygame.MOUSEBUTTONDOWN:
            if event.button == 1 and self._smiley_rect().collidepoint(event.pos):
                self._restart()
                return None
            pressed = pygame.mouse.get_pressed()
            if (event.button == 1 and pressed[2]) or (event.button == 3 and pressed[0]):
                # both buttons now held: arm the chord, fire it on release so the
                # neighbors can show their pressed state during the hold
                self.chording = True
                self.chord_armed = True
            elif event.button == 2:                 # middle => immediate chord
                self._chord(self.cell_at(event.pos))
                self.chord_armed = True
            elif event.button == 3:                 # right => flag
                cell = self.cell_at(event.pos)
                if cell:
                    self.game.toggle_flag(*cell)

        elif event.type == pygame.MOUSEBUTTONUP:
            if self.chording:
                self._chord(self.cell_at(event.pos))  # first release completes chord
                self.chording = False
            elif (event.button == 1 and not self.chord_armed
                  and not self.game.game_over):
                cell = self.cell_at(event.pos)
                if cell:
                    self._start_timer()
                    self.game.reveal_cell(*cell)
            if not any(pygame.mouse.get_pressed()):
                self.chord_armed = False

        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_q:
                return "QUIT"
            if event.key == pygame.K_r:
                self._restart()
        return None

    def _chord(self, cell):
        if cell and not self.game.game_over:
            self._start_timer()
            self.game.chord_cell(*cell)

    # -- main loop ----------------------------------------------------------
    def run(self):
        clock = pygame.time.Clock()
        while True:
            dt = clock.tick(FPS)
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    pygame.quit()
                    sys.exit()
                if self.handle_event(event) == "QUIT":
                    pygame.quit()
                    sys.exit()

            if self.timer_running and not self.game.game_over:
                self.elapsed_ms = min(self.elapsed_ms + dt, 999_000)
            elif self.game.game_over:
                self.timer_running = False

            self.screen.fill(FACE)
            self.draw_header()
            self.draw_board()
            pygame.display.flip()


# --- EXECUTION -------------------------------------------------------------
def main() -> None:
    pygame.init()
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("Win95 Minesweeper")
    game = MinesweeperGame(rows=ROWS, cols=COLS, mines=MINES)
    MinesweeperGUI(screen, game).run()


if __name__ == "__main__":
    main()
