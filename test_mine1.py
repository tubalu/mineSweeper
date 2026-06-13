"""Logic tests for MinesweeperGame.

These exercise only the headless game logic (no pygame display), using
``set_mines`` to build deterministic boards instead of random placement.
"""

from mine1 import MinesweeperGame, COVERED, REVEALED, FLAGGED


def _game_with_mine_at_origin() -> MinesweeperGame:
    """3x3 board with a single mine at (0, 0). Adjacency counts:

        M 1 0
        1 1 0
        0 0 0
    """
    game = MinesweeperGame(rows=3, cols=3, mines=0)
    game.set_mines({(0, 0)})
    return game


# --- board setup -----------------------------------------------------------

def test_adjacency_counts_around_single_mine():
    game = _game_with_mine_at_origin()
    assert game.is_mine[0][0] is True
    assert game.counts[0][1] == 1
    assert game.counts[1][0] == 1
    assert game.counts[1][1] == 1
    assert game.counts[0][2] == 0
    assert game.counts[2][2] == 0


def test_mines_hidden_until_revealed():
    """Regression: mines must NOT be pre-revealed at board setup (Bug 1)."""
    game = MinesweeperGame(rows=10, cols=10, mines=20)
    assert all(
        game.state[r][c] == COVERED
        for r in range(game.rows)
        for c in range(game.cols)
    )


# --- reveal & cascade ------------------------------------------------------

def test_reveal_mine_loses_and_records_detonation():
    game = _game_with_mine_at_origin()
    game.reveal_cell(0, 0)
    assert game.game_over is True
    assert game.win is False
    assert game.detonated == (0, 0)


def test_cascade_reveals_numbered_border():
    """Flood-fill from a zero must reveal the surrounding numbered ring."""
    game = _game_with_mine_at_origin()
    game.reveal_cell(2, 2)  # a zero cell, far corner
    # Every safe cell should now be revealed (full clear => win).
    assert game.state[0][1] == REVEALED  # a numbered border cell
    assert game.state[1][1] == REVEALED  # the "1" diagonal to the mine
    assert game.win is True


def test_no_mines_first_reveal_clears_and_wins():
    game = MinesweeperGame(rows=3, cols=3, mines=0)
    game.reveal_cell(1, 1)
    assert all(
        game.state[r][c] == REVEALED for r in range(3) for c in range(3)
    )
    assert game.win is True


def test_revealing_flagged_or_revealed_cell_is_noop():
    game = _game_with_mine_at_origin()
    game.toggle_flag(1, 1)
    game.reveal_cell(1, 1)
    assert game.state[1][1] == FLAGGED  # flag protects against reveal


# --- flagging --------------------------------------------------------------

def test_flag_toggles_on_covered_cell():
    game = _game_with_mine_at_origin()
    assert game.toggle_flag(0, 1) is True
    assert game.state[0][1] == FLAGGED
    assert game.toggle_flag(0, 1) is True
    assert game.state[0][1] == COVERED


def test_cannot_flag_revealed_cell():
    game = _game_with_mine_at_origin()
    game.reveal_cell(1, 1)
    assert game.toggle_flag(1, 1) is False
    assert game.state[1][1] == REVEALED


def test_mines_remaining_counts_down_with_flags():
    game = _game_with_mine_at_origin()  # 1 mine
    assert game.mines_remaining() == 1
    game.toggle_flag(0, 1)
    assert game.mines_remaining() == 0


# --- chording --------------------------------------------------------------

def test_chord_reveals_neighbors_when_flag_count_matches():
    game = _game_with_mine_at_origin()
    game.reveal_cell(1, 1)        # the "1"
    game.toggle_flag(0, 0)        # correctly flag the only mine
    game.chord_cell(1, 1)
    assert game.detonated is None        # chord opened only safe cells
    assert game.state[0][1] == REVEALED  # a safe neighbor got opened
    assert game.win is True              # full clear


def test_chord_with_wrong_flag_detonates():
    game = _game_with_mine_at_origin()
    game.reveal_cell(1, 1)        # the "1"
    game.toggle_flag(0, 1)        # WRONG: flag a safe cell, not the mine
    game.chord_cell(1, 1)         # flag count (1) matches => reveals (0,0) mine
    assert game.game_over is True
    assert game.win is False


def test_chord_is_noop_when_flag_count_mismatches():
    game = _game_with_mine_at_origin()
    game.reveal_cell(1, 1)        # the "1", zero flags around it
    game.chord_cell(1, 1)
    assert game.state[0][0] == COVERED   # mine untouched
    assert game.game_over is False


def test_chord_on_unrevealed_or_zero_is_noop():
    game = _game_with_mine_at_origin()
    game.chord_cell(1, 1)               # not revealed yet
    assert game.state[1][1] == COVERED


# --- reset -----------------------------------------------------------------

def test_reset_restores_fresh_board():
    game = _game_with_mine_at_origin()
    game.reveal_cell(0, 0)              # lose
    assert game.game_over is True
    game.reset()
    assert game.game_over is False
    assert game.win is False
    assert game.detonated is None
    assert all(
        game.state[r][c] == COVERED for r in range(3) for c in range(3)
    )
    assert sum(
        game.is_mine[r][c] for r in range(3) for c in range(3)
    ) == game.mines
