# Kaff — Plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** App Apple Watch standalone qui logue des doses de caféine dans HealthKit, estime en direct la quantité dans l'organisme (modèle de Bateman), la qualifie (ok / élevé / trop haut) selon poids et heure de coucher, et l'expose en complication WidgetKit.

**Architecture:** Un package Swift pur `KaffCore` (modèle PK, seuils, timeline, catalogue, persistance App Group) testé sous macOS avec `swift test`. Une cible watchOS SwiftUI (`Kaff Watch App`) avec un `AppModel` `@Observable` qui orchestre HealthKit (derrière un protocole `HealthStore`), écrit un snapshot dans l'App Group et recharge le widget. Une extension WidgetKit (`KaffComplication`) qui ne lit que le snapshot et précalcule sa timeline.

**Tech Stack:** Swift 6.3 (concurrence stricte), SwiftUI, Swift Charts, HealthKit, WidgetKit, Swift Testing, XcodeGen 2.45, watchOS 26.0+, Xcode 26.6.

**Spec :** `docs/superpowers/specs/2026-08-27-kaff-design.md`. **Suivi :** cocher ici, puis mettre à jour `docs/ROADMAP.md`.

**Conventions communes à toutes les tâches :**
- Commandes lancées depuis la racine `/Users/batum/Projects/Kaff`.
- `make test-core` = `cd Packages/KaffCore && swift test`. Une tâche n'est finie que si tout est vert.
- Chaque constante numérique porte un commentaire `// Source: …`.
- Commit conventionnel par tâche, message préfixé par l'identifiant de tâche.

---

## Structure des fichiers

```
Kaff/
├── Makefile
├── project.yml
├── Config/
│   ├── Local.xcconfig.example          # DEVELOPMENT_TEAM = XXXXXXXXXX
│   └── Local.xcconfig                  # gitignoré, copie renseignée
├── Packages/KaffCore/
│   ├── Package.swift
│   ├── Sources/KaffCore/
│   │   ├── Model/CaffeineDose.swift
│   │   ├── Model/Drink.swift
│   │   ├── Model/ClockTime.swift
│   │   ├── Model/UserProfile.swift
│   │   ├── Model/LevelStatus.swift
│   │   ├── Catalog/DrinkCatalog.swift
│   │   ├── Catalog/DrinkEquivalence.swift
│   │   ├── Pharmacokinetics/PharmacokineticModel.swift
│   │   ├── Assessment/CaffeineDay.swift
│   │   ├── Assessment/LevelAssessment.swift
│   │   ├── Assessment/LevelAssessor.swift
│   │   ├── Timeline/TimelinePoint.swift
│   │   ├── Timeline/TimelineBuilder.swift
│   │   ├── Persistence/AppGroup.swift
│   │   ├── Persistence/CacheSnapshot.swift
│   │   ├── Persistence/CacheStore.swift
│   │   └── Persistence/ProfileStore.swift
│   └── Tests/KaffCoreTests/
│       ├── Support/TestClock.swift
│       ├── PharmacokineticModelTests.swift
│       ├── DrinkCatalogTests.swift
│       ├── CaffeineDayTests.swift
│       ├── LevelAssessorTests.swift
│       ├── TimelineBuilderTests.swift
│       ├── CacheStoreTests.swift
│       └── ProfileStoreTests.swift
├── Kaff Watch App/
│   ├── App/KaffApp.swift
│   ├── App/AppModel.swift
│   ├── App/Route.swift
│   ├── Services/HealthStore.swift
│   ├── Services/HealthKitStore.swift
│   ├── Services/WidgetReloader.swift
│   ├── Features/Authorization/AuthorizationView.swift
│   ├── Features/Home/HomeView.swift
│   ├── Features/Home/LevelGaugeView.swift
│   ├── Features/Home/CaffeineChartView.swift
│   ├── Features/QuickLog/DrinkPickerView.swift
│   ├── Features/QuickLog/DrinkAmountView.swift
│   ├── Features/QuickLog/ManualDoseView.swift
│   ├── Features/History/HistoryView.swift
│   ├── Features/Settings/SettingsView.swift
│   ├── Features/Settings/CustomDrinkEditorView.swift
│   ├── Shared/Formatters.swift
│   ├── Shared/LevelStatus+UI.swift
│   ├── Resources/Assets.xcassets
│   ├── Resources/Localizable.xcstrings
│   └── Kaff.entitlements
├── KaffTests/
│   ├── Mocks/MockHealthStore.swift
│   ├── Mocks/SpyWidgetReloader.swift
│   └── AppModelTests.swift
├── KaffComplication/
│   ├── KaffComplicationBundle.swift
│   ├── CaffeineEntry.swift
│   ├── CaffeineTimelineProvider.swift
│   ├── CaffeineWidget.swift
│   ├── Views/CircularView.swift
│   ├── Views/RectangularView.swift
│   ├── Views/CornerView.swift
│   ├── Views/InlineView.swift
│   └── KaffComplication.entitlements
└── docs/screenshots/
```

Responsabilités : voir spec §3.1. Règle : un type public par fichier, fichiers < 200 lignes.

---

## M0 — Fondations

### Task M0.1 : Package `KaffCore` vide et testable

**Files:**
- Create: `Packages/KaffCore/Package.swift`
- Create: `Packages/KaffCore/Sources/KaffCore/KaffCore.swift`
- Create: `Packages/KaffCore/Tests/KaffCoreTests/SmokeTests.swift`
- Create: `Makefile`

- [ ] **Step 1 : Package.swift**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KaffCore",
    platforms: [.watchOS("26.0"), .macOS("15.0")],
    products: [.library(name: "KaffCore", targets: ["KaffCore"])],
    targets: [
        .target(name: "KaffCore", swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "KaffCoreTests", dependencies: ["KaffCore"]),
    ]
)
```

- [ ] **Step 2 : source et test de fumée**

`Sources/KaffCore/KaffCore.swift` :
```swift
/// Logique métier pure de Kaff (aucune dépendance UI ni HealthKit).
public enum KaffCore {
    public static let version = "0.1.0"
}
```

`Tests/KaffCoreTests/SmokeTests.swift` :
```swift
import Testing
@testable import KaffCore

@Test func packageLoads() {
    #expect(KaffCore.version == "0.1.0")
}
```

- [ ] **Step 3 : Makefile**

```make
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
```
(Les retraits des recettes sont des **tabulations**.)

- [ ] **Step 4 : vérifier**

Run: `make test-core`
Expected: `Test run with 1 test passed after …`

- [ ] **Step 5 : commit**

```bash
git add Packages Makefile
git commit -m "chore: M0.1 KaffCore package + Makefile"
```

### Task M0.2 : Projet XcodeGen — app Watch, widget, tests

**Files:**
- Create: `project.yml`
- Create: `Config/Local.xcconfig.example`, `Config/Local.xcconfig` (gitignoré)
- Create: `Kaff Watch App/App/KaffApp.swift`, `Kaff Watch App/Kaff.entitlements`, `Kaff Watch App/Resources/Assets.xcassets/Contents.json`
- Create: `KaffComplication/KaffComplicationBundle.swift`, `KaffComplication/KaffComplication.entitlements`
- Create: `KaffTests/SmokeTests.swift`
- Modify: `.gitignore` (ajouter `Config/Local.xcconfig`)

- [ ] **Step 1 : project.yml**

```yaml
name: Kaff
options:
  bundleIdPrefix: fr.batum
  deploymentTarget:
    watchOS: "26.0"
  xcodeVersion: "26.6"
  createIntermediateGroups: true
  generateEmptyDirectories: true

configFiles:
  Debug: Config/Local.xcconfig
  Release: Config/Local.xcconfig

settings:
  base:
    SWIFT_VERSION: "6.0"
    SWIFT_STRICT_CONCURRENCY: complete
    CODE_SIGN_STYLE: Automatic
    ENABLE_USER_SCRIPT_SANDBOXING: YES
    GENERATE_INFOPLIST_FILE: YES
    CURRENT_PROJECT_VERSION: 1
    MARKETING_VERSION: 0.1.0

packages:
  KaffCore:
    path: Packages/KaffCore

targets:
  Kaff Watch App:
    type: application
    platform: watchOS
    sources:
      - path: Kaff Watch App
        excludes: ["**/*.entitlements"]
    dependencies:
      - package: KaffCore
      - target: KaffComplication
        embed: true
    entitlements:
      path: Kaff Watch App/Kaff.entitlements
      properties:
        com.apple.developer.healthkit: true
        com.apple.developer.healthkit.access: []
        com.apple.security.application-groups: [group.fr.batum.kaff]
    info:
      path: Kaff Watch App/Info.plist
      properties:
        CFBundleDisplayName: Kaff
        WKApplication: true
        WKWatchOnly: true
        NSHealthShareUsageDescription: Kaff lit vos doses de caféine et votre poids pour estimer votre niveau.
        NSHealthUpdateUsageDescription: Kaff enregistre les doses de caféine que vous loguez.
        UISupportedInterfaceOrientations: [UIInterfaceOrientationPortrait]
        CFBundleURLTypes:
          - CFBundleURLName: fr.batum.kaff
            CFBundleURLSchemes: [kaff]
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: fr.batum.kaff.watchkitapp
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor
        INFOPLIST_KEY_WKRunsIndependentlyOfCompanionApp: YES

  KaffComplication:
    type: app-extension
    platform: watchOS
    sources:
      - path: KaffComplication
        excludes: ["**/*.entitlements"]
    dependencies:
      - package: KaffCore
      - sdk: WidgetKit.framework
      - sdk: SwiftUI.framework
    entitlements:
      path: KaffComplication/KaffComplication.entitlements
      properties:
        com.apple.security.application-groups: [group.fr.batum.kaff]
    info:
      path: KaffComplication/Info.plist
      properties:
        CFBundleDisplayName: Kaff
        NSExtension:
          NSExtensionPointIdentifier: com.apple.widgetkit-extension
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: fr.batum.kaff.watchkitapp.complication

  KaffTests:
    type: bundle.unit-test
    platform: watchOS
    sources: [KaffTests]
    dependencies:
      - target: Kaff Watch App
      - package: KaffCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: fr.batum.kaff.tests

schemes:
  Kaff Watch App:
    build:
      targets:
        Kaff Watch App: all
        KaffComplication: all
    run:
      config: Debug
    test:
      config: Debug
      gatherCoverageData: true
      coverageTargets: [Kaff Watch App, KaffComplication]
      targets: [KaffTests]
```

- [ ] **Step 2 : xcconfig**

`Config/Local.xcconfig.example` :
```
// Copier en Config/Local.xcconfig et renseigner le Team ID (Apple Developer > Membership)
DEVELOPMENT_TEAM = XXXXXXXXXX
```
Run: `cp Config/Local.xcconfig.example Config/Local.xcconfig` puis renseigner le Team ID réel.
Ajouter `Config/Local.xcconfig` à `.gitignore`.

- [ ] **Step 3 : app SwiftUI minimale**

`Kaff Watch App/App/KaffApp.swift` :
```swift
import SwiftUI

@main
struct KaffApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Kaff")
        }
    }
}
```

`Kaff Watch App/Resources/Assets.xcassets/Contents.json` :
```json
{ "info": { "author": "xcode", "version": 1 } }
```
Ajouter dans le même catalogue un `AccentColor.colorset` (couleur `#C8792B`, orange café) et un `AppIcon.appiconset` vide (Contents.json `{ "images": [ { "idiom": "universal", "platform": "watchos", "size": "1024x1024" } ], "info": { "author": "xcode", "version": 1 } }`).

- [ ] **Step 4 : widget minimal**

`KaffComplication/KaffComplicationBundle.swift` :
```swift
import SwiftUI
import WidgetKit

@main
struct KaffComplicationBundle: WidgetBundle {
    var body: some Widget {
        PlaceholderWidget()
    }
}

struct PlaceholderEntry: TimelineEntry { let date: Date }

struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry { .init(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) { completion(.init(date: .now)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [.init(date: .now)], policy: .never))
    }
}

struct PlaceholderWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "fr.batum.kaff.level", provider: PlaceholderProvider()) { _ in
            Text("☕").containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Caféine")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner, .accessoryInline])
    }
}
```

- [ ] **Step 5 : test de fumée de la cible app**

`KaffTests/SmokeTests.swift` :
```swift
import Testing
import KaffCore

@Test func appTestTargetRuns() {
    #expect(KaffCore.version == "0.1.0")
}
```

- [ ] **Step 6 : générer et builder**

Run: `make build`
Expected: aucune erreur. Si `xcodebuild` échoue sur `WKApplication`/`WKWatchOnly`, vérifier que les clés sont bien dans `Kaff Watch App/Info.plist` généré ; si l'embed du widget échoue, vérifier `embed: true` et que le bundle id du widget est préfixé par celui de l'app.

Run: `make run`
Expected: le simulateur Series 11 démarre, l'app « Kaff » affiche « Kaff ».

Run: `make test`
Expected: `** TEST SUCCEEDED **` (1 test dans KaffTests).

Vérification widget : dans le simulateur, appui long sur le cadran → Modifier → Complications → « Kaff » apparaît avec ☕.

- [ ] **Step 7 : commit**

```bash
git add project.yml Config/Local.xcconfig.example .gitignore "Kaff Watch App" KaffComplication KaffTests
git commit -m "chore: M0.2 XcodeGen project with watch app, widget extension and test target"
```

Mettre à jour `docs/ROADMAP.md` : M0 ✅.

---

## M1 — KaffCore

### Task M1.1 : Modèles de base

**Files:**
- Create: `Packages/KaffCore/Sources/KaffCore/Model/CaffeineDose.swift`
- Create: `Packages/KaffCore/Sources/KaffCore/Model/Drink.swift`
- Create: `Packages/KaffCore/Sources/KaffCore/Model/ClockTime.swift`
- Create: `Packages/KaffCore/Sources/KaffCore/Model/UserProfile.swift`
- Create: `Packages/KaffCore/Sources/KaffCore/Model/LevelStatus.swift`
- Test: `Packages/KaffCore/Tests/KaffCoreTests/ModelTests.swift`
- Delete: `Packages/KaffCore/Tests/KaffCoreTests/SmokeTests.swift`

