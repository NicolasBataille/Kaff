import Foundation
import KaffCore
import Testing
@testable import Kaff_Watch_App

/// `AppModel.setNotifications(sleepReady:lastIntake:)` et replanification à chaque publication (spec §7.6, §9).
@MainActor
struct AppModelNotificationTests {
    let health = MockHealthStore()
    let widgets = SpyWidgetReloader()
    let notifications = MockNotificationScheduler()
    let defaults: UserDefaults
    let calendar: Calendar
    /// 2026-08-28 12:00, Europe/Paris.
    let now: Date

    init() {
        let name = "kaff.notificationtests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        self.calendar = calendar
        now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 28, hour: 12))!
    }

    func makeModel() -> AppModel {
        AppModel(health: health, profileStore: ProfileStore(defaults: defaults),
                 cacheStore: CacheStore(defaults: defaults), widgets: widgets, notifications: notifications,
                 calendar: calendar, now: { now }, authorizationRetryDelay: .zero)
    }

    /// 2026-08-28 à `hour`:00, Europe/Paris.
    func date(_ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: 28, hour: hour))!
    }

    /// 100 mg à 08:00 : encore au-dessus du seuil coucher à midi, redescendu avant 23:00 → les deux rappels existent.
    var morningDose: CaffeineDose { CaffeineDose(date: date(8), milligrams: 100) }

    func expectedPlan(for model: AppModel, referenceMg: Double) -> [PlannedNotification] {
        NotificationPlanner.plan(doses: model.doses, limits: model.assessor.limits, referenceMg: referenceMg,
                                 wantsSleepReady: model.profile.notifySleepReady,
                                 wantsLastIntake: model.profile.notifyLastIntake, now: now, calendar: calendar)
    }

    @Test func startReadsAuthorizationWithoutAsking() async {
        notifications.status = .authorized
        let model = makeModel()
        await model.start()
        #expect(model.notificationAuthorization == .authorized)
        #expect(notifications.authorizationRequests == 0)
        #expect(notifications.replacements.count == 1)
        #expect(notifications.replacements.last?.plan.isEmpty == true)
    }

    /// Autorisation retirée dans Réglages › Notifications pendant que l'app était en arrière-plan : visible au retour
    /// au premier plan (`refresh()`), sans attendre une relance.
    @Test func refreshRereadsAuthorization() async {
        notifications.status = .authorized
        let model = makeModel()
        await model.start()
        notifications.status = .denied
        await model.refresh()
        #expect(model.notificationAuthorization == .denied)
        #expect(notifications.authorizationRequests == 0)
    }

    @Test func firstActivationAsksOnce() async {
        let model = makeModel()
        await model.start()
        await model.setNotifications(sleepReady: true, lastIntake: false)
        #expect(notifications.authorizationRequests == 1)
        #expect(model.notificationAuthorization == .authorized)
        await model.setNotifications(sleepReady: true, lastIntake: true)
        #expect(notifications.authorizationRequests == 1)
        #expect(model.profile.notifySleepReady == true)
        #expect(model.profile.notifyLastIntake == true)
        #expect(ProfileStore(defaults: defaults).loadProfile().notifyLastIntake == true)
    }

    @Test func alreadyAuthorizedNeverAsks() async {
        notifications.status = .authorized
        let model = makeModel()
        await model.start()
        await model.setNotifications(sleepReady: true, lastIntake: true)
        #expect(notifications.authorizationRequests == 0)
        #expect(model.profile.notifySleepReady == true)
    }

    @Test func denialClearsFlagsAndRemovesPending() async {
        notifications.requestResult = .denied
        health.stored = [morningDose]
        let model = makeModel()
        await model.start()
        await model.setNotifications(sleepReady: true, lastIntake: true)
        #expect(notifications.authorizationRequests == 1)
        #expect(model.notificationAuthorization == .denied)
        #expect(model.profile.notifySleepReady == false)
        #expect(model.profile.notifyLastIntake == false)
        #expect(notifications.replacements.last?.plan.isEmpty == true)
        #expect(model.plannedNotifications.isEmpty)
    }

    @Test func requestErrorIsReported() async {
        notifications.requestError = NSError(domain: "test", code: 7)
        let model = makeModel()
        await model.start()
        await model.setNotifications(sleepReady: true, lastIntake: false)
        #expect(model.lastError == "Autorisation des notifications impossible")
        #expect(model.notificationAuthorization == .notDetermined)
        // Revue M6.7 : sans réponse du système, les drapeaux restent éteints (rien ne serait jamais livré).
        #expect(model.profile.notifySleepReady == false)
        #expect(model.profile.notifyLastIntake == false)
        #expect(notifications.replacements.count == 1)   // seule la publication de start()
    }

    @Test func grantedPublishesPlannerPlanWithEspressoFallback() async throws {
        health.stored = [morningDose]
        let model = makeModel()
        await model.start()
        await model.setNotifications(sleepReady: true, lastIntake: true)
        let replacement = try #require(notifications.replacements.last)
        let expected = expectedPlan(for: model, referenceMg: 63)
        #expect(Set(expected.map(\.kind)) == [.sleepReady, .lastIntake])
        #expect(replacement.plan == expected)
        #expect(model.plannedNotifications == expected)
        #expect(replacement.content.referenceDrinkName == "Espresso")
        #expect(replacement.content.bedtime == model.profile.effectiveBedtime)
        #expect(replacement.content.bedtimeLimitMg == model.profile.bedtimeLimitMg)
    }

    /// Trois doubles espressos l'avant-veille (favori sur 30 jours) sans rien aujourd'hui : le rappel « dernier »
    /// porte sur 125 mg. Des doses logguées à midi même pousseraient la projection au coucher au-dessus du seuil.
    @Test func referenceDrinkIsTheFavorite() async throws {
        let double = try #require(DrinkCatalog.drink(id: "double-espresso", custom: []))
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: date(9))!
        health.stored = (0..<3).map { _ in
            CaffeineDose(date: twoDaysAgo, milligrams: double.milligrams, drinkID: double.id, volumeML: double.volumeML)
        }
        let model = makeModel()
        await model.start()
        await model.setNotifications(sleepReady: false, lastIntake: true)
        let replacement = try #require(notifications.replacements.last)
        #expect(replacement.content.referenceDrinkName == "Double espresso")
        #expect(replacement.plan == expectedPlan(for: model, referenceMg: double.milligrams))
        #expect(replacement.plan.map(\.kind) == [.lastIntake])
        #expect(replacement.plan.first?.milligrams == double.milligrams)
    }

    @Test func disablingBothRemovesPendingNotifications() async {
        health.stored = [morningDose]
        let model = makeModel()
        await model.start()
        await model.setNotifications(sleepReady: true, lastIntake: true)
        #expect(notifications.replacements.last?.plan.isEmpty == false)
        await model.setNotifications(sleepReady: false, lastIntake: false)
        #expect(notifications.replacements.last?.plan.isEmpty == true)
        #expect(model.plannedNotifications.isEmpty)
        #expect(model.profile.notifySleepReady == false)
        #expect(model.profile.notifyLastIntake == false)
    }

    @Test func logDeleteAndProfileUpdateEachReplan() async {
        health.stored = [morningDose]
        let model = makeModel()
        await model.start()
        await model.setNotifications(sleepReady: true, lastIntake: true)
        var count = notifications.replacements.count

        await model.log(milligrams: 63, drink: nil, volumeML: nil)
        #expect(notifications.replacements.count == count + 1)
        count = notifications.replacements.count

        await model.delete(model.doses[0])
        #expect(notifications.replacements.count == count + 1)
        count = notifications.replacements.count

        var profile = model.profile
        profile.bedtime = ClockTime(hour: 22, minute: 0)
        await model.update(profile: profile)
        #expect(notifications.replacements.count == count + 1)
        #expect(notifications.replacements.last?.content.bedtime == ClockTime(hour: 22, minute: 0))
    }
}
