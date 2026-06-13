# Minesweeper — dev tasks
# Usage: `make` or `make run` to play; `make install` to set up; `make clean` to reset.

PYTHON := python3.14
VENV   := .venv
VENV_PY := $(VENV)/bin/python
VENV_PIP := $(VENV)/bin/pip

.DEFAULT_GOAL := run
.PHONY: run install test clean

## run: launch the game (sets up the venv on first run)
run: $(VENV)
	$(VENV_PY) mine1.py

## install: create the venv and install dependencies
install: $(VENV)

## test: run the logic test suite (installs pytest if needed)
test: $(VENV)
	$(VENV_PIP) install -q -r requirements-dev.txt
	$(VENV_PY) -m pytest -q

# Create the venv and install pinned deps. Re-runs only if .venv is missing
# or requirements.txt is newer than the venv.
$(VENV): requirements.txt
	$(PYTHON) -m venv $(VENV)
	$(VENV_PIP) install --upgrade pip
	$(VENV_PIP) install -r requirements.txt
	@touch $(VENV)

## clean: remove the venv and Python caches
clean:
	rm -rf $(VENV)
	find . -type d -name __pycache__ -exec rm -rf {} +