- [ ] **Step 1 : tests**

```swift
import Foundation
import Testing
@testable import KaffCore

@Test func drinkScalesMilligramsLinearly() {
    let espresso = Drink(id: "espresso", name: "Espresso", milligrams: 63, volumeML: 30, symbol: "cup.and.saucer.fill")
    #expect(espresso.milligrams(forVolumeML: 60) == 126)
    #expect(espresso.milligrams(forVolumeML: 0) == 0)
}

@Test func weightPrefersManualThenHealthKitThenFallback() {
    var p = UserProfile.default
    #expect(p.weightKg == UserProfile.fallbackWeightKg && p.isWeightEstimated)
    p.healthKitWeightKg = 80
    #expect(p.weightKg == 80 && !p.isWeightEstimated)
    p.manualWeightKg = 75
    #expect(p.weightKg == 75)
}

@Test func singleDoseLimitIsCappedAt200() {
    var p = UserProfile.default
    p.manualWeightKg = 60
    #expect(p.singleDoseLimitMg == 180)
    p.manualWeightKg = 90
    #expect(p.singleDoseLimitMg == 200)
}

@Test func profileClampsOutOfRangeValues() {
    var p = UserProfile.default
    p.manualWeightKg = 10
    p.healthKitWeightKg = 900
    p.halfLifeHours = 40
    let c = p.clamped()
    #expect(c.manualWeightKg == UserProfile.Bounds.weightKg.lowerBound)
    #expect(c.healthKitWeightKg == UserProfile.Bounds.weightKg.upperBound)
    #expect(c.halfLifeHours == UserProfile.Bounds.halfLifeHours.upperBound)
}

@Test func levelStatusFromRatio() {
    #expect(LevelStatus(ratio: 0.2, elevatedAt: 0.6) == .ok)
    #expect(LevelStatus(ratio: 0.6, elevatedAt: 0.6) == .elevated)
    #expect(LevelStatus(ratio: 1.0, elevatedAt: 0.6) == .high)
    #expect(LevelStatus.high > LevelStatus.elevated && LevelStatus.elevated > LevelStatus.ok)
}

@Test func clockTimeMinutesOfDay() {
    #expect(ClockTime(hour: 23, minute: 30).minutesOfDay == 1410)
}

@Test func doseIsCodableRoundTrip() throws {
    let d = CaffeineDose(id: UUID(), date: Date(timeIntervalSince1970: 1_000), milligrams: 63, drinkID: "espresso", volumeML: 30)
    let data = try JSONEncoder().encode(d)
    #expect(try JSONDecoder().decode(CaffeineDose.self, from: data) == d)
}
```

- [ ] **Step 2 : `make test-core` → échec de compilation (types absents)**

- [ ] **Step 3 : implémentation**

`Model/CaffeineDose.swift` :
```swift
import Foundation

/// Une prise de caféine, telle que stockée dans HealthKit (`dietaryCaffeine`).
public struct CaffeineDose: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let date: Date
    public let milligrams: Double
    /// Identifiant du `Drink` d'origine, `nil` pour une saisie manuelle en mg.
    public let drinkID: String?
    public let volumeML: Double?

    public init(id: UUID = UUID(), date: Date, milligrams: Double, drinkID: String? = nil, volumeML: Double? = nil) {
        self.id = id
        self.date = date
        self.milligrams = milligrams
        self.drinkID = drinkID
        self.volumeML = volumeML
    }
}
```

`Model/Drink.swift` :
```swift
import Foundation

/// Une boisson du catalogue (prédéfinie ou personnalisée).
public struct Drink: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public var name: String
    /// Caféine pour `volumeML`.
    public var milligrams: Double
    public var volumeML: Double
    /// Nom de SF Symbol.
    public var symbol: String
    public var isCustom: Bool

    public init(id: String, name: String, milligrams: Double, volumeML: Double, symbol: String, isCustom: Bool = false) {
        self.id = id
        self.name = name
        self.milligrams = milligrams
        self.volumeML = volumeML
        self.symbol = symbol
        self.isCustom = isCustom
    }

    public func milligrams(forVolumeML volume: Double) -> Double {
        guard volumeML > 0 else { return 0 }
        return milligrams * volume / volumeML
    }
}
```

`Model/ClockTime.swift` :
```swift
/// Heure de la journée sans date (ex. heure de coucher).
public struct ClockTime: Hashable, Codable, Sendable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    public var minutesOfDay: Int { hour * 60 + minute }
}
```

`Model/UserProfile.swift` :
```swift
import Foundation

/// Réglages utilisateur qui paramètrent le modèle et les seuils.
public struct UserProfile: Hashable, Codable, Sendable {
    /// Source: valeur de repli quand ni HealthKit ni l'utilisateur ne fournissent de poids.
    public static let fallbackWeightKg = 70.0

    /// Dernier poids lu dans HealthKit (`bodyMass`), rafraîchi par l'app.
    public var healthKitWeightKg: Double?
    /// Surcharge saisie dans Réglages ; prioritaire sur HealthKit.
    public var manualWeightKg: Double?
    public var halfLifeHours: Double
    public var bedtime: ClockTime
    public var dailyLimitMg: Double
    public var bedtimeLimitMg: Double
    public var singleDoseMgPerKg: Double
    public var singleDoseCapMg: Double

    public init(healthKitWeightKg: Double? = nil, manualWeightKg: Double? = nil, halfLifeHours: Double, bedtime: ClockTime,
                dailyLimitMg: Double, bedtimeLimitMg: Double, singleDoseMgPerKg: Double, singleDoseCapMg: Double) {
        self.healthKitWeightKg = healthKitWeightKg
        self.manualWeightKg = manualWeightKg
        self.halfLifeHours = halfLifeHours
        self.bedtime = bedtime
        self.dailyLimitMg = dailyLimitMg
        self.bedtimeLimitMg = bedtimeLimitMg
        self.singleDoseMgPerKg = singleDoseMgPerKg
        self.singleDoseCapMg = singleDoseCapMg
    }

    public static let `default` = UserProfile(
        halfLifeHours: 5,                // Source: EFSA 2015, demi-vie médiane adulte ~5 h (fourchette 1,5–9,5 h)
        bedtime: ClockTime(hour: 23, minute: 0),
        dailyLimitMg: 400,               // Source: EFSA 2015 / FDA, apport journalier sans risque adulte
        bedtimeLimitMg: 50,              // Source: choix produit ; ≈ une demi-tasse restante au coucher. À affiner.
        singleDoseMgPerKg: 3,            // Source: EFSA 2015, dose unique sans risque ≈ 3 mg/kg
        singleDoseCapMg: 200             // Source: EFSA 2015, dose unique ≤ 200 mg
    )

    /// Poids effectif : manuel > HealthKit > repli.
    public var weightKg: Double { manualWeightKg ?? healthKitWeightKg ?? Self.fallbackWeightKg }
    /// `true` quand on utilise le poids de repli (badge « poids estimé » dans l'UI).
    public var isWeightEstimated: Bool { manualWeightKg == nil && healthKitWeightKg == nil }

    /// Dose ponctuelle maximale pour ce poids.
    public var singleDoseLimitMg: Double { min(singleDoseMgPerKg * weightKg, singleDoseCapMg) }

    public enum Bounds {
        public static let weightKg = 30.0...250.0
        public static let halfLifeHours = 2.0...10.0
        public static let dailyLimitMg = 50.0...1000.0
        public static let bedtimeLimitMg = 0.0...300.0
        public static let doseMg = 0.0...1000.0
    }

    /// Copie dont chaque champ est ramené dans ses bornes.
    public func clamped() -> UserProfile {
        var c = self
        c.manualWeightKg = manualWeightKg.map { min(max($0, Bounds.weightKg.lowerBound), Bounds.weightKg.upperBound) }
        c.healthKitWeightKg = healthKitWeightKg.map { min(max($0, Bounds.weightKg.lowerBound), Bounds.weightKg.upperBound) }
        c.halfLifeHours = min(max(halfLifeHours, Bounds.halfLifeHours.lowerBound), Bounds.halfLifeHours.upperBound)
        c.dailyLimitMg = min(max(dailyLimitMg, Bounds.dailyLimitMg.lowerBound), Bounds.dailyLimitMg.upperBound)
        c.bedtimeLimitMg = min(max(bedtimeLimitMg, Bounds.bedtimeLimitMg.lowerBound), Bounds.bedtimeLimitMg.upperBound)
        return c
    }
}
```

`Model/LevelStatus.swift` :
```swift
/// Qualification d'un niveau par rapport à un seuil.
public enum LevelStatus: Int, Comparable, Codable, Sendable, CaseIterable {
    case ok = 0
    case elevated = 1
    case high = 2

    /// `ratio` = valeur / seuil. `high` à partir de 1, `elevated` à partir de `elevatedAt`.
    public init(ratio: Double, elevatedAt: Double) {
        if ratio >= 1 { self = .high } else if ratio >= elevatedAt { self = .elevated } else { self = .ok }
    }

    public static func < (lhs: LevelStatus, rhs: LevelStatus) -> Bool { lhs.rawValue < rhs.rawValue }
}
```

Supprimer `Tests/KaffCoreTests/SmokeTests.swift` (remplacé) et garder `KaffCore.version`.

- [ ] **Step 4 : `make test-core` → 7 tests verts**

- [ ] **Step 5 : commit**

```bash
git add Packages
git commit -m "feat(core): M1.1 base models (dose, drink, profile, status)"
```

### Task M1.2 : Catalogue de boissons et équivalences

**Files:**
- Create: `Packages/KaffCore/Sources/KaffCore/Catalog/DrinkCatalog.swift`
- Create: `Packages/KaffCore/Sources/KaffCore/Catalog/DrinkEquivalence.swift`
- Test: `Packages/KaffCore/Tests/KaffCoreTests/DrinkCatalogTests.swift`

- [ ] **Step 1 : tests**

```swift
import Testing
@testable import KaffCore

@Test func catalogHasUniqueIDsAndPositiveValues() {
    let ids = DrinkCatalog.builtIn.map(\.id)
    #expect(Set(ids).count == ids.count)
    #expect(DrinkCatalog.builtIn.allSatisfy { $0.milligrams >= 0 && $0.volumeML > 0 })
    #expect(DrinkCatalog.builtIn.count >= 10)
}

@Test func lookupByID() {
    #expect(DrinkCatalog.drink(id: "espresso", custom: [])?.milligrams == 63)
    let custom = Drink(id: "custom-1", name: "Mon thé", milligrams: 40, volumeML: 200, symbol: "leaf.fill", isCustom: true)
    #expect(DrinkCatalog.drink(id: "custom-1", custom: [custom])?.name == "Mon thé")
    #expect(DrinkCatalog.drink(id: "nope", custom: []) == nil)
}

@Test func equivalenceInEspressos() {
    let espresso = DrinkCatalog.drink(id: "espresso", custom: [])!
    #expect(abs(DrinkEquivalence.count(of: espresso, forMilligrams: 150) - 2.38) < 0.01)
    #expect(DrinkEquivalence.count(of: espresso, forMilligrams: 0) == 0)
}

@Test func favoritesAreMostFrequentDrinkIDs() {
    let ids = ["espresso", "tea-black", "espresso", "cola", "espresso", "tea-black", "mate"]
    #expect(DrinkCatalog.favoriteIDs(from: ids, limit: 2) == ["espresso", "tea-black"])
}
```

- [ ] **Step 2 : `make test-core` → échec de compilation**

- [ ] **Step 3 : implémentation**

`Catalog/DrinkCatalog.swift` :
```swift
/// Boissons prédéfinies. Valeurs : USDA FoodData Central et EFSA (2015), arrondies.
public enum DrinkCatalog {
    public static let builtIn: [Drink] = [
        Drink(id: "espresso", name: "Espresso", milligrams: 63, volumeML: 30, symbol: "cup.and.saucer.fill"),          // Source: USDA 212 mg/100 g
        Drink(id: "double-espresso", name: "Double espresso", milligrams: 125, volumeML: 60, symbol: "cup.and.saucer.fill"),
        Drink(id: "lungo", name: "Allongé", milligrams: 80, volumeML: 120, symbol: "cup.and.saucer.fill"),              // Source: estimation, entre espresso et filtre
        Drink(id: "filter", name: "Café filtre", milligrams: 95, volumeML: 240, symbol: "mug.fill"),                    // Source: USDA 40 mg/100 g
        Drink(id: "latte", name: "Latte / cappuccino", milligrams: 63, volumeML: 240, symbol: "mug.fill"),               // Source: 1 shot d'espresso
        Drink(id: "decaf", name: "Décaféiné", milligrams: 3, volumeML: 30, symbol: "cup.and.saucer"),                   // Source: USDA décaf espresso ~3 mg/30 ml
        Drink(id: "tea-black", name: "Thé noir", milligrams: 47, volumeML: 240, symbol: "leaf.fill"),                   // Source: USDA 20 mg/100 g
        Drink(id: "tea-green", name: "Thé vert", milligrams: 28, volumeML: 240, symbol: "leaf.fill"),                   // Source: USDA 12 mg/100 g
        Drink(id: "mate", name: "Maté", milligrams: 85, volumeML: 240, symbol: "leaf.fill"),                            // Source: EFSA 2015, ~35 mg/100 ml
        Drink(id: "cola", name: "Cola", milligrams: 34, volumeML: 355, symbol: "takeoutbag.and.cup.and.straw.fill"),    // Source: USDA 9,7 mg/100 g
        Drink(id: "energy", name: "Boisson énergisante", milligrams: 80, volumeML: 250, symbol: "bolt.fill"),           // Source: EFSA 2015, 32 mg/100 ml
        Drink(id: "dark-chocolate", name: "Chocolat noir", milligrams: 12, volumeML: 30, symbol: "square.fill"),        // Source: USDA ~43 mg/100 g ; volumeML = grammes ici
    ]

    public static func drink(id: String, custom: [Drink]) -> Drink? {
        (builtIn + custom).first { $0.id == id }
    }

    /// Identifiants les plus fréquents, par ordre décroissant, égalités départagées par ordre d'apparition.
    public static func favoriteIDs(from loggedIDs: [String], limit: Int) -> [String] {
        var counts: [String: Int] = [:]
        var order: [String] = []
        for id in loggedIDs {
            if counts[id] == nil { order.append(id) }
            counts[id, default: 0] += 1
        }
        return order
            .sorted { (counts[$0]!, order.firstIndex(of: $1)!) > (counts[$1]!, order.firstIndex(of: $0)!) }
            .prefix(limit)
            .map { $0 }
    }
}
```

