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

// MARK: - Migration hors de l'App Group

private func legacyDefaultsWithData() throws -> (UserDefaults, UserProfile, [Drink]) {
    let legacy = freshDefaults()
    var profile = UserProfile.default
    profile.healthKitWeightKg = 82
    profile.halfLifeHours = 6
    let drink = Drink(id: "custom-mig", name: "Ristretto", milligrams: 60, volumeML: 25, symbol: "cup.and.saucer.fill", isCustom: true)
    let legacyStore = ProfileStore(defaults: legacy)
    try legacyStore.save(profile)
    try legacyStore.saveCustomDrinks([drink])
    return (legacy, profile, [drink])
}

@Test func migrationCopiesProfileAndDrinksThenClearsLegacy() throws {
    let (legacy, profile, drinks) = try legacyDefaultsWithData()
    let destination = freshDefaults()
    let store = ProfileStore(defaults: destination)

    store.migrate(from: legacy)

    #expect(store.loadProfile() == profile)
    #expect(store.loadCustomDrinks() == drinks)
    #expect(legacy.object(forKey: ProfileStore.profileKey) == nil)
    #expect(legacy.object(forKey: ProfileStore.customDrinksKey) == nil)
}

@Test func migrationKeepsDestinationWhenAlreadyPopulatedButStillClearsLegacy() throws {
    let (legacy, _, _) = try legacyDefaultsWithData()
    let destination = freshDefaults()
    let store = ProfileStore(defaults: destination)
    var existing = UserProfile.default
    existing.manualWeightKg = 60
    let existingDrink = Drink(id: "custom-keep", name: "Matcha", milligrams: 70, volumeML: 200, symbol: "leaf.fill", isCustom: true)
    try store.save(existing)
    try store.saveCustomDrinks([existingDrink])

    store.migrate(from: legacy)

    #expect(store.loadProfile() == existing)
    #expect(store.loadCustomDrinks() == [existingDrink])
    #expect(legacy.object(forKey: ProfileStore.profileKey) == nil)
    #expect(legacy.object(forKey: ProfileStore.customDrinksKey) == nil)
}

@Test func migrationIsNoOpWhenNothingToMigrate() {
    let legacy = freshDefaults()
    let destination = freshDefaults()
    let store = ProfileStore(defaults: destination)

    store.migrate(from: legacy)

    #expect(store.loadProfile() == .default)
    #expect(store.loadCustomDrinks().isEmpty)
    #expect(destination.object(forKey: ProfileStore.profileKey) == nil)
    #expect(destination.object(forKey: ProfileStore.customDrinksKey) == nil)
}

@Test func migrationIsIdempotent() throws {
    let (legacy, profile, drinks) = try legacyDefaultsWithData()
    let store = ProfileStore(defaults: freshDefaults())

    store.migrate(from: legacy)
    store.migrate(from: legacy)

    #expect(store.loadProfile() == profile)
    #expect(store.loadCustomDrinks() == drinks)
}
