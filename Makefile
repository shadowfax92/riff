APP_NAME := Riff
APP_BUNDLE := $(APP_NAME).app
CONFIG ?= release
INSTALL_DIR ?= $(HOME)/Applications

.PHONY: all build app install open test clean

all: build

build: app

app:
	CONFIG="$(CONFIG)" scripts/make-app.sh

install: app
	mkdir -p "$(INSTALL_DIR)"
	rm -rf "$(INSTALL_DIR)/$(APP_BUNDLE)"
	ditto "$(APP_BUNDLE)" "$(INSTALL_DIR)/$(APP_BUNDLE)"
	@echo "✓ Installed $(INSTALL_DIR)/$(APP_BUNDLE)"
	@echo "  open \"$(INSTALL_DIR)/$(APP_BUNDLE)\""

open: app
	open "$(APP_BUNDLE)"

test:
	swift test

clean:
	rm -rf .build "$(APP_BUNDLE)"