`Catalog/DrinkEquivalence.swift` :
```swift
/// Conversion mg ⇄ nombre de boissons (« 150 mg ≈ 2,4 espressos »).
public enum DrinkEquivalence {
    public static func count(of drink: Drink, forMilligrams mg: Double) -> Double {
        guard drink.milligrams > 0 else { return 0 }
        return mg / drink.milligrams
    }
}
```

- [ ] **Step 4 : `make test-core` → vert**

- [ ] **Step 5 : commit**

```bash
git add Packages
git commit -m "feat(core): M1.2 drink catalog and equivalences"
```

### Task M1.3 : Modèle pharmacocinétique (Bateman)

**Files:**
- Create: `Packages/KaffCore/Sources/KaffCore/Pharmacokinetics/PharmacokineticModel.swift`
- Test: `Packages/KaffCore/Tests/KaffCoreTests/PharmacokineticModelTests.swift`

- [ ] **Step 1 : tests** (valeurs de référence dérivées indépendamment dans la spec §4)

```swift
import Foundation
import Testing
@testable import KaffCore

private let model = PharmacokineticModel(halfLifeHours: 5)

@Test func nothingBeforeIntake() {
    #expect(model.amount(dose: 100, hoursSince: -1) == 0)
    #expect(model.amount(dose: 100, hoursSince: 0) == 0)
}

@Test func peakOccursAround44Minutes() {
    // tmax = ln(ka/ke)/(ka−ke) avec ka = 5, ke = ln2/5 ≈ 0,1386 → 0,738 h
    #expect(abs(model.timeToPeakHours - 0.738) < 0.005)
    let samples = stride(from: 0.0, through: 3.0, by: 0.01).map { ($0, model.amount(dose: 100, hoursSince: $0)) }
    let peak = samples.max { $0.1 < $1.1 }!
    #expect(abs(peak.0 - model.timeToPeakHours) < 0.02)
}

@Test func peakIsAbout90PercentOfDose() {
    #expect(abs(model.amount(dose: 100, hoursSince: model.timeToPeakHours) - 90.3) < 0.5)
}

@Test func lateDecayMatchesPureElimination() {
    // À 10 h, 100·e^(−ln2·10/5) = 25 mg ; l'absorption est terminée depuis longtemps.
    #expect(abs(model.amount(dose: 100, hoursSince: 10) - 25.0) < 0.3)
}

@Test func halfLifeChangesElimination() {
    let fast = PharmacokineticModel(halfLifeHours: 2.5)
    #expect(fast.amount(dose: 100, hoursSince: 10) < model.amount(dose: 100, hoursSince: 10))
}

@Test func dosesSuperpose() {
    let t0 = Date(timeIntervalSince1970: 0)
    let doses = [
        CaffeineDose(date: t0, milligrams: 100),
        CaffeineDose(date: t0.addingTimeInterval(3600), milligrams: 50),
    ]
    let at = t0.addingTimeInterval(2 * 3600)
    let expected = model.amount(dose: 100, hoursSince: 2) + model.amount(dose: 50, hoursSince: 1)
    #expect(abs(model.amount(doses: doses, at: at) - expected) < 1e-9)
}
```

- [ ] **Step 2 : `make test-core` → échec de compilation**

- [ ] **Step 3 : implémentation**

```swift
import Foundation

/// Modèle à un compartiment, absorption et élimination de premier ordre (courbe de Bateman).
/// Retourne des **mg dans l'organisme** (pas une concentration).
public struct PharmacokineticModel: Hashable, Sendable {
    /// Constante d'absorption ka (h⁻¹). Avec t½ = 5 h, tmax ≈ 44 min, dans la fourchette 30–60 min.
    /// Source: tmax caféine 30–60 min (EFSA 2015) ; ka choisi pour tmax = ln(ka/ke)/(ka−ke) ≈ 0,74 h.
    public static let absorptionRatePerHour = 5.0

    public let halfLifeHours: Double

    public init(halfLifeHours: Double) {
        self.halfLifeHours = halfLifeHours
    }

    /// ke = ln 2 / t½ (h⁻¹).
    public var eliminationRatePerHour: Double { log(2) / halfLifeHours }

    /// Instant du pic après une prise (h).
    public var timeToPeakHours: Double {
        let ka = Self.absorptionRatePerHour, ke = eliminationRatePerHour
        return log(ka / ke) / (ka - ke)
    }

    /// Quantité restante d'une dose `dose` mg prise il y a `t` heures.
    public func amount(dose: Double, hoursSince t: Double) -> Double {
        guard t > 0, dose > 0 else { return 0 }
        let ka = Self.absorptionRatePerHour, ke = eliminationRatePerHour
        return dose * ka / (ka - ke) * (exp(-ke * t) - exp(-ka * t))
    }

    /// Superposition linéaire de toutes les doses à l'instant `date`.
    public func amount(doses: [CaffeineDose], at date: Date) -> Double {
        doses.reduce(0) { total, dose in
            total + amount(dose: dose.milligrams, hoursSince: date.timeIntervalSince(dose.date) / 3600)
        }
    }
}
```

- [ ] **Step 4 : `make test-core` → vert**

- [ ] **Step 5 : commit**

```bash
git add Packages
git commit -m "feat(core): M1.3 Bateman pharmacokinetic model"
```

### Task M1.4 : Journée caféine et heure de coucher (`CaffeineDay`)

**Files:**
- Create: `Packages/KaffCore/Sources/KaffCore/Assessment/CaffeineDay.swift`
- Create: `Packages/KaffCore/Tests/KaffCoreTests/Support/TestClock.swift`
- Test: `Packages/KaffCore/Tests/KaffCoreTests/CaffeineDayTests.swift`

- [ ] **Step 1 : support de test + tests**

`Tests/KaffCoreTests/Support/TestClock.swift` :
```swift
import Foundation

/// Calendrier UTC déterministe pour les tests.
enum TestClock {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// 2026-08-`day` à `hour`:`minute` UTC.
    static func date(day: Int = 10, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: day, hour: hour, minute: minute))!
    }
}
```

`Tests/KaffCoreTests/CaffeineDayTests.swift` :
```swift
import Foundation
import Testing
@testable import KaffCore

private let day = CaffeineDay(calendar: TestClock.calendar)

@Test func dayStartsAtFourInTheMorning() {
    #expect(day.start(containing: TestClock.date(14)) == TestClock.date(4))
    #expect(day.start(containing: TestClock.date(4)) == TestClock.date(4))
    // 01:00 appartient encore à la journée de la veille
    #expect(day.start(containing: TestClock.date(1)) == TestClock.date(day: 9, 4))
}

@Test func bedtimeLaterToday() {
    let bed = ClockTime(hour: 23, minute: 0)
    #expect(day.nextBedtime(bed, after: TestClock.date(20, 15)) == TestClock.date(23))
}

@Test func bedtimeAlreadyPassedIsNow() {
    let bed = ClockTime(hour: 23, minute: 0)
    let lateEvening = TestClock.date(23, 30)
    #expect(day.nextBedtime(bed, after: lateEvening) == lateEvening)
    let lateNight = TestClock.date(day: 11, 1, 0)
    #expect(day.nextBedtime(bed, after: lateNight) == lateNight)
}

@Test func bedtimeAfterMidnightIsTomorrow() {
    let bed = ClockTime(hour: 0, minute: 30)
    #expect(day.nextBedtime(bed, after: TestClock.date(22)) == TestClock.date(day: 11, 0, 30))
}
```

- [ ] **Step 2 : `make test-core` → échec de compilation**

- [ ] **Step 3 : implémentation**

```swift
import Foundation

/// Découpage de la journée « caféine » : elle commence à 04:00, pas à minuit.
public struct CaffeineDay: Sendable {
    /// Source: choix produit — une soirée tardive ne remet pas le cumul à zéro à minuit.
    public static let startHour = 4

    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Début (04:00) de la journée caféine contenant `date`.
    public func start(containing date: Date) -> Date {
        let hour = calendar.component(.hour, from: date)
        let base = hour >= Self.startHour ? date : calendar.date(byAdding: .day, value: -1, to: date)!
        return calendar.date(bySettingHour: Self.startHour, minute: 0, second: 0, of: base)!
    }

    /// Prochaine heure de coucher. Si elle est déjà passée dans la journée caféine courante, retourne `now`.
    public func nextBedtime(_ bedtime: ClockTime, after now: Date) -> Date {
        let nowMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let dayStart = Self.startHour * 60
        let nowRel = (nowMinutes - dayStart + 1440) % 1440
        let bedRel = (bedtime.minutesOfDay - dayStart + 1440) % 1440
        guard nowRel < bedRel else { return now }
        let target = now.addingTimeInterval(Double(bedRel - nowRel) * 60)
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: target)
        return calendar.date(from: comps)!
    }
}
```

- [ ] **Step 4 : `make test-core` → vert**

- [ ] **Step 5 : commit**

```bash
git add Packages
git commit -m "feat(core): M1.4 caffeine day boundaries and next bedtime"
```

### Task M1.5 : Évaluation du niveau (`LevelAssessor`)

**Files:**
- Create: `Packages/KaffCore/Sources/KaffCore/Assessment/LevelAssessment.swift`
- Create: `Packages/KaffCore/Sources/KaffCore/Assessment/LevelAssessor.swift`
- Test: `Packages/KaffCore/Tests/KaffCoreTests/LevelAssessorTests.swift`

- [ ] **Step 1 : tests** (profil par défaut : 70 kg → limite ponctuelle 200 mg, 400 mg/jour, 50 mg au coucher 23:00, t½ 5 h)

```swift
import Foundation
import Testing
@testable import KaffCore

private func assessor(_ mutate: (inout UserProfile) -> Void = { _ in }) -> LevelAssessor {
    var p = UserProfile.default
    mutate(&p)
    return LevelAssessor(profile: p, calendar: TestClock.calendar)
}

@Test func noDosesIsOkAndSleepReadyNow() {
    let now = TestClock.date(10)
    let a = assessor().assess(doses: [], at: now)
    #expect(a.currentMg == 0)
    #expect(a.dailyTotalMg == 0)
    #expect(a.status == .ok)
    #expect(a.reason == .none)
    #expect(a.sleepReadyAt == now)
    #expect(a.isSleepReady)
}

@Test func bigDoseOneHourAgoIsHighForPeak() {
    let now = TestClock.date(10)
    let a = assessor().assess(doses: [CaffeineDose(date: TestClock.date(9), milligrams: 250)], at: now)
    #expect(abs(a.currentMg - 222) < 2)          // 250 × 0,889 (voir modèle PK à t = 1 h)
    #expect(a.peakStatus == .high)
    #expect(a.reason == .peak)
}

@Test func mediumDoseIsElevatedForPeak() {
    let now = TestClock.date(10)
    let a = assessor().assess(doses: [CaffeineDose(date: TestClock.date(9), milligrams: 150)], at: now)
    #expect(a.peakStatus == .elevated)           // 133 mg / 200 = 0,67 ≥ 0,6
    #expect(a.status == .elevated)
}

@Test func dailyTotalCountsSinceFourAM() {
    let now = TestClock.date(20)
    let doses = [
        CaffeineDose(date: TestClock.date(day: 9, 23), milligrams: 100),  // veille, hors journée
        CaffeineDose(date: TestClock.date(2), milligrams: 50),            // 02:00 → journée de la veille
        CaffeineDose(date: TestClock.date(8), milligrams: 140),
        CaffeineDose(date: TestClock.date(10), milligrams: 140),
        CaffeineDose(date: TestClock.date(12), milligrams: 140),
        CaffeineDose(date: TestClock.date(21), milligrams: 999),          // futur, ignoré
    ]
    let a = assessor { $0.bedtimeLimitMg = 100 }.assess(doses: doses, at: now)
    #expect(a.dailyTotalMg == 420)
    #expect(a.dailyStatus == .high)
    #expect(a.peakStatus == .ok)                 // ≈ 108 mg / 200
    #expect(a.bedtimeStatus == .elevated)        // ≈ 71 mg / 100
    #expect(a.reason == .daily)
}

@Test func bedtimeProjectionAndSleepReady() {
    let now = TestClock.date(20)
    let a = assessor().assess(doses: [CaffeineDose(date: TestClock.date(19), milligrams: 200)], at: now)
    #expect(a.bedtime == TestClock.date(23))
    #expect(abs(a.projectedBedtimeMg - 118) < 2)  // 200 × 0,59 à t = 4 h
    #expect(a.bedtimeStatus == .high)
    #expect(a.reason == .bedtime)
    // < 50 mg à t ≈ 10,2 h après 19:00 → ≈ 05:12
    let expected = TestClock.date(19).addingTimeInterval(10.204 * 3600)
    #expect(abs(a.sleepReadyAt.timeIntervalSince(expected)) < 120)
    #expect(!a.isSleepReady)
}

@Test func afterBedtimeProjectionIsCurrentLevel() {
    let now = TestClock.date(23, 30)
    let a = assessor().assess(doses: [CaffeineDose(date: TestClock.date(22), milligrams: 100)], at: now)
    #expect(a.bedtime == now)
    #expect(a.projectedBedtimeMg == a.currentMg)
}

@Test func sleepReadyIsAfterPeakEvenIfCurrentlyLow() {
    let now = TestClock.date(20)
    let a = assessor().assess(doses: [CaffeineDose(date: now, milligrams: 100)], at: now)
    #expect(a.currentMg == 0)
    #expect(a.sleepReadyAt > now)
}

@Test func priorityWhenTwoChecksAreHighIsPeakThenBedtimeThenDaily() {
    let now = TestClock.date(22)
    let a = assessor().assess(doses: [CaffeineDose(date: TestClock.date(21), milligrams: 300)], at: now)
    #expect(a.peakStatus == .high && a.bedtimeStatus == .high)
    #expect(a.reason == .peak)
}
```

