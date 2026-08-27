SIM ?= Apple Watch Series 11 (46mm)
SCHEME = Kaff Watch App
DEST = platform=watchOS Simulator,name=$(SIM)
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
	xcrun simctl boot "$(SIM)" 2>/dev/null || true
	open -a Simulator
	xcrun simctl install "$(SIM)" "$(APP)"
	xcrun simctl launch "$(SIM)" $(BUNDLE_ID)

clean:
	rm -rf $(DERIVED) Kaff.xcodeproj Packages/KaffCore/.build
