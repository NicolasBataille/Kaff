import Foundation
import KaffCore
import Testing
@testable import Kaff_Watch_App

/// `AppModel.enableHealthBedtime()` / `disableHealthBedtime()` / `refresh()` : coucher déduit du sommeil Santé (spec §5.1, §9).
@MainActor
struct AppModelSleepTests {
    let health = MockHealthStore()
    let widgets = SpyWidgetReloader()
    let notifications = MockNotificationScheduler()
    let defaults: UserDefaults
    let calendar: Calendar
    /// 2026-08-28 12:00, Europe/Paris.
    let now: Date

    init() {
        let name = "kaff.sleeptests.\(UUID().uuidString)"
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

    /// 2026-08-`day` à `hour`:`minute`, Europe/Paris.
    func date(day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: day, hour: hour, minute: minute))!
    }

    /// Nuits consécutives se terminant la veille de `now`, couchées à `hour`:`minute`, levées 8 h plus tard.
    func nights(_ count: Int, at hour: Int, _ minute: Int = 0) -> [SleepSession] {
        (0..<count).map { offset in
            let start = date(day: 27 - offset, hour, minute)
            return SleepSession(start: start, end: start.addingTimeInterval(8 * 3600), kind: .asleep)
        }
    }

    /// Modèle démarré avec un coucher manuel à 22:00 (pour distinguer la valeur Santé de la valeur manuelle).
    func startedModel() async -> AppModel {
        let model = makeModel()
        await model.start()
        var profile = model.profile
        profile.bedtime = ClockTime(hour: 22, minute: 0)
        await model.update(profile: profile)
        return model
    }

    func cachedBedtime() throws -> ClockTime {
        try #require(CacheStore(defaults: defaults).read()).limits.bedtime
    }

    @Test func enableAsksSleepAuthorizationOnceAndReadsFourteenDays() async throws {
        health.sleepSessions = nights(3, at: 23)
        let model = await startedModel()
        await model.enableHealthBedtime()
        #expect(health.sleepAuthorizationRequests == 1)
        let query = try #require(health.sleepQueries.last)
        #expect(query.start == calendar.date(byAdding: .day, value: -BedtimeInference.lookbackDays, to: now))
        #expect(query.end == now)
    }

    @Test func enableStoresInferredBedtimeAndPublishesIt() async throws {
        health.sleepSessions = nights(3, at: 23)
        let model = await startedModel()
        let reloads = widgets.reloadCount
        await model.enableHealthBedtime()
        #expect(model.profile.usesHealthBedtime == true)
        #expect(model.profile.healthBedtime == ClockTime(hour: 23, minute: 0))
        #expect(model.profile.healthBedtimeNights == 3)
        #expect(model.healthBedtimeState == .inferred(nights: 3))
        #expect(model.profile.bedtime == ClockTime(hour: 22, minute: 0))
        #expect(try cachedBedtime() == ClockTime(hour: 23, minute: 0))
        #expect(widgets.reloadCount == reloads + 1)
        #expect(ProfileStore(defaults: defaults).loadProfile() == model.profile)
        #expect(model.lastError == nil)
    }

    @Test func enableWithoutNightsKeepsManualBedtime() async throws {
        let model = await startedModel()
        await model.enableHealthBedtime()
        #expect(model.profile.usesHealthBedtime == true)
        #expect(model.profile.healthBedtime == nil)
        #expect(model.profile.healthBedtimeNights == nil)
        #expect(model.healthBedtimeState == .noNights)
        #expect(try cachedBedtime() == ClockTime(hour: 22, minute: 0))
        #expect(ProfileStore(defaults: defaults).loadProfile().usesHealthBedtime == true)
    }

    @Test func enableSurvivesAuthorizationErrorAndStillReads() async {
        health.sleepAuthorizationError = NSError(domain: "test", code: 5)
        health.sleepSessions = nights(3, at: 23)
        let model = await startedModel()
        await model.enableHealthBedtime()
        #expect(model.lastError == "Autorisation sommeil impossible")
        #expect(health.sleepQueries.count == 1)
        #expect(model.profile.healthBedtime == ClockTime(hour: 23, minute: 0))
    }

    @Test func readErrorReportsAndKeepsPreviousValue() async {
        health.sleepSessions = nights(3, at: 23)
        let model = await startedModel()
        await model.enableHealthBedtime()
        health.sleepError = NSError(domain: "test", code: 6)
        await model.refresh()
        #expect(model.lastError == "Lecture du sommeil impossible")
        #expect(model.profile.healthBedtime == ClockTime(hour: 23, minute: 0))
        #expect(model.profile.healthBedtimeNights == 3)
        #expect(model.healthBedtimeState == .inferred(nights: 3))
    }

    @Test func refreshReInfersWhenEnabled() async throws {
        health.sleepSessions = nights(3, at: 23)
        let model = await startedModel()
        await model.enableHealthBedtime()
        health.sleepSessions = nights(4, at: 0, 30)
        await model.refresh()
        #expect(health.sleepQueries.count == 2)
        #expect(model.profile.healthBedtime == ClockTime(hour: 0, minute: 30))
        #expect(model.profile.healthBedtimeNights == 4)
        #expect(try cachedBedtime() == ClockTime(hour: 0, minute: 30))
        #expect(ProfileStore(defaults: defaults).loadProfile().healthBedtime == ClockTime(hour: 0, minute: 30))
    }

    @Test func refreshNeverQueriesSleepWhenDisabled() async {
        health.sleepSessions = nights(3, at: 23)
        let model = await startedModel()
        await model.refresh()
        #expect(health.sleepQueries.isEmpty)
        #expect(health.sleepAuthorizationRequests == 0)
        #expect(model.healthBedtimeState == .off)
    }

    @Test func disableRestoresManualBedtime() async throws {
        health.sleepSessions = nights(3, at: 23)
        let model = await startedModel()
        await model.enableHealthBedtime()
        let reloads = widgets.reloadCount
        await model.disableHealthBedtime()
        #expect(model.profile.usesHealthBedtime == false)
        #expect(model.healthBedtimeState == .off)
        #expect(try cachedBedtime() == ClockTime(hour: 22, minute: 0))
        #expect(widgets.reloadCount == reloads + 1)
        #expect(ProfileStore(defaults: defaults).loadProfile().usesHealthBedtime == false)
    }
}
