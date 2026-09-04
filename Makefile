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

.PHONY: generate test-core check-sim build test run clean figures archive testflight

# Figures du README (docs/figures/*.svg|png), calculées avec les constantes du modèle. Dépend de matplotlib.
figures:
	python3 docs/figures/make_figures.py

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

# Archive App Store : schéma `Kaff` = conteneur iOS sans code qui embarque l'app Watch (Xcode n'a pas de
# méthode de distribution App Store pour watchOS). Signature automatique, Team ID dans Config/Local.xcconfig.
ARCHIVE = $(DERIVED)/Kaff.xcarchive
archive: generate
	rm -rf "$(ARCHIVE)"
	xcodebuild -project Kaff.xcodeproj -scheme Kaff -destination "generic/platform=iOS" -configuration Release \
	  -archivePath "$(ARCHIVE)" -allowProvisioningUpdates -quiet archive

# Envoi vers App Store Connect / TestFlight (fiche app `fr.batum.kaff`, plateforme iOS, requise au préalable).
# PATH réduit : openrsync (/usr/bin/rsync) lance « rsync » comme serveur via le PATH ; s'il tombe sur le rsync
# 3.x de Homebrew, l'étape « Create IPA » échoue (« Copy failed », option --extended-attributes inconnue).
testflight: archive
	PATH=/usr/bin:/bin:/usr/sbin:/sbin xcodebuild -exportArchive -archivePath "$(ARCHIVE)" -exportOptionsPlist Config/ExportOptions-TestFlight.plist \
	  -exportPath $(DERIVED)/export -allowProvisioningUpdates

clean:
	rm -rf $(DERIVED) Kaff.xcodeproj Packages/KaffCore/.build
