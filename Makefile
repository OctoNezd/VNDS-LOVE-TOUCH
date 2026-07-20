.PHONY: all clean compile run test build icons help

# Default target
all: compile

# Help target
help:
	@echo "Available targets:"
	@echo "  icons    - Generate icon files from SVG"
	@echo "  clean    - Remove the vnds/ directory"
	@echo "  compile  - Copy src/ to vnds/ (no MoonScript compilation needed)"
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

# Copy src to vnds/ (all files are now plain Lua)
compile: clean
	cp -r src/ vnds/

# i dont want to pollute my documents folder
sampleprep:
	ln -s $(PWD) ~/Library/Application\ Support/LOVE/VNDS-LOVE/work_around_symlink_bug

# Run the game
run: compile
	love vnds nomount

run-doc: compile
	love vnds

run-narcissu: compile
	love vnds nomount "Narcissu 2 - R3.7z" 1

# Run tests
test:
	cd src && busted -C . ../spec

# Build release binaries
build: compile
	mkdir -p VNDS-LOVE/build
	cd vnds;zip -r ../VNDS-LOVE/build/vnds.love  .

install-container: build
	cp VNDS-LOVE/build/vnds.love ~/Library/Containers/28149278-D215-439E-A9ED-C293C0F93DDE/Data/Documents/core.love

run-onmac: install-container
	$(MAKE) -C SwiftVN run-onmac
