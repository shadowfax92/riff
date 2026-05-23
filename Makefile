APP_NAME := Riff
APP_BUNDLE := $(APP_NAME).app
BUNDLE_ID := com.riff.Riff
BUNDLE_VERSION := 1
CONFIG ?= release
ICON_FILE := AppIcon.icns
ICON_NAME := AppIcon
INSTALL_DIR ?= /Applications
MIN_MACOS := 15.0
SHORT_VERSION := 0.1.0
BIN_PATH := .build/$(CONFIG)/$(APP_NAME)
SHELL := /bin/bash

DMG_PATH := $(APP_NAME)-$(SHORT_VERSION).dmg
DMG_STAGING := .build/dmg-staging
INSTALL_APP := $(INSTALL_DIR)/$(APP_BUNDLE)
INSTALL_STAGING_DIR := .build/install-staging
INSTALL_STAGING_APP := $(INSTALL_STAGING_DIR)/$(APP_BUNDLE)

.PHONY: all build app icon install reinstall uninstall open dmg test clean

all: build

build: app

icon:
	@./scripts/regenerate-icon.sh

app: Resources/$(ICON_FILE)
	@set -euo pipefail; \
	echo "→ swift build -c $(CONFIG)"; \
	swift build -c "$(CONFIG)"; \
	if [[ ! -x "$(BIN_PATH)" ]]; then \
		echo "Expected binary not found at $(BIN_PATH)" >&2; \
		exit 1; \
	fi; \
	echo "→ assembling $(APP_BUNDLE)"; \
	rm -rf "$(APP_BUNDLE)"; \
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS" "$(APP_BUNDLE)/Contents/Resources"; \
	cp "$(BIN_PATH)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"; \
	cp "Resources/$(ICON_FILE)" "$(APP_BUNDLE)/Contents/Resources/$(ICON_FILE)"; \
	{ \
		printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>'; \
		printf '%s\n' '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'; \
		printf '%s\n' '<plist version="1.0">'; \
		printf '%s\n' '<dict>'; \
		printf '%s\n' '    <key>CFBundleDevelopmentRegion</key>'; \
		printf '%s\n' '    <string>en</string>'; \
		printf '%s\n' '    <key>CFBundleExecutable</key>'; \
		printf '%s\n' '    <string>$(APP_NAME)</string>'; \
		printf '%s\n' '    <key>CFBundleIdentifier</key>'; \
		printf '%s\n' '    <string>$(BUNDLE_ID)</string>'; \
		printf '%s\n' '    <key>CFBundleIconFile</key>'; \
		printf '%s\n' '    <string>$(ICON_NAME)</string>'; \
		printf '%s\n' '    <key>CFBundleInfoDictionaryVersion</key>'; \
		printf '%s\n' '    <string>6.0</string>'; \
		printf '%s\n' '    <key>CFBundleName</key>'; \
		printf '%s\n' '    <string>$(APP_NAME)</string>'; \
		printf '%s\n' '    <key>CFBundleDisplayName</key>'; \
		printf '%s\n' '    <string>$(APP_NAME)</string>'; \
		printf '%s\n' '    <key>CFBundlePackageType</key>'; \
		printf '%s\n' '    <string>APPL</string>'; \
		printf '%s\n' '    <key>CFBundleShortVersionString</key>'; \
		printf '%s\n' '    <string>$(SHORT_VERSION)</string>'; \
		printf '%s\n' '    <key>CFBundleVersion</key>'; \
		printf '%s\n' '    <string>$(BUNDLE_VERSION)</string>'; \
		printf '%s\n' '    <key>LSMinimumSystemVersion</key>'; \
		printf '%s\n' '    <string>$(MIN_MACOS)</string>'; \
		printf '%s\n' '    <key>NSHighResolutionCapable</key>'; \
		printf '%s\n' '    <true/>'; \
		printf '%s\n' '    <key>NSPrincipalClass</key>'; \
		printf '%s\n' '    <string>NSApplication</string>'; \
		printf '%s\n' '    <key>NSSupportsAutomaticGraphicsSwitching</key>'; \
		printf '%s\n' '    <true/>'; \
		printf '%s\n' '</dict>'; \
		printf '%s\n' '</plist>'; \
	} > "$(APP_BUNDLE)/Contents/Info.plist"; \
	codesign --force --sign - "$(APP_BUNDLE)" >/dev/null; \
	echo "✓ $(CURDIR)/$(APP_BUNDLE)"; \
	echo "  open $(CURDIR)/$(APP_BUNDLE)"

install: app
	@set -euo pipefail; \
	echo "→ installing $(INSTALL_APP)"; \
	rm -rf "$(INSTALL_STAGING_DIR)"; \
	mkdir -p "$(INSTALL_STAGING_DIR)" "$(INSTALL_DIR)"; \
	ditto "$(APP_BUNDLE)" "$(INSTALL_STAGING_APP)"; \
	codesign --force --sign - "$(INSTALL_STAGING_APP)" >/dev/null; \
	rm -rf "$(INSTALL_APP)"; \
	ditto "$(INSTALL_STAGING_APP)" "$(INSTALL_APP)"; \
	codesign --verify --deep --strict "$(INSTALL_APP)" >/dev/null; \
	rm -rf "$(INSTALL_STAGING_DIR)"; \
	echo "✓ Installed $(INSTALL_APP)"; \
	echo "  open \"$(INSTALL_APP)\""

reinstall:
	@rm -rf "$(INSTALL_APP)"
	@$(MAKE) install INSTALL_DIR="$(INSTALL_DIR)" CONFIG="$(CONFIG)"

uninstall:
	rm -rf "$(INSTALL_APP)"
	@echo "✓ Removed $(INSTALL_APP)"

open: app
	open "$(APP_BUNDLE)"

dmg: app
	@set -euo pipefail; \
	echo "→ staging $(DMG_PATH)"; \
	rm -rf "$(DMG_STAGING)" "$(DMG_PATH)"; \
	mkdir -p "$(DMG_STAGING)"; \
	cp -R "$(APP_BUNDLE)" "$(DMG_STAGING)/"; \
	ln -s /Applications "$(DMG_STAGING)/Applications"; \
	hdiutil create \
		-volname "$(APP_NAME) $(SHORT_VERSION)" \
		-srcfolder "$(DMG_STAGING)" \
		-ov \
		-format UDZO \
		"$(DMG_PATH)" >/dev/null; \
	rm -rf "$(DMG_STAGING)"; \
	echo "✓ $(CURDIR)/$(DMG_PATH)"

test:
	swift test

clean:
	rm -rf .build "$(APP_BUNDLE)" "$(APP_NAME)"-*.dmg