- [ ] **Step 2 : `make test-core` → échec de compilation**

- [ ] **Step 3 : implémentation**

`Assessment/LevelAssessment.swift` :
```swift
import Foundation

public enum LevelReason: Hashable, Sendable {
    case none, peak, daily, bedtime
}

/// Résultat d'une évaluation à un instant donné.
public struct LevelAssessment: Hashable, Sendable {
    public let now: Date
    public let currentMg: Double
    public let dailyTotalMg: Double
    public let bedtime: Date
    public let projectedBedtimeMg: Double
    /// Premier instant (≥ `now`) où le niveau passe sous le seuil de coucher. `== now` si c'est déjà le cas.
    public let sleepReadyAt: Date
    public let peakStatus: LevelStatus
    public let dailyStatus: LevelStatus
    public let bedtimeStatus: LevelStatus

    public var status: LevelStatus { max(peakStatus, max(dailyStatus, bedtimeStatus)) }

    /// Vérification qui impose le statut (priorité pic > coucher > journée).
    public var reason: LevelReason {
        guard status != .ok else { return .none }
        if peakStatus == status { return .peak }
        if bedtimeStatus == status { return .bedtime }
        return .daily
    }

    public var isSleepReady: Bool { sleepReadyAt <= now }
}
```

`Assessment/LevelAssessor.swift` :
```swift
import Foundation

/// Applique les trois vérifications de la spec §5 à un jeu de doses.
public struct LevelAssessor: Sendable {
    /// Source: choix produit — fractions à partir desquelles on prévient avant le dépassement.
    public static let elevatedPeakFraction = 0.6
    public static let elevatedDailyFraction = 0.75
    public static let elevatedBedtimeFraction = 0.6
    /// Horizon de recherche de `sleepReadyAt`.
    static let sleepSearchHorizonHours = 72.0

    public let profile: UserProfile
    public let model: PharmacokineticModel
    public let day: CaffeineDay

    public init(profile: UserProfile, calendar: Calendar = .current) {
        self.profile = profile
        self.model = PharmacokineticModel(halfLifeHours: profile.halfLifeHours)
        self.day = CaffeineDay(calendar: calendar)
    }

    public func assess(doses: [CaffeineDose], at now: Date) -> LevelAssessment {
        let past = doses.filter { $0.date <= now }
        let current = model.amount(doses: past, at: now)
        let dayStart = day.start(containing: now)
        let dailyTotal = past.filter { $0.date >= dayStart }.reduce(0) { $0 + $1.milligrams }
        let bedtime = day.nextBedtime(profile.bedtime, after: now)
        let projected = model.amount(doses: past, at: bedtime)
        return LevelAssessment(
            now: now,
            currentMg: current,
            dailyTotalMg: dailyTotal,
            bedtime: bedtime,
            projectedBedtimeMg: projected,
            sleepReadyAt: sleepReadyDate(doses: past, from: now),
            peakStatus: LevelStatus(ratio: current / profile.singleDoseLimitMg, elevatedAt: Self.elevatedPeakFraction),
            dailyStatus: LevelStatus(ratio: dailyTotal / profile.dailyLimitMg, elevatedAt: Self.elevatedDailyFraction),
            bedtimeStatus: LevelStatus(ratio: projected / profile.bedtimeLimitMg, elevatedAt: Self.elevatedBedtimeFraction)
        )
    }

    /// Après le dernier pic la courbe est strictement décroissante : recherche par dichotomie à la minute près.
    public func sleepReadyDate(doses: [CaffeineDose], from now: Date) -> Date {
        let limit = profile.bedtimeLimitMg
        guard let lastDose = doses.map(\.date).max() else { return now }
        let lastPeak = lastDose.addingTimeInterval(model.timeToPeakHours * 3600)
        let start = max(now, lastPeak)
        guard model.amount(doses: doses, at: start) >= limit else { return start }
        var low = start
        var high = start.addingTimeInterval(Self.sleepSearchHorizonHours * 3600)
        guard model.amount(doses: doses, at: high) < limit else { return high }
        while high.timeIntervalSince(low) > 60 {
            let mid = low.addingTimeInterval(high.timeIntervalSince(low) / 2)
            if model.amount(doses: doses, at: mid) < limit { high = mid } else { low = mid }
        }
        return high
    }
}
```

- [ ] **Step 4 : `make test-core` → vert**

- [ ] **Step 5 : commit**

```bash
git add Packages
git commit -m "feat(core): M1.5 level assessor (peak, daily, bedtime, sleep-ready)"
```

### Task M1.6 : Timeline (`TimelineBuilder`)

**Files:**
- Create: `Packages/KaffCore/Sources/KaffCore/Timeline/TimelinePoint.swift`
- Create: `Packages/KaffCore/Sources/KaffCore/Timeline/TimelineBuilder.swift`
- Test: `Packages/KaffCore/Tests/KaffCoreTests/TimelineBuilderTests.swift`

- [ ] **Step 1 : tests**

```swift
import Foundation
import Testing
@testable import KaffCore

private let builder = TimelineBuilder(assessor: LevelAssessor(profile: .default, calendar: TestClock.calendar))

@Test func chartPointsCoverRangeWithStep() {
    let start = TestClock.date(8)
    let points = builder.chartPoints(doses: [], from: start, hours: 2, stepMinutes: 30)
    #expect(points.count == 5)
    #expect(points.first?.date == start)
    #expect(points.last?.date == start.addingTimeInterval(2 * 3600))
    #expect(points.allSatisfy { $0.milligrams == 0 && $0.status == .ok })
}

@Test func widgetGridWithoutDosesIsEvery15Minutes() {
    let now = TestClock.date(8)
    let dates = builder.widgetEntryDates(doses: [], from: now)
    #expect(dates.count == 49)
    #expect(dates.first == now)
    #expect(dates.last == now.addingTimeInterval(12 * 3600))
}

@Test func widgetEntriesIncludeStatusTransitions() {
    let now = TestClock.date(8)
    let doses = [CaffeineDose(date: now, milligrams: 250)]
    let dates = builder.widgetEntryDates(doses: doses, from: now)
    let grid = Set(builder.widgetEntryDates(doses: [], from: now))
    let extras = dates.filter { !grid.contains($0) }
    #expect(!extras.isEmpty)
    #expect(dates == dates.sorted() && Set(dates).count == dates.count)
    let assessor = builder.assessor
    for d in extras {
        let before = assessor.assess(doses: doses, at: d.addingTimeInterval(-60))
        let after = assessor.assess(doses: doses, at: d)
        let changed = before.status != after.status || before.isSleepReady != after.isSleepReady
        #expect(changed, "entrée \(d) sans transition")
    }
}
```

- [ ] **Step 2 : `make test-core` → échec de compilation**

- [ ] **Step 3 : implémentation**

`Timeline/TimelinePoint.swift` :
```swift
import Foundation

public struct TimelinePoint: Hashable, Sendable, Identifiable {
    public var id: Date { date }
    public let date: Date
    public let milligrams: Double
    public let status: LevelStatus

    public init(date: Date, milligrams: Double, status: LevelStatus) {
        self.date = date
        self.milligrams = milligrams
        self.status = status
    }
}
```

`Timeline/TimelineBuilder.swift` :
```swift
import Foundation

/// Échantillonne la courbe pour le graphique et calcule les instants d'entrée du widget.
public struct TimelineBuilder: Sendable {
    public static let widgetHours = 12.0
    public static let widgetStepMinutes = 15

    public let assessor: LevelAssessor

    public init(assessor: LevelAssessor) {
        self.assessor = assessor
    }

    public func chartPoints(doses: [CaffeineDose], from start: Date, hours: Double, stepMinutes: Int) -> [TimelinePoint] {
        let step = TimeInterval(stepMinutes * 60)
        let count = Int(hours * 3600 / step)
        return (0...count).map { i in
            let date = start.addingTimeInterval(Double(i) * step)
            let a = assessor.assess(doses: doses, at: date)
            return TimelinePoint(date: date, milligrams: a.currentMg, status: a.status)
        }
    }

    /// Grille régulière + un instant à chaque changement de statut ou de « prêt pour dormir ».
    public func widgetEntryDates(doses: [CaffeineDose], from now: Date,
                                 hours: Double = widgetHours, stepMinutes: Int = widgetStepMinutes) -> [Date] {
        let step = TimeInterval(stepMinutes * 60)
        let end = now.addingTimeInterval(hours * 3600)
        let grid = stride(from: 0.0, through: hours * 3600, by: step).map { now.addingTimeInterval($0) }
        var transitions: [Date] = []
        var previous = signature(doses: doses, at: now)
        var t = now.addingTimeInterval(60)
        while t <= end {
            let current = signature(doses: doses, at: t)
            if current != previous { transitions.append(t) }
            previous = current
            t = t.addingTimeInterval(60)
        }
        return Array(Set(grid + transitions)).sorted()
    }

    private func signature(doses: [CaffeineDose], at date: Date) -> (LevelStatus, Bool) {
        let a = assessor.assess(doses: doses, at: date)
        return (a.status, a.isSleepReady)
    }
}

private func != (lhs: (LevelStatus, Bool), rhs: (LevelStatus, Bool)) -> Bool {
    lhs.0 != rhs.0 || lhs.1 != rhs.1
}
```

- [ ] **Step 4 : `make test-core` → vert**

- [ ] **Step 5 : commit**

```bash
git add Packages
git commit -m "feat(core): M1.6 timeline builder with threshold transitions"
```

### Task M1.7 : Persistance App Group (`CacheStore`, `ProfileStore`)

**Files:**
- Create: `Packages/KaffCore/Sources/KaffCore/Persistence/AppGroup.swift`
- Create: `Packages/KaffCore/Sources/KaffCore/Persistence/CacheSnapshot.swift`
- Create: `Packages/KaffCore/Sources/KaffCore/Persistence/CacheStore.swift`
- Create: `Packages/KaffCore/Sources/KaffCore/Persistence/ProfileStore.swift`
- Test: `Packages/KaffCore/Tests/KaffCoreTests/CacheStoreTests.swift`
- Test: `Packages/KaffCore/Tests/KaffCoreTests/ProfileStoreTests.swift`

- [ ] **Step 1 : tests**

`CacheStoreTests.swift` :
```swift
import Foundation
import Testing
@testable import KaffCore

private func freshDefaults() -> UserDefaults {
    let name = "kaff.tests.\(UUID().uuidString)"
    let d = UserDefaults(suiteName: name)!
    d.removePersistentDomain(forName: name)
    return d
}

@Test func cacheRoundTrip() throws {
    let store = CacheStore(defaults: freshDefaults())
    #expect(store.read() == nil)
    let snapshot = CacheSnapshot(
        doses: [CaffeineDose(date: TestClock.date(9), milligrams: 63, drinkID: "espresso", volumeML: 30)],
        profile: .default,
        updatedAt: TestClock.date(10))
    try store.write(snapshot)
    #expect(store.read() == snapshot)
    store.clear()
    #expect(store.read() == nil)
}

@Test func corruptedCacheReadsAsNil() {
    let defaults = freshDefaults()
    defaults.set(Data("garbage".utf8), forKey: CacheStore.key)
    #expect(CacheStore(defaults: defaults).read() == nil)
}
```

`ProfileStoreTests.swift` :
```swift
import Foundation
import Testing
@testable import KaffCore

private func freshDefaults() -> UserDefaults {
    let name = "kaff.tests.\(UUID().uuidString)"
    let d = UserDefaults(suiteName: name)!
    d.removePersistentDomain(forName: name)
    return d
}

@Test func profileDefaultsWhenEmpty() {
    let store = ProfileStore(defaults: freshDefaults())
    #expect(store.loadProfile() == .default)
    #expect(store.loadCustomDrinks().isEmpty)
}

@Test func profileRoundTripIsClamped() throws {
    let store = ProfileStore(defaults: freshDefaults())
    var p = UserProfile.default
    p.manualWeightKg = 500
    p.bedtime = ClockTime(hour: 22, minute: 15)
    try store.save(p)
    let loaded = store.loadProfile()
    #expect(loaded.weightKg == UserProfile.Bounds.weightKg.upperBound)
    #expect(loaded.bedtime == ClockTime(hour: 22, minute: 15))
}

@Test func customDrinksRoundTrip() throws {
    let store = ProfileStore(defaults: freshDefaults())
    let drink = Drink(id: "custom-abc", name: "Cold brew", milligrams: 200, volumeML: 300, symbol: "mug.fill", isCustom: true)
    try store.saveCustomDrinks([drink])
    #expect(store.loadCustomDrinks() == [drink])
}
```

- [ ] **Step 2 : `make test-core` → échec de compilation**

- [ ] **Step 3 : implémentation**

`Persistence/AppGroup.swift` :
```swift
import Foundation

/// Conteneur partagé entre l'app et la complication.
public enum AppGroup {
    public static let identifier = "group.fr.batum.kaff"

    /// `nil` si l'entitlement App Groups manque (erreur de configuration, pas d'état normal).
    public static var defaults: UserDefaults? { UserDefaults(suiteName: identifier) }
}
```

`Persistence/CacheSnapshot.swift` :
```swift
import Foundation

/// Ce que le widget a besoin de connaître : les doses récentes et le profil.
public struct CacheSnapshot: Hashable, Codable, Sendable {
    public let doses: [CaffeineDose]
    public let profile: UserProfile
    public let updatedAt: Date

    public init(doses: [CaffeineDose], profile: UserProfile, updatedAt: Date) {
        self.doses = doses
        self.profile = profile
        self.updatedAt = updatedAt
    }
}
```

