# Nepali Input — Build System
# Builds the Nepali Input input method as a universal (Apple silicon + Intel) .app bundle

APP_NAME = NepaliInput
BUNDLE_ID = com.pradeeps.inputmethod.NepaliInput
APP_BUNDLE = $(APP_NAME).app
INSTALL_DIR = $(HOME)/Library/Input\ Methods

SWIFT_FILES = $(wildcard Sources/*.swift)
FRAMEWORKS = -framework Cocoa -framework InputMethodKit -framework Carbon
HELPER_FRAMEWORKS = -framework Carbon -framework Foundation

# Deployment targets
ARM_TARGET = arm64-apple-macos13
INTEL_TARGET = x86_64-apple-macos13

# Swift compiler
SWIFTC = swiftc

# Build directory
BUILD_DIR = build

.PHONY: all clean build helper install uninstall reinstall

all: build

# Registration helper, universal (used by the installers to enable the input source)
helper: scripts/register_input_source.swift
	@mkdir -p $(BUILD_DIR)
	$(SWIFTC) -target $(ARM_TARGET) $(HELPER_FRAMEWORKS) -O scripts/register_input_source.swift -o $(BUILD_DIR)/register_input_source-arm64
	$(SWIFTC) -target $(INTEL_TARGET) $(HELPER_FRAMEWORKS) -O scripts/register_input_source.swift -o $(BUILD_DIR)/register_input_source-x86_64
	lipo -create $(BUILD_DIR)/register_input_source-arm64 $(BUILD_DIR)/register_input_source-x86_64 -output $(BUILD_DIR)/register_input_source
	@rm -f $(BUILD_DIR)/register_input_source-arm64 $(BUILD_DIR)/register_input_source-x86_64

# Compile the app for both architectures and combine them into one universal executable
build: $(SWIFT_FILES) helper
	@echo "🔨 Compiling $(APP_NAME) (Apple silicon + Intel)..."
	@mkdir -p $(BUILD_DIR)
	$(SWIFTC) -target $(ARM_TARGET) $(FRAMEWORKS) -O $(SWIFT_FILES) -o $(BUILD_DIR)/$(APP_NAME)-arm64
	$(SWIFTC) -target $(INTEL_TARGET) $(FRAMEWORKS) -O $(SWIFT_FILES) -o $(BUILD_DIR)/$(APP_NAME)-x86_64
	lipo -create $(BUILD_DIR)/$(APP_NAME)-arm64 $(BUILD_DIR)/$(APP_NAME)-x86_64 -output $(BUILD_DIR)/$(APP_NAME)
	@rm -f $(BUILD_DIR)/$(APP_NAME)-arm64 $(BUILD_DIR)/$(APP_NAME)-x86_64
	@echo "📦 Creating app bundle..."
	@mkdir -p $(BUILD_DIR)/$(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(BUILD_DIR)/$(APP_BUNDLE)/Contents/Resources
	@cp $(BUILD_DIR)/$(APP_NAME) $(BUILD_DIR)/$(APP_BUNDLE)/Contents/MacOS/
	@cp Resources/Info.plist $(BUILD_DIR)/$(APP_BUNDLE)/Contents/
	@cp Resources/*.tiff $(BUILD_DIR)/$(APP_BUNDLE)/Contents/Resources/ 2>/dev/null || true
	@cp Resources/*.icns $(BUILD_DIR)/$(APP_BUNDLE)/Contents/Resources/ 2>/dev/null || true
	@cp Resources/*.png $(BUILD_DIR)/$(APP_BUNDLE)/Contents/Resources/ 2>/dev/null || true
	@cp Resources/lexicon/*.tsv $(BUILD_DIR)/$(APP_BUNDLE)/Contents/Resources/ 2>/dev/null || true
	@cp $(BUILD_DIR)/register_input_source $(BUILD_DIR)/$(APP_BUNDLE)/Contents/Resources/
	@echo "🔏 Code signing..."
	@codesign --force --sign - \
		--entitlements Resources/NepaliInput.entitlements \
		$(BUILD_DIR)/$(APP_BUNDLE)
	@echo "✅ Build complete: $(BUILD_DIR)/$(APP_BUNDLE)"
	@lipo -info $(BUILD_DIR)/$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)

# Install to ~/Library/Input Methods
install: build
	@echo "📥 Installing $(APP_NAME)..."
	@# Kill any running instance of MacInput or NepaliInput
	@-pkill -f "MacInput.app" 2>/dev/null || true
	@-pkill -f "$(APP_NAME).app" 2>/dev/null || true
	@sleep 1
	@mkdir -p $(INSTALL_DIR)
	@rm -rf $(INSTALL_DIR)/MacInput.app
	@rm -rf $(INSTALL_DIR)/$(APP_BUNDLE)
	@cp -R $(BUILD_DIR)/$(APP_BUNDLE) $(INSTALL_DIR)/
	@echo "✅ Installed to ~/Library/Input Methods/"
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  Next steps:"
	@echo "  1. Open System Settings → Keyboard → Input Sources"
	@echo "  2. Click 'Edit...' then '+' to add a new input source"
	@echo "  3. Search for 'Nepali Input' and add it"
	@echo "  4. Switch to Nepali Input from the menu bar (ने icon)"
	@echo "  5. Start typing in English — suggestions will appear!"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Uninstall
uninstall:
	@echo "🗑  Uninstalling $(APP_NAME)..."
	@-pkill -f "MacInput.app" 2>/dev/null || true
	@-pkill -f "$(APP_NAME).app" 2>/dev/null || true
	@rm -rf $(INSTALL_DIR)/MacInput.app
	@rm -rf $(INSTALL_DIR)/$(APP_BUNDLE)
	@echo "✅ $(APP_NAME) has been removed."

# Reinstall (useful during development)
reinstall: uninstall install

# Clean build artifacts
clean:
	@echo "🧹 Cleaning..."
	@rm -rf $(BUILD_DIR)
	@echo "✅ Clean complete."
