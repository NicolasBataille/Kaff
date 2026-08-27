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