`Persistence/CacheStore.swift` :
```swift
import Foundation

/// Snapshot JSON dans les `UserDefaults` de l'App Group. Écrit par l'app, lu par le widget.
public struct CacheStore: Sendable {
    public static let key = "cache.snapshot.v1"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func read() -> CacheSnapshot? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(CacheSnapshot.self, from: data)
    }

    public func write(_ snapshot: CacheSnapshot) throws {
        defaults.set(try JSONEncoder().encode(snapshot), forKey: Self.key)
    }

    public func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}
```

`Persistence/ProfileStore.swift` :
```swift
import Foundation

/// Réglages et boissons personnalisées, dans l'App Group.
public struct ProfileStore: Sendable {
    static let profileKey = "profile.v1"
    static let customDrinksKey = "customDrinks.v1"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func loadProfile() -> UserProfile {
        guard let data = defaults.data(forKey: Self.profileKey),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else { return .default }
        return profile.clamped()
    }

    public func save(_ profile: UserProfile) throws {
        defaults.set(try JSONEncoder().encode(profile.clamped()), forKey: Self.profileKey)
    }

    public func loadCustomDrinks() -> [Drink] {
        guard let data = defaults.data(forKey: Self.customDrinksKey),
              let drinks = try? JSONDecoder().decode([Drink].self, from: data) else { return [] }
        return drinks
    }

    public func saveCustomDrinks(_ drinks: [Drink]) throws {
        defaults.set(try JSONEncoder().encode(drinks), forKey: Self.customDrinksKey)
    }
}
```

- [ ] **Step 4 : `make test-core` → vert**

- [ ] **Step 5 : couverture**

Run: `cd Packages/KaffCore && swift test --enable-code-coverage && xcrun llvm-cov report .build/debug/KaffCorePackageTests.xctest/Contents/MacOS/KaffCorePackageTests -instr-profile .build/debug/codecov/default.profdata -ignore-filename-regex='Tests|\.build' | tail -3`
Expected: ligne `TOTAL` avec `Lines` ≥ 90 %. Sinon ajouter les tests manquants avant de continuer.

- [ ] **Step 6 : commit**

```bash
git add Packages
git commit -m "feat(core): M1.7 app-group cache and profile stores"
```

Mettre à jour `docs/ROADMAP.md` : M1 ✅ (noter la couverture obtenue dans le journal).

---

## M2 — Services (cible `Kaff Watch App`)

### Task M2.1 : Protocole `HealthStore` et implémentation HealthKit

**Files:**
- Create: `Kaff Watch App/Services/HealthStore.swift`
- Create: `Kaff Watch App/Services/HealthKitStore.swift`
- Create: `Kaff Watch App/Services/WidgetReloader.swift`

