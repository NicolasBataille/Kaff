SIM ?= Apple Watch Series 11 (46mm)
OS ?= 26.5
# Deux simulateurs portent le même nom (watchOS 26.4 et 26.5) : xcodebuild refuse un nom ambigu, on résout l'UDID.
SIM_ID ?= $(shell xcrun simctl list devices available | sed -n '/^-- watchOS $(OS) --$$/,/^-- /p' | grep -F "$(SIM)" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
SCHEME = Kaff Watch App
DEST = platform=watchOS Simulator,id=$(SIM_ID)
DERIVED = build
APP = $(DERIVED)/Build/Products/Debug-watchsimulator/Kaff Watch App.app
BUNDLE_ID = fr.batum.kaff.watchkitapp

.PHONY: generate test-core build test run clean

generate:
	xcodegen generate

test-core:
	cd Packages/KaffCore && swift test

build: generate
	xcodebuild -project Kaff.xcodeproj -scheme "$(SCHEME)" -destination "$(DEST)" \
	  -derivedDataPath $(DERIVED) -quiet build

test: generate
	xcodebuild -project Kaff.xcodeproj -scheme "$(SCHEME)" -destination "$(DEST)" \
	  -derivedDataPath $(DERIVED) -quiet -enableCodeCoverage YES test

run: build
	xcrun simctl boot "$(SIM_ID)" 2>/dev/null || true
	open -a Simulator
	xcrun simctl install "$(SIM_ID)" "$(APP)"
	xcrun simctl launch "$(SIM_ID)" $(BUNDLE_ID)

clean:
	rm -rf $(DERIVED) Kaff.xcodeproj Packages/KaffCore/.build
