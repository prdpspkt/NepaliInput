# Nepali Input — Build System
# Builds the Nepali Input input method and creates a proper .app bundle

APP_NAME = NepaliInput
BUNDLE_ID = com.pradeeps.inputmethod.NepaliInput
APP_BUNDLE = $(APP_NAME).app
INSTALL_DIR = $(HOME)/Library/Input\ Methods

SWIFT_FILES = $(wildcard Sources/*.swift)
FRAMEWORKS = -framework Cocoa -framework InputMethodKit -framework Carbon

# Deployment target
MACOS_TARGET = -target arm64-apple-macos13

# Swift compiler flags
SWIFTC = swiftc
SWIFTFLAGS = $(MACOS_TARGET) $(FRAMEWORKS) -O

# Build directory
BUILD_DIR = build

.PHONY: all clean build install uninstall reinstall

all: build

# Compile Swift sources into executable
build: $(SWIFT_FILES)
	@echo "🔨 Compiling $(APP_NAME)..."
	@mkdir -p $(BUILD_DIR)
	$(SWIFTC) $(SWIFTFLAGS) $(SWIFT_FILES) -o $(BUILD_DIR)/$(APP_NAME)
	@echo "📦 Creating app bundle..."
	@mkdir -p $(BUILD_DIR)/$(APP_BUNDLE)/Contents/MacOS
	@mkdir -p $(BUILD_DIR)/$(APP_BUNDLE)/Contents/Resources
	@cp $(BUILD_DIR)/$(APP_NAME) $(BUILD_DIR)/$(APP_BUNDLE)/Contents/MacOS/
	@cp Resources/Info.plist $(BUILD_DIR)/$(APP_BUNDLE)/Contents/
	@cp Resources/*.tiff $(BUILD_DIR)/$(APP_BUNDLE)/Contents/Resources/ 2>/dev/null || true
	@cp Resources/*.icns $(BUILD_DIR)/$(APP_BUNDLE)/Contents/Resources/ 2>/dev/null || true
	@cp Resources/*.png $(BUILD_DIR)/$(APP_BUNDLE)/Contents/Resources/ 2>/dev/null || true
	@echo "🔏 Code signing..."
	@codesign --force --sign - \
		--entitlements Resources/NepaliInput.entitlements \
		$(BUILD_DIR)/$(APP_BUNDLE)
	@echo "✅ Build complete: $(BUILD_DIR)/$(APP_BUNDLE)"

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
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  Next steps:"
	@echo "  1. Open System Settings → Keyboard → Input Sources"
	@echo "  2. Click 'Edit...' then '+' to add a new input source"
	@echo "  3. Search for 'Nepali Input' and add it"
	@echo "  4. Switch to Nepali Input from the menu bar (ने icon)"
	@echo "  5. Start typing in English — suggestions will appear!"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

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