Pas de test unitaire direct de `HealthKitStore` (HealthKit n'est pas mockable) : il est vérifié sur simulateur à la Task M2.3 et couvert par un protocole pour le reste.

- [ ] **Step 1 : protocole**

`Services/HealthStore.swift` :
```swift
import Foundation
import KaffCore

/// Abstraction de HealthKit pour les doses de caféine et le poids.
protocol HealthStore: Sendable {
    var isAvailable: Bool { get }
    /// `true` si l'utilisateur a autorisé l'écriture des doses (le statut de lecture est masqué par HealthKit).
    var isWriteAuthorized: Bool { get }
    func requestAuthorization() async throws
    func doses(from start: Date, to end: Date) async throws -> [CaffeineDose]
    /// Retourne la dose telle qu'enregistrée (l'`id` devient l'UUID HealthKit).
    func save(_ dose: CaffeineDose) async throws -> CaffeineDose
    func delete(doseID: UUID) async throws
    func latestBodyMassKg() async throws -> Double?
}
```

- [ ] **Step 2 : implémentation HealthKit**

`Services/HealthKitStore.swift` :
```swift
import Foundation
import HealthKit
import KaffCore

/// Implémentation HealthKit. `HKHealthStore` est thread-safe (documentation Apple) mais pas annoté `Sendable`.
final class HealthKitStore: HealthStore, @unchecked Sendable {
    enum MetadataKey {
        static let drinkID = "fr.batum.kaff.drinkID"
        static let volumeML = "fr.batum.kaff.volumeML"
        static let source = "fr.batum.kaff.source"
    }

    private let store = HKHealthStore()
    private let caffeineType = HKQuantityType(.dietaryCaffeine)
    private let bodyMassType = HKQuantityType(.bodyMass)
    private let milligram = HKUnit.gramUnit(with: .milli)

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    var isWriteAuthorized: Bool { store.authorizationStatus(for: caffeineType) == .sharingAuthorized }

    func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: [caffeineType], read: [caffeineType, bodyMassType])
    }

    func doses(from start: Date, to end: Date) async throws -> [CaffeineDose] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: caffeineType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)])
        return try await descriptor.result(for: store).map(dose(from:))
    }

    func save(_ dose: CaffeineDose) async throws -> CaffeineDose {
        var metadata: [String: Any] = [MetadataKey.source: dose.drinkID == nil ? "manual" : "drink"]
        if let drinkID = dose.drinkID { metadata[MetadataKey.drinkID] = drinkID }
        if let volume = dose.volumeML { metadata[MetadataKey.volumeML] = volume }
        let sample = HKQuantitySample(
            type: caffeineType,
            quantity: HKQuantity(unit: milligram, doubleValue: dose.milligrams),
            start: dose.date, end: dose.date, metadata: metadata)
        try await store.save(sample)
        return self.dose(from: sample)
    }

    func delete(doseID: UUID) async throws {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: caffeineType, predicate: HKQuery.predicateForObject(with: doseID))],
            sortDescriptors: [])
        guard let sample = try await descriptor.result(for: store).first else { return }
        try await store.delete(sample)
    }

    func latestBodyMassKg() async throws -> Double? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: bodyMassType)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1)
        return try await descriptor.result(for: store).first?.quantity.doubleValue(for: .gramUnit(with: .kilo))
    }

    private func dose(from sample: HKQuantitySample) -> CaffeineDose {
        CaffeineDose(
            id: sample.uuid,
            date: sample.startDate,
            milligrams: sample.quantity.doubleValue(for: milligram),
            drinkID: sample.metadata?[MetadataKey.drinkID] as? String,
            volumeML: sample.metadata?[MetadataKey.volumeML] as? Double)
    }
}
```

- [ ] **Step 3 : rechargement du widget**

`Services/WidgetReloader.swift` :
```swift
import WidgetKit

/// Permet d'espionner le rechargement des complications dans les tests.
protocol WidgetReloader: Sendable {
    func reloadAll()
}

struct WidgetCenterReloader: WidgetReloader {
    func reloadAll() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
```

- [ ] **Step 4 : `make build` → OK**

- [ ] **Step 5 : commit**

```bash
git add "Kaff Watch App/Services"
git commit -m "feat(app): M2.1 HealthStore protocol, HealthKit implementation, widget reloader"
```

### Task M2.2 : `AppModel` (orchestration) avec tests

**Files:**
- Create: `Kaff Watch App/App/Route.swift`
- Create: `Kaff Watch App/App/AppModel.swift`
- Create: `KaffTests/Mocks/MockHealthStore.swift`
- Create: `KaffTests/Mocks/SpyWidgetReloader.swift`
- Create: `KaffTests/AppModelTests.swift`
- Delete: `KaffTests/SmokeTests.swift`

- [ ] **Step 1 : mocks et tests**

`KaffTests/Mocks/MockHealthStore.swift` :
```swift
import Foundation
import KaffCore
@testable import Kaff_Watch_App

/// Tests séquentiels sur le MainActor : pas de synchronisation nécessaire.
final class MockHealthStore: HealthStore, @unchecked Sendable {
    var isAvailable = true
    var isWriteAuthorized = true
    var stored: [CaffeineDose] = []
    var bodyMassKg: Double? = 72
    var saveError: Error?
    var savedIDs: [UUID] = []
    var deletedIDs: [UUID] = []

    func requestAuthorization() async throws {}

    func doses(from start: Date, to end: Date) async throws -> [CaffeineDose] {
        stored.filter { $0.date >= start && $0.date <= end }
    }

    func save(_ dose: CaffeineDose) async throws -> CaffeineDose {
        if let saveError { throw saveError }
        stored.append(dose)
        savedIDs.append(dose.id)
        return dose
    }

    func delete(doseID: UUID) async throws {
        stored.removeAll { $0.id == doseID }
        deletedIDs.append(doseID)
    }

    func latestBodyMassKg() async throws -> Double? { bodyMassKg }
}
```

`KaffTests/Mocks/SpyWidgetReloader.swift` :
```swift
@testable import Kaff_Watch_App

final class SpyWidgetReloader: WidgetReloader, @unchecked Sendable {
    var reloadCount = 0
    func reloadAll() { reloadCount += 1 }
}
```

`KaffTests/AppModelTests.swift` :
```swift
import Foundation
import KaffCore
import Testing
@testable import Kaff_Watch_App

@MainActor
struct AppModelTests {
    let health = MockHealthStore()
    let widgets = SpyWidgetReloader()
    let defaults: UserDefaults
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    init() {
        let name = "kaff.apptests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
    }

    func makeModel() -> AppModel {
        AppModel(health: health, profileStore: ProfileStore(defaults: defaults),
                 cacheStore: CacheStore(defaults: defaults), widgets: widgets, now: { now })
    }

    @Test func startLoadsDosesAndWeight() async {
        health.stored = [CaffeineDose(date: now.addingTimeInterval(-3600), milligrams: 63, drinkID: "espresso", volumeML: 30)]
        let model = makeModel()
        await model.start()
        #expect(model.authorization == .authorized)
        #expect(model.doses.count == 1)
        #expect(model.profile.healthKitWeightKg == 72)
        #expect(model.profile.isWeightEstimated == false)
    }

    @Test func startDetectsDeniedAuthorization() async {
        health.isWriteAuthorized = false
        let model = makeModel()
        await model.start()
        #expect(model.authorization == .denied)
    }

    @Test func logSavesWritesCacheAndReloadsWidgets() async throws {
        let model = makeModel()
        await model.start()
        let espresso = DrinkCatalog.drink(id: "espresso", custom: [])!
        await model.log(milligrams: 126, drink: espresso, volumeML: 60)
        #expect(health.savedIDs.count == 1)
        #expect(model.doses.last?.drinkID == "espresso")
        let cache = try #require(CacheStore(defaults: defaults).read())
        #expect(cache.doses.count == 1)
        #expect(widgets.reloadCount >= 1)
        #expect(model.lastError == nil)
    }

    @Test func logFailureReportsErrorAndKeepsState() async {
        health.saveError = NSError(domain: "test", code: 1)
        let model = makeModel()
        await model.start()
        await model.log(milligrams: 50, drink: nil, volumeML: nil)
        #expect(model.doses.isEmpty)
        #expect(model.lastError != nil)
    }

    @Test func deleteRemovesDoseAndPublishes() async {
        let dose = CaffeineDose(date: now.addingTimeInterval(-600), milligrams: 95)
        health.stored = [dose]
        let model = makeModel()
        await model.start()
        let before = widgets.reloadCount
        await model.delete(dose)
        #expect(health.deletedIDs == [dose.id])
        #expect(model.doses.isEmpty)
        #expect(widgets.reloadCount == before + 1)
    }

    @Test func updateProfilePersistsAndReloads() async {
        let model = makeModel()
        await model.start()
        var p = model.profile
        p.halfLifeHours = 7
        await model.update(profile: p)
        #expect(ProfileStore(defaults: defaults).loadProfile().halfLifeHours == 7)
        #expect(model.assessment().now == now)
        #expect(widgets.reloadCount >= 1)
    }

    @Test func favoritesComeFromLoggedDrinks() async {
        health.stored = ["tea-black", "espresso", "espresso"].map {
            CaffeineDose(date: now.addingTimeInterval(-7200), milligrams: 50, drinkID: $0, volumeML: 100)
        }
        let model = makeModel()
        await model.start()
        #expect(model.favoriteDrinks.map(\.id) == ["espresso", "tea-black"])
    }
}
```

- [ ] **Step 2 : `make test` → échec de compilation**

- [ ] **Step 3 : implémentation**

`App/Route.swift` :
```swift
/// Destinations de navigation de l'app.
enum Route: Hashable {
    case logDrink
    case logManual
    case settings
}
```

`App/AppModel.swift` :
```swift
import Foundation
import KaffCore
import Observation
import os

/// État global de l'app : doses, profil, autorisation. Orchestration HealthKit → cache → widget.
@MainActor
@Observable
final class AppModel {
    enum AuthorizationState: Equatable { case unknown, authorized, denied, unavailable }

    static let historyDays = 30
    static let cacheHours = 24.0
    static let favoritesLimit = 4

    private(set) var authorization: AuthorizationState = .unknown
    private(set) var doses: [CaffeineDose] = []
    private(set) var profile: UserProfile
    private(set) var customDrinks: [Drink]
    private(set) var lastError: String?
    var path: [Route] = []

    private let health: any HealthStore
    private let profileStore: ProfileStore
    private let cacheStore: CacheStore
    private let widgets: any WidgetReloader
    private let calendar: Calendar
    private let now: @Sendable () -> Date
    private let logger = Logger(subsystem: "fr.batum.kaff", category: "AppModel")

    init(health: any HealthStore, profileStore: ProfileStore, cacheStore: CacheStore,
         widgets: any WidgetReloader, calendar: Calendar = .current,
         now: @escaping @Sendable () -> Date = { Date() }) {
        self.health = health
        self.profileStore = profileStore
        self.cacheStore = cacheStore
        self.widgets = widgets
        self.calendar = calendar
        self.now = now
        self.profile = profileStore.loadProfile()
        self.customDrinks = profileStore.loadCustomDrinks()
    }

    // MARK: Dérivés

    var assessor: LevelAssessor { LevelAssessor(profile: profile, calendar: calendar) }
    var allDrinks: [Drink] { DrinkCatalog.builtIn + customDrinks }

    var favoriteDrinks: [Drink] {
        DrinkCatalog.favoriteIDs(from: doses.compactMap(\.drinkID), limit: Self.favoritesLimit)
            .compactMap { DrinkCatalog.drink(id: $0, custom: customDrinks) }
    }

    func assessment(at date: Date? = nil) -> LevelAssessment {
        assessor.assess(doses: doses, at: date ?? now())
    }

    func drink(for dose: CaffeineDose) -> Drink? {
        dose.drinkID.flatMap { DrinkCatalog.drink(id: $0, custom: customDrinks) }
    }

    // MARK: Cycle de vie

    func start() async {
        guard health.isAvailable else { authorization = .unavailable; return }
        do { try await health.requestAuthorization() } catch { report("Autorisation Santé impossible", error) }
        authorization = health.isWriteAuthorized ? .authorized : .denied
        guard authorization == .authorized else { return }
        await refresh()
    }

    func refresh() async {
        let end = now()
        let start = calendar.date(byAdding: .day, value: -Self.historyDays, to: end) ?? end
        do {
            doses = try await health.doses(from: start, to: end)
            if let kg = try await health.latestBodyMassKg(), kg != profile.healthKitWeightKg {
                profile.healthKitWeightKg = kg
                try profileStore.save(profile)
            }
            publish()
        } catch {
            report("Lecture Santé impossible", error)
        }
    }

    // MARK: Actions

    func log(milligrams: Double, drink: Drink?, volumeML: Double?) async {
        let clamped = min(max(milligrams, UserProfile.Bounds.doseMg.lowerBound), UserProfile.Bounds.doseMg.upperBound)
        let dose = CaffeineDose(date: now(), milligrams: clamped, drinkID: drink?.id, volumeML: volumeML)
        do {
            let saved = try await health.save(dose)
            doses = (doses + [saved]).sorted { $0.date < $1.date }
            lastError = nil
            publish()
        } catch {
            report("Enregistrement impossible", error)
        }
    }

    func delete(_ dose: CaffeineDose) async {
        do {
            try await health.delete(doseID: dose.id)
            doses.removeAll { $0.id == dose.id }
            publish()
        } catch {
            report("Suppression impossible", error)
        }
    }

    func update(profile newProfile: UserProfile) async {
        profile = newProfile.clamped()
        do { try profileStore.save(profile) } catch { report("Sauvegarde des réglages impossible", error) }
        publish()
    }

    func save(customDrink: Drink) async {
        customDrinks = customDrinks.filter { $0.id != customDrink.id } + [customDrink]
        do { try profileStore.saveCustomDrinks(customDrinks) } catch { report("Sauvegarde de la boisson impossible", error) }
    }

    func deleteCustomDrink(id: String) async {
        customDrinks.removeAll { $0.id == id }
        do { try profileStore.saveCustomDrinks(customDrinks) } catch { report("Suppression de la boisson impossible", error) }
    }

    func clearError() { lastError = nil }

    // MARK: Privé

    /// Écrit le snapshot 24 h et demande le rechargement des complications.
    private func publish() {
        let cutoff = now().addingTimeInterval(-Self.cacheHours * 3600)
        let snapshot = CacheSnapshot(doses: doses.filter { $0.date >= cutoff }, profile: profile, updatedAt: now())
        do { try cacheStore.write(snapshot) } catch { report("Écriture du cache impossible", error) }
        widgets.reloadAll()
    }

    private func report(_ message: String, _ error: Error) {
        logger.error("\(message): \(error.localizedDescription, privacy: .public)")
        lastError = message
    }
}
```

- [ ] **Step 4 : `make test` → `** TEST SUCCEEDED **`, 7 tests**

- [ ] **Step 5 : commit**

```bash
git add "Kaff Watch App/App" KaffTests
git commit -m "feat(app): M2.2 AppModel orchestration with tests"
```

### Task M2.3 : Vérification HealthKit sur simulateur

**Files:**
- Modify: `Kaff Watch App/App/KaffApp.swift`

- [ ] **Step 1 : brancher `AppModel` et un écran de debug temporaire**

```swift
import KaffCore
import SwiftUI

@main
struct KaffApp: App {
    @State private var model = AppModel(
        health: HealthKitStore(),
        profileStore: ProfileStore(defaults: AppGroup.defaults ?? .standard),
        cacheStore: CacheStore(defaults: AppGroup.defaults ?? .standard),
        widgets: WidgetCenterReloader())

    var body: some Scene {
        WindowGroup {
            VStack {
                Text("Auth: \(String(describing: model.authorization))")
                Text("Doses: \(model.doses.count)")
                Text("\(Int(model.assessment().currentMg)) mg")
                Button("+63 mg") { Task { await model.log(milligrams: 63, drink: nil, volumeML: nil) } }
            }
            .task { await model.start() }
            .environment(model)
        }
    }
}
```

- [ ] **Step 2 : `make run`** — accepter la demande d'autorisation Santé sur le simulateur ; appuyer sur « +63 mg » ; relancer l'app.
Expected: « Auth: authorized », « Doses: 1 » persiste après relance, le nombre de mg monte puis redescend.
Si `AppGroup.defaults` est `nil` (visible en ajoutant un `print`), l'entitlement App Groups n'est pas embarqué : vérifier `project.yml`.

- [ ] **Step 3 : commit**

```bash
git add "Kaff Watch App/App/KaffApp.swift"
git commit -m "chore(app): M2.3 wire AppModel with HealthKit for simulator verification"
```

Mettre à jour `docs/ROADMAP.md` : M2 ✅.

---

## M3 — App Watch (SwiftUI)

Pas de tests unitaires pour les vues (spec §10) : chaque tâche se termine par une vérification sur simulateur. Les vues ne contiennent aucune logique métier — tout passe par `AppModel` et `KaffCore`.

### Task M3.1 : Racine, navigation, écran d'autorisation, helpers UI

**Files:**
- Modify: `Kaff Watch App/App/KaffApp.swift`
- Create: `Kaff Watch App/App/RootView.swift`
- Create: `Kaff Watch App/Features/Authorization/AuthorizationView.swift`
- Create: `Kaff Watch App/Shared/Formatters.swift`
- Create: `Kaff Watch App/Shared/LevelStatus+UI.swift`

- [ ] **Step 1 : helpers**

`Shared/Formatters.swift` :
```swift
import Foundation

enum Formatters {
    static func mg(_ value: Double) -> String { "\(Int(value.rounded())) mg" }
    static func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }
    static func count(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...1))) }
    static func ml(_ value: Double) -> String { "\(Int(value.rounded())) ml" }
}
```

`Shared/LevelStatus+UI.swift` :
```swift
import KaffCore
import SwiftUI

extension LevelStatus {
    var color: Color {
        switch self {
        case .ok: .green
        case .elevated: .orange
        case .high: .red
        }
    }

    var label: String {
        switch self {
        case .ok: "OK"
        case .elevated: "Élevé"
        case .high: "Trop haut"
        }
    }
}

extension LevelReason {
    var label: String {
        switch self {
        case .none: "Niveau correct"
        case .peak: "Pic trop haut"
        case .daily: "Cumul du jour dépassé"
        case .bedtime: "Trop pour bien dormir"
        }
    }
}
```

- [ ] **Step 2 : racine et app**

`App/RootView.swift` :
```swift
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.path) {
            content
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .logDrink: DrinkPickerView()
                    case .logManual: ManualDoseView()
                    case .settings: SettingsView()
                    }
                }
        }
        .task { await model.start() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, model.authorization == .authorized { Task { await model.refresh() } }
        }
        .onOpenURL { url in
            if url.scheme == "kaff", url.host == "log" { model.path = [.logDrink] }
        }
        .alert("Erreur", isPresented: Binding(get: { model.lastError != nil }, set: { if !$0 { model.clearError() } })) {
            Button("OK") {}
        } message: {
            Text(model.lastError ?? "")
        }
    }

    @ViewBuilder private var content: some View {
        switch model.authorization {
        case .unknown: ProgressView()
        case .authorized:
            TabView {
                HomeView()
                HistoryView()
            }
            .tabViewStyle(.verticalPage)
        case .denied, .unavailable: AuthorizationView()
        }
    }
}
```

`App/KaffApp.swift` (remplace l'écran de debug de M2.3) :
```swift
import KaffCore
import SwiftUI

@main
struct KaffApp: App {
    @State private var model = AppModel(
        health: HealthKitStore(),
        profileStore: ProfileStore(defaults: AppGroup.defaults ?? .standard),
        cacheStore: CacheStore(defaults: AppGroup.defaults ?? .standard),
        widgets: WidgetCenterReloader())

    var body: some Scene {
        WindowGroup {
            RootView().environment(model)
        }
    }
}
```

`Features/Authorization/AuthorizationView.swift` :
```swift
import SwiftUI

struct AuthorizationView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "heart.text.square").font(.title2).foregroundStyle(.red)
                Text(model.authorization == .unavailable ? "Santé indisponible" : "Accès Santé requis").font(.headline)
                Text("Kaff stocke vos doses de caféine dans Santé. Autorisez l'écriture de « Caféine » : Réglages › Santé › Apps › Kaff.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Réessayer") { Task { await model.start() } }
            }
        }
    }
}
```

- [ ] **Step 3 : stubs temporaires** pour compiler avant M3.2–M3.5 — créer chaque fichier de vue manquant avec `struct XView: View { var body: some View { Text("X") } }` : `HomeView`, `HistoryView`, `DrinkPickerView`, `ManualDoseView`, `SettingsView` aux chemins de la structure des fichiers. Ils sont remplacés dans les tâches suivantes.

- [ ] **Step 4 : `make run`** → écran Home stub après autorisation ; réinitialiser l'autorisation (Simulateur › Réglages › Santé) pour voir `AuthorizationView`.

- [ ] **Step 5 : commit**

```bash
git add "Kaff Watch App"
git commit -m "feat(app): M3.1 root navigation, authorization screen, UI helpers"
```

### Task M3.2 : Home — niveau live, statut, courbe

**Files:**
- Create: `Kaff Watch App/Features/Home/HomeView.swift`
- Create: `Kaff Watch App/Features/Home/LevelGaugeView.swift`
- Create: `Kaff Watch App/Features/Home/CaffeineChartView.swift`

- [ ] **Step 1 : jauge**

```swift
import KaffCore
import SwiftUI

struct LevelGaugeView: View {
    let assessment: LevelAssessment
    let limitMg: Double

    var body: some View {
        HStack(spacing: 10) {
            Gauge(value: min(assessment.currentMg, limitMg), in: 0...limitMg) {
                Text("mg")
            } currentValueLabel: {
                Image(systemName: "cup.and.saucer.fill").font(.caption2)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(assessment.status.color)
            VStack(alignment: .leading, spacing: 2) {
                Text(Formatters.mg(assessment.currentMg)).font(.title2.bold()).monospacedDigit()
                Text(assessment.status.label).font(.caption).foregroundStyle(assessment.status.color)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Formatters.mg(assessment.currentMg)), \(assessment.status.label)")
    }
}
```

- [ ] **Step 2 : courbe** (12 h passées, 6 h projetées, pas 10 min)

```swift
import Charts
import KaffCore
import SwiftUI

struct CaffeineChartView: View {
    static let pastHours = 12.0
    static let futureHours = 6.0
    static let stepMinutes = 10

    let doses: [CaffeineDose]
    let assessor: LevelAssessor
    let now: Date

    private var points: [TimelinePoint] {
        TimelineBuilder(assessor: assessor).chartPoints(
            doses: doses, from: now.addingTimeInterval(-Self.pastHours * 3600),
            hours: Self.pastHours + Self.futureHours, stepMinutes: Self.stepMinutes)
    }

    var body: some View {
        Chart {
            ForEach(points) { p in
                AreaMark(x: .value("Heure", p.date), y: .value("mg", p.milligrams))
                    .foregroundStyle(.linearGradient(colors: [.accentColor.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Heure", p.date), y: .value("mg", p.milligrams))
                    .foregroundStyle(p.date > now ? Color.secondary : Color.accentColor)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: p.date > now ? [3, 3] : []))
            }
            RuleMark(x: .value("Maintenant", now)).foregroundStyle(.secondary).lineStyle(StrokeStyle(lineWidth: 1))
            RuleMark(y: .value("Limite", assessor.profile.singleDoseLimitMg))
                .foregroundStyle(.red.opacity(0.5)).lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
        }
        .chartXAxis { AxisMarks(values: .stride(by: .hour, count: 6)) { _ in AxisValueLabel(format: .dateTime.hour()) } }
        .chartYAxis(.hidden)
        .frame(height: 70)
        .accessibilityLabel("Courbe de caféine sur 18 heures")
    }
}
```

- [ ] **Step 3 : Home**

```swift
import KaffCore
import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let a = model.assessment(at: context.date)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    LevelGaugeView(assessment: a, limitMg: model.profile.singleDoseLimitMg)
                    Text(a.reason.label).font(.footnote).foregroundStyle(a.status == .ok ? .secondary : a.status.color)
                    Label(sleepText(a), systemImage: "moon.zzz.fill").font(.caption2).foregroundStyle(.secondary)
                    HStack {
                        Text("Aujourd'hui").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Formatters.mg(a.dailyTotalMg)) / \(Formatters.mg(model.profile.dailyLimitMg))")
                            .font(.caption2).monospacedDigit().foregroundStyle(a.dailyStatus.color)
                    }
                    if model.profile.isWeightEstimated {
                        Label("Poids estimé (\(Int(model.profile.weightKg)) kg)", systemImage: "scalemass")
                            .font(.caption2).foregroundStyle(.orange)
                    }
                    CaffeineChartView(doses: model.doses, assessor: model.assessor, now: context.date)
                    HStack {
                        NavigationLink(value: Route.logDrink) { Label("Boisson", systemImage: "cup.and.saucer.fill") }
                        NavigationLink(value: Route.logManual) { Label("mg", systemImage: "number") }
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.caption)
                }
            }
        }
        .navigationTitle("Kaff")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Route.settings) { Image(systemName: "gearshape") }
            }
        }
    }

    private func sleepText(_ a: LevelAssessment) -> String {
        a.isSleepReady ? "OK pour dormir maintenant" : "OK pour dormir à \(Formatters.time(a.sleepReadyAt))"
    }
}
```

- [ ] **Step 4 : `make run`** → jauge, courbe, deux boutons. Avec une dose loguée en M2.3, la courbe montre le pic. Laisser l'app ouverte 2 min : le nombre change (décroissance live).

- [ ] **Step 5 : commit**

```bash
git add "Kaff Watch App/Features/Home"
git commit -m "feat(app): M3.2 home screen with live level, status and chart"
```

### Task M3.3 : QuickLog — boisson (grille + volume) et mg

**Files:**
- Create: `Kaff Watch App/Features/QuickLog/DrinkPickerView.swift`
- Create: `Kaff Watch App/Features/QuickLog/DrinkAmountView.swift`
- Create: `Kaff Watch App/Features/QuickLog/ManualDoseView.swift`

- [ ] **Step 1 : grille**

```swift
import KaffCore
import SwiftUI

struct DrinkPickerView: View {
    @Environment(AppModel.self) private var model

    private var ordered: [Drink] {
        let favorites = model.favoriteDrinks
        return favorites + model.allDrinks.filter { d in !favorites.contains { $0.id == d.id } }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(ordered) { drink in
                    NavigationLink(value: drink) {
                        VStack(spacing: 2) {
                            Image(systemName: drink.symbol).font(.title3)
                            Text(drink.name).font(.caption2).lineLimit(2).multilineTextAlignment(.center)
                            Text(Formatters.mg(drink.milligrams)).font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 64)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .navigationTitle("Boisson")
        .navigationDestination(for: Drink.self) { DrinkAmountView(drink: $0) }
    }
}
```

- [ ] **Step 2 : volume + confirmation**

```swift
import KaffCore
import SwiftUI
import WatchKit

struct DrinkAmountView: View {
    @Environment(AppModel.self) private var model
    let drink: Drink
    @State private var volumeML: Double
    @State private var isSaving = false

    init(drink: Drink) {
        self.drink = drink
        _volumeML = State(initialValue: drink.volumeML)
    }

    private var milligrams: Double { drink.milligrams(forVolumeML: volumeML) }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: drink.symbol).font(.title2)
            Text(drink.name).font(.headline)
            Text(Formatters.ml(volumeML)).font(.title3).monospacedDigit()
                .focusable()
                .digitalCrownRotation($volumeML, from: 10, through: 1000, by: 10, sensitivity: .medium, isContinuous: false)
            Text("≈ \(Formatters.mg(milligrams))").foregroundStyle(.secondary).monospacedDigit()
            Button {
                isSaving = true
                Task {
                    await model.log(milligrams: milligrams, drink: drink, volumeML: volumeML)
                    WKInterfaceDevice.current().play(model.lastError == nil ? .success : .failure)
                    model.path = []
                }
            } label: { Label("Ajouter", systemImage: "plus") }
            .buttonStyle(.borderedProminent)
            .disabled(isSaving)
        }
        .navigationTitle(drink.name)
    }
}
```

- [ ] **Step 3 : saisie manuelle en mg**

```swift
import KaffCore
import SwiftUI
import WatchKit

struct ManualDoseView: View {
    @Environment(AppModel.self) private var model
    @State private var milligrams = 80.0
    @State private var isSaving = false

    private var espressoEquivalent: String {
        guard let espresso = DrinkCatalog.drink(id: "espresso", custom: []) else { return "" }
        return "≈ \(Formatters.count(DrinkEquivalence.count(of: espresso, forMilligrams: milligrams))) espresso"
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(Formatters.mg(milligrams)).font(.title2.bold()).monospacedDigit()
                .focusable()
                .digitalCrownRotation($milligrams, from: 5, through: 1000, by: 5, sensitivity: .medium, isContinuous: false)
            Text(espressoEquivalent).foregroundStyle(.secondary)
            Button {
                isSaving = true
                Task {
                    await model.log(milligrams: milligrams, drink: nil, volumeML: nil)
                    WKInterfaceDevice.current().play(model.lastError == nil ? .success : .failure)
                    model.path = []
                }
            } label: { Label("Ajouter", systemImage: "plus") }
            .buttonStyle(.borderedProminent)
            .disabled(isSaving)
        }
        .navigationTitle("Dose")
    }
}
```

- [ ] **Step 4 : `make run`** → Boisson › Espresso › couronne change le volume et les mg › Ajouter → retour Home, niveau mis à jour, haptique. Idem via « mg ».

- [ ] **Step 5 : commit**

```bash
git add "Kaff Watch App/Features/QuickLog"
git commit -m "feat(app): M3.3 quick log by drink or milligrams"
```

### Task M3.4 : Historique

**Files:**
- Create: `Kaff Watch App/Features/History/HistoryView.swift`

- [ ] **Step 1 : vue**

```swift
import KaffCore
import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    static let days = 7

    private var sections: [(day: Date, doses: [CaffeineDose])] {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -Self.days, to: .now) ?? .now
        let grouped = Dictionary(grouping: model.doses.filter { $0.date >= cutoff }) { calendar.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0]!.sorted { $0.date > $1.date }) }
    }

    var body: some View {
        List {
            if sections.isEmpty {
                Text("Aucune dose sur 7 jours").foregroundStyle(.secondary)
            }
            ForEach(sections, id: \.day) { section in
                Section(section.day.formatted(.dateTime.weekday(.wide).day())) {
                    ForEach(section.doses) { dose in
                        HStack {
                            Text(Formatters.time(dose.date)).monospacedDigit()
                            Text(model.drink(for: dose)?.name ?? "Manuel").lineLimit(1)
                            Spacer()
                            Text(Formatters.mg(dose.milligrams)).foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                    .onDelete { offsets in
                        let toDelete = offsets.map { section.doses[$0] }
                        Task { for dose in toDelete { await model.delete(dose) } }
                    }
                }
            }
        }
        .navigationTitle("Historique")
    }
}
```

- [ ] **Step 2 : `make run`** → défiler vers le bas depuis Home : liste par jour ; swipe → supprimer ; retour Home : niveau recalculé.

- [ ] **Step 3 : commit**

```bash
git add "Kaff Watch App/Features/History"
git commit -m "feat(app): M3.4 history with swipe-to-delete"
```

### Task M3.5 : Réglages et boissons personnalisées

**Files:**
- Create: `Kaff Watch App/Features/Settings/SettingsView.swift`
- Create: `Kaff Watch App/Features/Settings/CustomDrinkEditorView.swift`

- [ ] **Step 1 : réglages**

```swift
import KaffCore
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var draft: UserProfile = .default
    @State private var bedtime = Date()
    @State private var useManualWeight = false

    var body: some View {
        Form {
            Section("Poids") {
                if let kg = draft.healthKitWeightKg {
                    Text("Santé : \(Int(kg)) kg").foregroundStyle(.secondary)
                }
                Toggle("Saisir manuellement", isOn: $useManualWeight)
                if useManualWeight {
                    Stepper(value: Binding(get: { draft.manualWeightKg ?? draft.weightKg }, set: { draft.manualWeightKg = $0 }),
                            in: UserProfile.Bounds.weightKg, step: 1) {
                        Text("\(Int(draft.manualWeightKg ?? draft.weightKg)) kg")
                    }
                }
            }
            Section("Modèle") {
                Stepper(value: $draft.halfLifeHours, in: UserProfile.Bounds.halfLifeHours, step: 0.5) {
                    Text("Demi-vie \(Formatters.count(draft.halfLifeHours)) h")
                }
            }
            Section("Sommeil") {
                DatePicker("Coucher", selection: $bedtime, displayedComponents: .hourAndMinute)
                Stepper(value: $draft.bedtimeLimitMg, in: UserProfile.Bounds.bedtimeLimitMg, step: 10) {
                    Text("Max au coucher \(Formatters.mg(draft.bedtimeLimitMg))")
                }
            }
            Section("Limites") {
                Stepper(value: $draft.dailyLimitMg, in: UserProfile.Bounds.dailyLimitMg, step: 25) {
                    Text("Par jour \(Formatters.mg(draft.dailyLimitMg))")
                }
                Text("Dose unique : \(Formatters.mg(draft.singleDoseLimitMg)) (3 mg/kg, max 200)").font(.caption2).foregroundStyle(.secondary)
            }
            Section {
                NavigationLink("Boissons personnalisées") { CustomDrinkEditorView() }
            }
            Section {
                Text("Estimation indicative. Ce n'est pas un avis médical.").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Réglages")
        .onAppear {
            draft = model.profile
            useManualWeight = draft.manualWeightKg != nil
            bedtime = Calendar.current.date(bySettingHour: draft.bedtime.hour, minute: draft.bedtime.minute, second: 0, of: .now) ?? .now
        }
        .onChange(of: useManualWeight) { _, on in if !on { draft.manualWeightKg = nil } }
        .onChange(of: bedtime) { _, date in
            let c = Calendar.current.dateComponents([.hour, .minute], from: date)
            draft.bedtime = ClockTime(hour: c.hour ?? 23, minute: c.minute ?? 0)
        }
        .onChange(of: draft) { _, new in Task { await model.update(profile: new) } }
    }
}
```

- [ ] **Step 2 : éditeur de boissons**

```swift
import KaffCore
import SwiftUI

struct CustomDrinkEditorView: View {
    @Environment(AppModel.self) private var model
    @State private var name = ""
    @State private var milligrams = 80.0
    @State private var volumeML = 250.0
    @State private var isAdding = false

    var body: some View {
        List {
            ForEach(model.customDrinks) { drink in
                HStack {
                    Text(drink.name).lineLimit(1)
                    Spacer()
                    Text("\(Formatters.mg(drink.milligrams)) / \(Formatters.ml(drink.volumeML))").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .onDelete { offsets in
                let ids = offsets.map { model.customDrinks[$0].id }
                Task { for id in ids { await model.deleteCustomDrink(id: id) } }
            }
            Button { isAdding = true } label: { Label("Nouvelle boisson", systemImage: "plus") }
        }
        .navigationTitle("Boissons")
        .sheet(isPresented: $isAdding) {
            Form {
                TextField("Nom", text: $name)
                Stepper(value: $milligrams, in: 1...500, step: 5) { Text(Formatters.mg(milligrams)) }
                Stepper(value: $volumeML, in: 10...1000, step: 10) { Text(Formatters.ml(volumeML)) }
                Button("Enregistrer") {
                    let drink = Drink(id: "custom-\(UUID().uuidString)", name: name.trimmingCharacters(in: .whitespaces),
                                      milligrams: milligrams, volumeML: volumeML, symbol: "mug.fill", isCustom: true)
                    Task { await model.save(customDrink: drink) }
                    name = ""
                    isAdding = false
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}
```

- [ ] **Step 3 : `make run`** → changer la demi-vie : le niveau Home change. Régler le coucher : « OK pour dormir à » change. Créer « Cold brew » : elle apparaît dans la grille Boisson.

- [ ] **Step 4 : commit**

```bash
git add "Kaff Watch App/Features/Settings"
git commit -m "feat(app): M3.5 settings and custom drinks"
```

### Task M3.6 : Parcours complet et captures

- [ ] **Step 1 : parcours** sur Series 11 (46 mm) puis Ultra 3 (49 mm) : réinitialiser l'app (`xcrun simctl uninstall "<SIM>" fr.batum.kaff.watchkitapp`), `make run`, autoriser, loguer un espresso et 100 mg manuels, vérifier statut/courbe/sommeil, supprimer une dose, changer un réglage, ouvrir `kaff://log` (`xcrun simctl openurl "<SIM>" "kaff://log"`) → arrive sur la grille Boisson.

- [ ] **Step 2 : captures**

```bash
mkdir -p docs/screenshots
for s in home drink amount history settings; do echo "naviguer vers $s puis Entrée"; read; xcrun simctl io "Apple Watch Series 11 (46mm)" screenshot docs/screenshots/m3-$s.png; done
```

- [ ] **Step 3 : commit**

```bash
git add docs/screenshots
git commit -m "docs: M3.6 simulator screenshots"
```

Mettre à jour `docs/ROADMAP.md` : M3 ✅.

---

## M4 — Complication WidgetKit

### Task M4.1 : Planificateur de timeline widget dans `KaffCore` (testable)

**Files:**
- Create: `Packages/KaffCore/Sources/KaffCore/Timeline/WidgetEntryData.swift`
- Create: `Packages/KaffCore/Sources/KaffCore/Timeline/WidgetTimelinePlanner.swift`
- Test: `Packages/KaffCore/Tests/KaffCoreTests/WidgetTimelinePlannerTests.swift`

- [ ] **Step 1 : tests**

```swift
import Foundation
import Testing
@testable import KaffCore

@Test func noSnapshotGivesSingleEmptyEntry() {
    let now = TestClock.date(8)
    let entries = WidgetTimelinePlanner.entries(snapshot: nil, now: now, calendar: TestClock.calendar)
    #expect(entries.count == 1)
    #expect(entries[0].date == now && entries[0].hasData == false && entries[0].milligrams == 0)
}

@Test func snapshotGivesGridAndTransitions() {
    let now = TestClock.date(8)
    let snapshot = CacheSnapshot(doses: [CaffeineDose(date: now, milligrams: 250)], profile: .default, updatedAt: now)
    let entries = WidgetTimelinePlanner.entries(snapshot: snapshot, now: now, calendar: TestClock.calendar)
    #expect(entries.count > 49)
    #expect(entries.first?.date == now)
    #expect(entries.allSatisfy { $0.hasData && $0.limitMg == 200 })
    let peak = entries.max { $0.milligrams < $1.milligrams }!
    #expect(peak.status == .high)
    #expect(entries.last!.milligrams < peak.milligrams)
}
```

- [ ] **Step 2 : `make test-core` → échec de compilation**

- [ ] **Step 3 : implémentation**

`Timeline/WidgetEntryData.swift` :
```swift
import Foundation

/// Tout ce qu'une entrée de complication doit afficher, précalculé.
public struct WidgetEntryData: Hashable, Sendable {
    public let date: Date
    public let milligrams: Double
    public let status: LevelStatus
    public let limitMg: Double
    public let sleepReadyAt: Date
    public let isSleepReady: Bool
    /// `false` quand aucun snapshot n'existe (app jamais ouverte).
    public let hasData: Bool

    public init(date: Date, milligrams: Double, status: LevelStatus, limitMg: Double,
                sleepReadyAt: Date, isSleepReady: Bool, hasData: Bool) {
        self.date = date
        self.milligrams = milligrams
        self.status = status
        self.limitMg = limitMg
        self.sleepReadyAt = sleepReadyAt
        self.isSleepReady = isSleepReady
        self.hasData = hasData
    }

    public static func empty(at date: Date) -> WidgetEntryData {
        WidgetEntryData(date: date, milligrams: 0, status: .ok, limitMg: UserProfile.default.singleDoseLimitMg,
                        sleepReadyAt: date, isSleepReady: true, hasData: false)
    }
}
```

`Timeline/WidgetTimelinePlanner.swift` :
```swift
import Foundation

/// Transforme un snapshot en liste d'entrées de complication (grille 15 min + transitions).
public enum WidgetTimelinePlanner {
    public static func entries(snapshot: CacheSnapshot?, now: Date, calendar: Calendar = .current) -> [WidgetEntryData] {
        guard let snapshot else { return [.empty(at: now)] }
        let assessor = LevelAssessor(profile: snapshot.profile, calendar: calendar)
        let dates = TimelineBuilder(assessor: assessor).widgetEntryDates(doses: snapshot.doses, from: now)
        return dates.map { date in
            let a = assessor.assess(doses: snapshot.doses, at: date)
            return WidgetEntryData(date: date, milligrams: a.currentMg, status: a.status,
                                   limitMg: snapshot.profile.singleDoseLimitMg,
                                   sleepReadyAt: a.sleepReadyAt, isSleepReady: a.isSleepReady, hasData: true)
        }
    }
}
```

- [ ] **Step 4 : `make test-core` → vert**

- [ ] **Step 5 : commit**

```bash
git add Packages
git commit -m "feat(core): M4.1 widget timeline planner"
```

### Task M4.2 : Extension WidgetKit — provider, vues, deep link

**Files:**
- Modify: `KaffComplication/KaffComplicationBundle.swift` (remplacer le placeholder)
- Create: `KaffComplication/CaffeineEntry.swift`
- Create: `KaffComplication/CaffeineTimelineProvider.swift`
- Create: `KaffComplication/CaffeineWidget.swift`
- Create: `KaffComplication/Views/CircularView.swift`
- Create: `KaffComplication/Views/RectangularView.swift`
- Create: `KaffComplication/Views/CornerView.swift`
- Create: `KaffComplication/Views/InlineView.swift`

- [ ] **Step 1 : entrée et provider**

`CaffeineEntry.swift` :
```swift
import KaffCore
import WidgetKit

struct CaffeineEntry: TimelineEntry {
    let data: WidgetEntryData
    var date: Date { data.date }
}
```

`CaffeineTimelineProvider.swift` :
```swift
import KaffCore
import WidgetKit

struct CaffeineTimelineProvider: TimelineProvider {
    private var snapshot: CacheSnapshot? {
        AppGroup.defaults.flatMap { CacheStore(defaults: $0).read() }
    }

    func placeholder(in context: Context) -> CaffeineEntry {
        CaffeineEntry(data: WidgetEntryData(date: .now, milligrams: 120, status: .ok, limitMg: 200,
                                            sleepReadyAt: .now, isSleepReady: true, hasData: true))
    }

    func getSnapshot(in context: Context, completion: @escaping (CaffeineEntry) -> Void) {
        let first = WidgetTimelinePlanner.entries(snapshot: snapshot, now: .now).first ?? .empty(at: .now)
        completion(CaffeineEntry(data: first))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CaffeineEntry>) -> Void) {
        let entries = WidgetTimelinePlanner.entries(snapshot: snapshot, now: .now).map(CaffeineEntry.init)
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}
```

- [ ] **Step 2 : vues par famille**

Couleur partagée — ajouter en haut de `CaffeineWidget.swift` :
```swift
import KaffCore
import SwiftUI
import WidgetKit

extension LevelStatus {
    var widgetColor: Color {
        switch self {
        case .ok: .green
        case .elevated: .orange
        case .high: .red
        }
    }

    var shortLabel: String {
        switch self {
        case .ok: "OK"
        case .elevated: "Élevé"
        case .high: "Trop"
        }
    }
}

struct CaffeineWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "fr.batum.kaff.level", provider: CaffeineTimelineProvider()) { entry in
            CaffeineWidgetView(data: entry.data)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "kaff://log"))
        }
        .configurationDisplayName("Caféine")
        .description("Niveau de caféine estimé.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner, .accessoryInline])
    }
}

struct CaffeineWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let data: WidgetEntryData

    var body: some View {
        switch family {
        case .accessoryCircular: CircularView(data: data)
        case .accessoryRectangular: RectangularView(data: data)
        case .accessoryCorner: CornerView(data: data)
        default: InlineView(data: data)
        }
    }
}
```

`Views/CircularView.swift` :
```swift
import KaffCore
import SwiftUI
import WidgetKit

struct CircularView: View {
    let data: WidgetEntryData

    var body: some View {
        Gauge(value: min(data.milligrams, data.limitMg), in: 0...data.limitMg) {
            Text("mg")
        } currentValueLabel: {
            Text(data.hasData ? "\(Int(data.milligrams.rounded()))" : "—").font(.system(.body, design: .rounded).bold())
        }
        .gaugeStyle(.accessoryCircular)
        .tint(data.status.widgetColor)
        .widgetAccentable()
    }
}
```

`Views/RectangularView.swift` :
```swift
import KaffCore
import SwiftUI
import WidgetKit

struct RectangularView: View {
    let data: WidgetEntryData

    var body: some View {
        HStack(spacing: 6) {
            Gauge(value: min(data.milligrams, data.limitMg), in: 0...data.limitMg) { EmptyView() }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(data.status.widgetColor)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 0) {
                if data.hasData {
                    Text("\(Int(data.milligrams.rounded())) mg").font(.headline).widgetAccentable()
                    Text(data.status.shortLabel).font(.caption2).foregroundStyle(data.status.widgetColor)
                    Text(data.isSleepReady ? "Sommeil OK" : "Sommeil \(data.sleepReadyAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("Ouvrir Kaff").font(.headline)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
```

`Views/CornerView.swift` :
```swift
import KaffCore
import SwiftUI
import WidgetKit

struct CornerView: View {
    let data: WidgetEntryData

    var body: some View {
        Text(data.hasData ? "\(Int(data.milligrams.rounded()))" : "—")
            .font(.system(.title3, design: .rounded).bold())
            .widgetAccentable()
            .widgetLabel {
                Gauge(value: min(data.milligrams, data.limitMg), in: 0...data.limitMg) { Text("mg") }
                    .gaugeStyle(.accessoryLinearCapacity)
                    .tint(data.status.widgetColor)
            }
    }
}
```

`Views/InlineView.swift` :
```swift
import KaffCore
import SwiftUI
import WidgetKit

struct InlineView: View {
    let data: WidgetEntryData

    var body: some View {
        if data.hasData {
            Text("☕ \(Int(data.milligrams.rounded())) mg · \(data.status.shortLabel)")
        } else {
            Text("☕ Ouvrir Kaff")
        }
    }
}
```

`KaffComplicationBundle.swift` (remplace tout le contenu de M0.2) :
```swift
import SwiftUI
import WidgetKit

@main
struct KaffComplicationBundle: WidgetBundle {
    var body: some Widget {
        CaffeineWidget()
    }
}
```

- [ ] **Step 3 : `make run`** puis ajouter la complication sur un cadran (Modulaire ou Infographe pour voir plusieurs familles). Loguer une dose dans l'app → la complication se met à jour. Attendre 15 min (ou avancer l'horloge du simulateur) → la valeur décroît sans ouvrir l'app. Tap → l'app s'ouvre sur la grille Boisson.

- [ ] **Step 4 : commit**

```bash
git add KaffComplication
git commit -m "feat(widget): M4.2 accessory complications with precomputed timeline and deep link"
```

Mettre à jour `docs/ROADMAP.md` : M4 ✅.

---

## M5 — Finition et appareil

### Task M5.1 : Catalogue de chaînes et région de développement

**Files:**
- Create: `Kaff Watch App/Resources/Localizable.xcstrings`
- Modify: `project.yml`

- [ ] **Step 1** : créer `Localizable.xcstrings` avec `{ "sourceLanguage" : "fr", "strings" : { }, "version" : "1.0" }`.
- [ ] **Step 2** : dans `project.yml`, section `settings.base`, ajouter `SWIFT_EMIT_LOC_STRINGS: YES` ; dans `info.properties` de l'app, ajouter `CFBundleDevelopmentRegion: fr`.
- [ ] **Step 3** : `make build` → ouvrir `Localizable.xcstrings` dans Xcode : les chaînes des vues sont listées.
- [ ] **Step 4** : commit `git commit -am "chore(app): M5.1 string catalog, French development region"`.

### Task M5.2 : États vides, accessibilité, tailles de texte

**Files:**
- Modify: `Kaff Watch App/Features/Home/HomeView.swift`

- [ ] **Step 1** : dans `HomeView`, quand `model.doses.isEmpty`, afficher sous la jauge `Text("Aucune caféine enregistrée. Ajoutez une boisson.").font(.footnote).foregroundStyle(.secondary)` à la place de la courbe.
- [ ] **Step 2** : simulateur › Réglages › Accessibilité › Taille du texte au maximum : aucun texte tronqué sur Home, QuickLog, Historique (ajuster `lineLimit`/`minimumScaleFactor(0.8)` si nécessaire).
- [ ] **Step 3** : activer VoiceOver sur le simulateur (Réglages › Accessibilité) et parcourir Home : la jauge annonce « 142 mg, OK ».
- [ ] **Step 4** : commit `git commit -am "feat(app): M5.2 empty state and accessibility pass"`.

### Task M5.3 : Installation sur la montre physique

- [ ] **Step 1** : sur l'iPhone, Réglages › Confidentialité et sécurité › Mode développeur activé ; idem sur la montre (Réglages › Confidentialité et sécurité › Mode développeur).
- [ ] **Step 2** : Xcode › Window › Devices and Simulators : l'iPhone apparaît, la montre appariée en dessous. Renseigner `Config/Local.xcconfig` avec le Team ID réel si ce n'est pas fait.
- [ ] **Step 3** : `xcodegen generate && open Kaff.xcodeproj`, choisir la montre comme destination, Run. Première fois : accepter le profil sur la montre (Réglages › Général › Gestion des appareils) et autoriser Santé.
- [ ] **Step 4** : ajouter la complication à ton cadran, utiliser l'app une journée. Noter dans `docs/ROADMAP.md` (journal) les crashs ou frictions observés ; corriger avant de continuer.
- [ ] **Step 5** : commit des éventuels correctifs `fix(app): M5.3 …`.

### Task M5.4 : Revue de code, sécurité, couverture

- [ ] **Step 1** : lancer l'agent `code-reviewer` sur l'ensemble du dépôt et l'agent `security-reviewer` sur `Kaff Watch App/Services` et `Kaff Watch App/App` (données de santé). Corriger les CRITICAL et HIGH ; noter les MEDIUM restants dans le backlog de `docs/ROADMAP.md`.
- [ ] **Step 2** : couverture `KaffCore` : commande de la Task M1.7 Step 5 → ≥ 90 %.
- [ ] **Step 3** : couverture app : `make test` puis `xcrun xccov view --report --only-targets build/Logs/Test/*.xcresult` → `Kaff Watch App` ≥ 80 % hors fichiers `Features/**` (vues) ; sinon ajouter des tests `AppModel`.
- [ ] **Step 4** : commit `git commit -am "test: M5.4 review fixes and coverage"`.

### Task M5.5 : README et version

**Files:**
- Modify: `README.md`

- [ ] **Step 1** : compléter `README.md` : description, capture d'écran (`docs/screenshots/m3-home.png`), prérequis (Xcode 26.6, XcodeGen, watchOS 26), installation (`cp Config/Local.xcconfig.example Config/Local.xcconfig`, `make run`), commandes du Makefile, mention « estimation indicative, pas un avis médical », lien vers la spec et la roadmap.
- [ ] **Step 2** : `git commit -am "docs: M5.5 README" && git tag v0.1.0`.

Mettre à jour `docs/ROADMAP.md` : M5 ✅, journal « v0.1.0 installée sur la montre ».

---

## Auto-revue du plan (faite le 2026-08-27)

- **Couverture de la spec** : §3 structure → M0/M1/M2 ; §4 PK → M1.3 ; §5 seuils, sommeil, équivalences → M1.2, M1.5, M3.3 ; §6 catalogue, favoris, boissons perso, métadonnées HealthKit → M1.2, M2.1, M2.2, M3.5 ; §7 écrans + deep link → M3.1–M3.5 ; §8 complication (4 familles, grille + transitions, `.atEnd`, rechargement, placeholder) → M1.6, M4.1, M4.2 ; §9 erreurs (autorisation, écriture, poids, cache widget, bornes) → M2.2, M3.1, M4.2, M1.1 ; §10 tests → chaque tâche ; §11 hypothèses → M0.2.
- **Cohérence des types** : `UserProfile` utilise `healthKitWeightKg` / `manualWeightKg` / `weightKg` (calculé) partout ; `Route` = `logDrink | logManual | settings` (l'historique est une page verticale) ; `HealthStore.save` retourne la dose sauvegardée ; `WidgetEntryData` est le seul type traversant la frontière KaffCore → widget.
- **Écart connu avec la spec** : §7 disait « Digital Crown défile vers Historique » — réalisé par `TabView(.verticalPage)`, cohérent.
