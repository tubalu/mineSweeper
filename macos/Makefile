# Native macOS Minesweeper (Swift + AppKit) — dev tasks
# Build needs only the Command Line Tools (no Xcode).

APP     := Minesweeper
BUILD   := build
BIN     := .build/release/$(APP)
BUNDLE  := $(BUILD)/$(APP).app
ICONSET := $(BUILD)/AppIcon.iconset
ICNS    := $(BUILD)/AppIcon.icns
PYICON  := ../icon.png          # PNG the pygame window loads (committed at repo root)

.DEFAULT_GOAL := run
.PHONY: run build test preview icon app clean

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

## icon: generate AppIcon.icns (all sizes) + the pygame window PNG
icon:
	rm -rf $(ICONSET)
	swift run MinesweeperIcon $(ICONSET) $(PYICON) 256
	iconutil -c icns -o $(ICNS) $(ICONSET)
	@echo "Built $(ICNS) and $(PYICON)"

## app: assemble + ad-hoc sign Minesweeper.app (with icon), then open it
app: build icon
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	cp $(BIN) $(BUNDLE)/Contents/MacOS/$(APP)
	cp Info.plist $(BUNDLE)/Contents/Info.plist
	cp $(ICNS) $(BUNDLE)/Contents/Resources/AppIcon.icns
	codesign --force --sign - $(BUNDLE)
	@echo "Built $(BUNDLE)"
	open $(BUNDLE)

## clean: remove build artifacts
clean:
	rm -rf .build $(BUILD)
