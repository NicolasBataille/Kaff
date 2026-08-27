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
