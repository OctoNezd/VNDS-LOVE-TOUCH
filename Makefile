.PHONY: all clean compile run test build icons help

# Default target
all: compile

# Help target
help:
	@echo "Available targets:"
	@echo "  icons    - Generate icon files from SVG"
	@echo "  clean    - Remove the vnds/ directory"
	@echo "  compile  - Compile MoonScript files to Lua"
	@echo "  run      - Compile and run the game with love"
	@echo "  test     - Run busted unit tests"
	@echo "  build    - Build release binaries"
	@echo "  help     - Show this help message"

# Generate icons from SVG
icons:
	convert icons/icon.svg -resize 48x48 icons/icon.png
	convert icons/icon.svg -resize 256x256 icons/icon.jpg

# Clean build artifacts
clean:
	rm -rf vnds/ VNDS-LOVE/

# Compile MoonScript to Lua
compile: clean
	cp -r src/ vnds/
	@echo "Compiling MoonScript files..."
	@find vnds/ -name "*.moon" -type f | while read file; do \
		echo "$$file"; \
		moonc "$$file" || exit 1; \
		rm "$$file"; \
	done

# i dont want to pollute my documents folder
sampleprep:
	ln -s $(PWD) ~/Library/Application\ Support/LOVE/VNDS-LOVE/work_around_symlink_bug

# Run the game
run: compile
	love vnds nomount

# Run tests
test:
	cd src && busted -C . ../spec

# Build release binaries
build: compile
	mkdir -p VNDS-LOVE/build
	cd vnds;zip -r ../VNDS-LOVE/build/vnds.love  .
