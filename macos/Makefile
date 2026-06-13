# Native macOS Minesweeper (Swift + AppKit) — dev tasks
# Build needs only the Command Line Tools (no Xcode).

APP    := Minesweeper
BUILD  := build
BIN    := .build/release/$(APP)
BUNDLE := $(BUILD)/$(APP).app

.DEFAULT_GOAL := run
.PHONY: run build test preview app clean

## run: build (debug) and launch the game window
run:
	swift run $(APP)

## build: release build of the app binary
build:
	swift build -c release --product $(APP)

## test: run the headless logic test suite
test:
	swift run MinesweeperTests

## preview: dump mid-game + game-over PNGs for visual verification
preview:
	swift run MinesweeperPreview /tmp/msw_mid.png /tmp/msw_over.png

## app: assemble + ad-hoc sign Minesweeper.app, then open it
app: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	cp $(BIN) $(BUNDLE)/Contents/MacOS/$(APP)
	cp Info.plist $(BUNDLE)/Contents/Info.plist
	codesign --force --sign - $(BUNDLE)
	@echo "Built $(BUNDLE)"
	open $(BUNDLE)

## clean: remove build artifacts
clean:
	rm -rf .build $(BUILD)
