SIM ?= Apple Watch Series 11 (46mm)
OS ?= 26.5
OS_RE := $(subst .,\.,$(OS))
# Deux simulateurs portent le même nom (watchOS 26.4 et 26.5) : xcodebuild refuse un nom ambigu, on résout l'UDID.
ifeq ($(origin SIM_ID), undefined)
SIM_ID := $(shell xcrun simctl list devices available | sed -n '/^-- watchOS $(OS_RE) --$$/,/^-- /p' | grep -F "$(SIM)" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
endif
SCHEME = Kaff Watch App
DEST = platform=watchOS Simulator,id=$(SIM_ID)
DERIVED = build
APP = $(DERIVED)/Build/Products/Debug-watchsimulator/Kaff Watch App.app
BUNDLE_ID = fr.batum.kaff.watchkitapp

.PHONY: generate test-core check-sim build test run clean

generate:
	@test -f Config/Local.xcconfig || { cp Config/Local.xcconfig.example Config/Local.xcconfig; echo "Config/Local.xcconfig created from example — set DEVELOPMENT_TEAM before building for a device"; }
	xcodegen generate

test-core:
	cd Packages/KaffCore && swift test

check-sim:
	@test -n "$(SIM_ID)" || { echo "error: no simulator matching '$(SIM)' under watchOS $(OS) — see 'xcrun simctl list devices available'"; exit 1; }

build: generate check-sim
	xcodebuild -project Kaff.xcodeproj -scheme "$(SCHEME)" -destination "$(DEST)" \
	  -derivedDataPath $(DERIVED) -quiet build

test: generate check-sim
	xcodebuild -project Kaff.xcodeproj -scheme "$(SCHEME)" -destination "$(DEST)" \
	  -derivedDataPath $(DERIVED) -quiet test

run: build check-sim
	xcrun simctl boot "$(SIM_ID)" 2>/dev/null || true
	open -a Simulator
	xcrun simctl install "$(SIM_ID)" "$(APP)"
	xcrun simctl launch "$(SIM_ID)" $(BUNDLE_ID)

clean:
	rm -rf $(DERIVED) Kaff.xcodeproj Packages/KaffCore/.build
