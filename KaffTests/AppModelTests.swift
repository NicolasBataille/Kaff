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
                 cacheStore: CacheStore(defaults: defaults), widgets: widgets,
                 now: { now }, authorizationRetryDelay: .zero)
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

    @Test func startRetriesAuthorizationStatusBeforeDenying() async {
        health.authorizedAfterChecks = 2
        let model = makeModel()
        await model.start()
        #expect(model.authorization == .authorized)
    }

    @Test func refreshPublishesDosesEvenIfWeightReadFails() async throws {
        health.stored = [CaffeineDose(date: now.addingTimeInterval(-3600), milligrams: 63)]
        health.bodyMassError = NSError(domain: "test", code: 2)
        let model = makeModel()
        await model.start()
        #expect(model.doses.count == 1)
        let cache = try #require(CacheStore(defaults: defaults).read())
        #expect(cache.doses.count == 1)
        #expect(widgets.reloadCount >= 1)
        #expect(model.lastError != nil)
    }

    @Test func logSavesWritesCacheAndReloadsWidgets() async throws {
        let model = makeModel()
        await model.start()
        let espresso = DrinkCatalog.drink(id: "espresso", custom: [])!
        let before = widgets.reloadCount
        await model.log(milligrams: 126, drink: espresso, volumeML: 60)
        #expect(health.savedIDs.count == 1)
        #expect(model.doses.last?.drinkID == "espresso")
        #expect(model.doses.last?.id == health.savedIDs.first)
        let cache = try #require(CacheStore(defaults: defaults).read())
        #expect(cache.doses.count == 1)
        #expect(widgets.reloadCount == before + 1)
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

    @Test func deleteAfterFailedLogClearsError() async {
        let dose = CaffeineDose(date: now.addingTimeInterval(-600), milligrams: 95)
        health.stored = [dose]
        health.saveError = NSError(domain: "test", code: 1)
        let model = makeModel()
        await model.start()
        await model.log(milligrams: 50, drink: nil, volumeML: nil)
        #expect(model.lastError != nil)
        health.saveError = nil
        await model.delete(dose)
        #expect(model.lastError == nil)
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
        let before = widgets.reloadCount
        await model.update(profile: p)
        #expect(ProfileStore(defaults: defaults).loadProfile().halfLifeHours == 7)
        #expect(model.assessment().now == now)
        #expect(widgets.reloadCount == before + 1)
    }

    @Test func favoritesComeFromLoggedDrinks() async {
        health.stored = ["tea-black", "espresso", "espresso"].map {
            CaffeineDose(date: now.addingTimeInterval(-7200), milligrams: 50, drinkID: $0, volumeML: 100)
        }
        let model = makeModel()
        await model.start()
        #expect(model.favoriteDrinks.map(\.id) == ["espresso", "tea-black"])
    }

    @Test func startReportsUnavailableWhenHealthDataUnavailable() async {
        health.isAvailable = false
        health.stored = [CaffeineDose(date: now.addingTimeInterval(-3600), milligrams: 63)]
        let model = makeModel()
        await model.start()
        #expect(model.authorization == .unavailable)
        #expect(model.doses.isEmpty)
        #expect(widgets.reloadCount == 0)
        #expect(model.lastError == nil)
    }

    @Test func startSurvivesAuthorizationRequestError() async {
        health.authorizationError = NSError(domain: "test", code: 3)
        health.isWriteAuthorized = false
        let denied = makeModel()
        await denied.start()
        #expect(denied.lastError != nil)
        #expect(denied.authorization == .denied)
        // L'échec de la demande n'empêche pas de constater une autorisation déjà accordée.
        health.isWriteAuthorized = true
        health.stored = [CaffeineDose(date: now.addingTimeInterval(-3600), milligrams: 63)]
        let granted = makeModel()
        await granted.start()
        #expect(granted.authorization == .authorized)
        #expect(granted.doses.count == 1)
    }

    @Test func saveCustomDrinkPersistsAndReplacesSameID() async {
        let model = makeModel()
        let first = Drink(id: "custom-1", name: "Maté", milligrams: 80, volumeML: 250, symbol: "mug.fill", isCustom: true)
        let renamed = Drink(id: "custom-1", name: "Maté fort", milligrams: 120, volumeML: 250, symbol: "mug.fill", isCustom: true)
        await model.save(customDrink: first)
        await model.save(customDrink: renamed)
        #expect(model.customDrinks.count == 1)
        #expect(model.customDrinks.first?.name == "Maté fort")
        #expect(ProfileStore(defaults: defaults).loadCustomDrinks() == model.customDrinks)
        #expect(model.allDrinks.contains { $0.id == "custom-1" })
        #expect(model.lastError == nil)
    }

    @Test func deleteCustomDrinkRemovesIt() async {
        let model = makeModel()
        let drink = Drink(id: "custom-2", name: "Guarana", milligrams: 60, volumeML: 200, symbol: "mug.fill", isCustom: true)
        await model.save(customDrink: drink)
        await model.deleteCustomDrink(id: drink.id)
        #expect(model.customDrinks.isEmpty)
        #expect(ProfileStore(defaults: defaults).loadCustomDrinks().isEmpty)
        #expect(model.lastError == nil)
    }
}
